//
//  FileLocator.swift
//  CueApp
//

import Foundation

#if os(macOS)
/// A utility class for locating files in various project structures
class FileLocator: @unchecked Sendable {
    // Singleton instance
    static let shared = FileLocator()

    // Cache of found paths to improve performance
    private var pathCache: [String: String] = [:]

    private var projectRoots: [String] = []

    // Initialize with specific project location
    private init() { }

    /// Clear the path cache
    func clearCache() {
        pathCache.removeAll()
    }

    /// Add a project root directory
    func addProjectRoot(_ path: String) {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue {
            // Only add if it's not already in the list
            if !projectRoots.contains(path) {
                projectRoots.append(path)
            }
        }
    }

    /// Remove a project root directory
    func removeProjectRoot(_ path: String) {
        if let index = projectRoots.firstIndex(of: path) {
            projectRoots.remove(at: index)
        }
    }

    /// Get all project roots
    func getAllProjectRoots() -> [String] {
        return projectRoots
    }

    /// Find a kotlin or java file directly using common Android package structure
    func findFile(named fileName: String) -> String? {
        // Check cache first
        if let cachedPath = pathCache[fileName] {
            return cachedPath
        }

        // Only search in the most likely locations
        let commonPaths = [
            // Most common locations in Android projects
            "/app/src/main/java/",
            "/app/src/main/kotlin/"
        ]

        // Search in all project roots
        for projectRoot in projectRoots {
            // Check each path directly without recursion
            for relativePath in commonPaths {
                let fullPath = (projectRoot as NSString).appendingPathComponent(relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath)
                let filePath = (fullPath as NSString).appendingPathComponent(fileName)

                if FileManager.default.fileExists(atPath: filePath) {
                    // Cache the result
                    pathCache[fileName] = filePath
                    return filePath
                }
            }

            // If not found in common paths, do a limited search in the app/src directory only
            let appSrcPath = (projectRoot as NSString).appendingPathComponent("app/src")

            if let foundPath = findFileWithLimitedDepth(named: fileName, in: appSrcPath, maxDepth: 5) {
                // Cache the result
                pathCache[fileName] = foundPath
                return foundPath
            }
        }

        return nil
    }

    /// Find a file in a specific module
    func findFile(named fileName: String, inModule module: String) -> String? {
        // Check cache first
        let cacheKey = "\(module)/\(fileName)"
        if let cachedPath = pathCache[cacheKey] {
            return cachedPath
        }

        // Search in all project roots
        for projectRoot in projectRoots {
            // Look in the module directly
            let modulePath = (projectRoot as NSString).appendingPathComponent(module)
            var isDir: ObjCBool = false

            if FileManager.default.fileExists(atPath: modulePath, isDirectory: &isDir) && isDir.boolValue {
                // Check common module paths
                let modulePaths = [
                    "/src/main/java/",
                    "/src/main/kotlin/",
                    "/src/main/java/com/example/cue/",
                    "/src/main/kotlin/com/example/cue/"
                ]

                for relativePath in modulePaths {
                    let fullPath = (modulePath as NSString).appendingPathComponent(relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath)
                    let filePath = (fullPath as NSString).appendingPathComponent(fileName)

                    if FileManager.default.fileExists(atPath: filePath) {
                        // Cache the result
                        pathCache[cacheKey] = filePath
                        return filePath
                    }
                }

                // Limited depth search within the module
                if let foundPath = findFileWithLimitedDepth(named: fileName, in: modulePath, maxDepth: 4) {
                    // Cache the result
                    pathCache[cacheKey] = foundPath
                    return foundPath
                }
            }
        }

        // Fall back to regular search
        return findFile(named: fileName)
    }

    // MARK: - Private helpers

    /// Find a file with limited depth to avoid permission issues
    private func findFileWithLimitedDepth(named fileName: String, in directory: String, maxDepth: Int = 3, currentDepth: Int = 0) -> String? {
        if currentDepth >= maxDepth {
            return nil
        }

        // Skip certain directories to avoid permission issues and improve performance
        let skipDirectories = ["node_modules", ".git", ".idea", "build", "tmp", "temp", ".gradle", "test", "androidTest"]
        let dirName = (directory as NSString).lastPathComponent
        if skipDirectories.contains(dirName) {
            return nil
        }

        // Check if we have access to this directory before attempting to read it
        guard FileManager.default.isReadableFile(atPath: directory) else {
            return nil
        }

        do {
            // Check if the file exists in this directory
            let fullPath = (directory as NSString).appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: fullPath) {
                return fullPath
            }

            // Try to get contents
            let contents: [String]
            do {
                contents = try FileManager.default.contentsOfDirectory(atPath: directory)
            } catch {
                // If we can't access this directory, just skip it
                return nil
            }

            // Prioritize directories that are likely to contain source files
            let prioritizedContents = contents.sorted { item1, item2 in
                let isSourceDir1 = ["java", "kotlin", "src", "main"].contains(item1.lowercased())
                let isSourceDir2 = ["java", "kotlin", "src", "main"].contains(item2.lowercased())
                return isSourceDir1 && !isSourceDir2
            }

            for item in prioritizedContents {
                let itemPath = (directory as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false

                // Only process directories we can access
                if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir) && isDir.boolValue && FileManager.default.isReadableFile(atPath: itemPath) {
                    if let path = findFileWithLimitedDepth(named: fileName, in: itemPath, maxDepth: maxDepth, currentDepth: currentDepth + 1) {
                        return path
                    }
                }
            }
        } catch {
            // Just continue if we encounter errors
        }

        return nil
    }
}
#endif
