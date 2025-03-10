import Accessibility

#if os(macOS)
import AppKit
import os

final class XcodeHandler {

    // MARK: - Public Methods

    func isXcode(_ runningApp: NSRunningApplication) -> Bool {
        guard let bundleId = runningApp.bundleIdentifier else { return false }
        return bundleId == "com.apple.dt.Xcode" || bundleId.contains("Xcode")
    }

    func getXcodeDocumentInfo(_ textArea: AXUIElement, appElement: AXUIElement) -> (fileName: String?, filePath: String?) {
        extractAndAddXcodeProjectPath(from: textArea)
        if let editorInfo = findXcodeEditorInfo(textArea) {
            return editorInfo
        }
        return getUniqueDocumentInfo(textArea, appElement: appElement)
    }

    // MARK: - Private Helpers

    private func isXcodeSourceFile(_ title: String) -> Bool {
        let fileExtensions = [".swift", ".h", ".m", ".mm", ".c", ".cpp", ".hpp", ".java", ".kt", ".py", ".js", ".ts"]
        return fileExtensions.contains { title.contains($0) } || title.contains(" — ")
    }

    private func isProjectPath(_ string: String) -> Bool {
        return string.contains("/") && (string.contains(".xcodeproj") || string.contains(".xcworkspace"))
    }

    private func extractAndAddXcodeProjectPath(from textArea: AXUIElement) {
        var currentElement = textArea
        let maxDepth = 15

        for _ in 0..<maxDepth {
            guard let parent = currentElement.getParent() else { break }

            if let description = try? parent.axDescription(), isProjectPath(description) {
                let projectDir = (description as NSString).deletingLastPathComponent
                print("Found Xcode project path: \(description)")
                FileLocator.shared.addProjectRoot(projectDir)
                addCommonXcodeSubdirectories(projectDir)
                break
            }

            var attributeNames: CFArray?
            if AXUIElementCopyAttributeNames(parent, &attributeNames) == .success,
               let attributeNames = attributeNames {
                let count = CFArrayGetCount(attributeNames)
                for i in 0..<count {
                    let nameRef = CFArrayGetValueAtIndex(attributeNames, i)
                    let name = unsafeBitCast(nameRef, to: CFString.self) as String
                    if name.lowercased().contains("path") ||
                       name.lowercased().contains("url") ||
                       name.lowercased().contains("file") ||
                       name.lowercased().contains("document") {

                        var value: AnyObject?
                        if AXUIElementCopyAttributeValue(parent, name as CFString, &value) == .success,
                           let stringValue = value as? String,
                           isProjectPath(stringValue) {

                            let projectDir = (stringValue as NSString).deletingLastPathComponent
                            print("Found Xcode project path in attribute \(name): \(stringValue)")
                            FileLocator.shared.addProjectRoot(projectDir)
                            addCommonXcodeSubdirectories(projectDir)
                            break
                        }
                    }
                }
            }
            currentElement = parent
        }
    }

    private func findXcodeEditorInfo(_ textArea: AXUIElement) -> (fileName: String?, filePath: String?)? {
        if let description = try? textArea.axDescription(), description == "Source Editor" {
            return findFileInfoInXcodeHierarchy(textArea)
        }

        var currentElement = textArea
        let maxDepth = 15
        for _ in 0..<maxDepth {
            guard let parent = currentElement.getParent() else { break }
            if let description = try? parent.axDescription(), description == "Source Editor" {
                return findFileInfoInXcodeHierarchy(parent)
            }
            currentElement = parent
        }
        return nil
    }

    private func findFileInfoInXcodeHierarchy(_ editorElement: AXUIElement) -> (fileName: String?, filePath: String?)? {
        var currentElement = editorElement
        let maxDepth = 20
        let editorPosition = editorElement.axPosition()
        var tabInfos: [(element: AXUIElement, title: String, position: CGPoint)] = []
        var possibleFileNames: [(depth: Int, name: String, element: AXUIElement)] = []

        // Walk to a high-level parent to collect tab elements
        var rootElement = editorElement
        for _ in 0..<10 {
            guard let parent = rootElement.getParent() else { break }
            rootElement = parent
        }
        collectTabElements(rootElement, tabInfos: &tabInfos)

        for depth in 0..<maxDepth {
            guard let parent = currentElement.getParent() else { break }

            if let role = parent.axRole(), role.contains("Tab"), let title = parent.axTitle(), !title.isEmpty {
                if isXcodeSourceFile(title) { return processXcodeFileName(title) }
                possibleFileNames.append((depth, title, parent))
            }

            if let description = try? parent.axDescription(), !description.isEmpty, description != "Source Editor" {
                if isXcodeSourceFile(description) { return processXcodeFileName(description) }
                possibleFileNames.append((depth, description, parent))
            }

            if let title = parent.axTitle(), !title.isEmpty {
                if isXcodeSourceFile(title) { return processXcodeFileName(title) }
                if title.contains(".") || title.contains(" — ") {
                    possibleFileNames.append((depth, title, parent))
                }
            }

            currentElement = parent
        }

        if !tabInfos.isEmpty {
            tabInfos.sort { abs($0.position.y - editorPosition.y) < abs($1.position.y - editorPosition.y) }
            if let tab = tabInfos.first(where: { isXcodeSourceFile($0.title) }) {
                return processXcodeFileName(tab.title)
            }
            return processXcodeFileName(tabInfos.first?.title ?? "")
        }

        if !possibleFileNames.isEmpty {
            possibleFileNames.sort { $0.depth < $1.depth }
            if let match = possibleFileNames.first(where: { isXcodeSourceFile($0.name) }) {
                return processXcodeFileName(match.name)
            }
            if let fallback = possibleFileNames.first(where: { $0.name.contains(" — ") }) {
                return processXcodeFileName(fallback.name)
            }
            return processXcodeFileName(possibleFileNames[0].name)
        }

        return nil
    }

    private func addCommonXcodeSubdirectories(_ projectDir: String) {
        let commonDirs = ["", "Classes", "Source", "Sources", "App", "Views", "Models", "Controllers", "ViewControllers", "ViewModels", "Utilities", "Utils", "Helpers", "Extensions", "Shared", "Common"]
        for dir in commonDirs {
            let path = dir.isEmpty ? projectDir : (projectDir as NSString).appendingPathComponent(dir)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                FileLocator.shared.addProjectRoot(path)
            }
        }
        print("Project roots in FileLocator: \(FileLocator.shared.getAllProjectRoots())")
    }

    private func processXcodeFileName(_ title: String) -> (fileName: String?, filePath: String?) {
        print("Processing Xcode file name: \(title)")
        var fileName: String?
        var projectOrPath: String?
        let parts = title.components(separatedBy: " — ")
        if parts.count > 1 {
            fileName = parts[0]
            projectOrPath = parts[1]
        } else {
            fileName = title
        }
        if fileName?.contains(".") == false && title.contains("."),
           let range = title.range(of: #"\b\w+\.\w+\b"#, options: .regularExpression) {
            fileName = String(title[range])
        }
        var filePath: String?
        if let projectOrPath = projectOrPath, projectOrPath.contains("/") {
            filePath = projectOrPath
        } else if let fileName = fileName {
            filePath = FileLocator.shared.findFile(named: fileName) ?? findXcodeFileInProjectRoots(fileName)
        }
        return (fileName, filePath)
    }

    private func findXcodeFileInProjectRoots(_ fileName: String) -> String? {
        let projectRoots = FileLocator.shared.getAllProjectRoots()
        print("findXcodeFileInProjectRoots projectRoots: \(projectRoots)")

        let specificPaths = getXcodeSpecificPaths()
        for path in specificPaths {
            let filePath = (path as NSString).appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: filePath) {
                print("Found file at specific path: \(filePath)")
                return filePath
            }
        }

        for root in projectRoots {
            if let found = findFileRecursively(fileName, in: root, maxDepth: 7) {
                return found
            }
        }
        return nil
    }

    private func getXcodeSpecificPaths() -> [String] {
        var paths: [String] = []
        let projectRoots = FileLocator.shared.getAllProjectRoots()

        for projectRoot in projectRoots {
            let spmPath = (projectRoot as NSString).appendingPathComponent("Sources")
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: spmPath, isDirectory: &isDir), isDir.boolValue {
                paths.append(spmPath)
                let commonSubdirs = ["macOS", "iOS", "Common", "Shared", "Utilities", "Extensions"]
                for subdir in commonSubdirs {
                    let subPath = (spmPath as NSString).appendingPathComponent(subdir)
                    if FileManager.default.fileExists(atPath: subPath, isDirectory: &isDir), isDir.boolValue {
                        paths.append(subPath)
                    }
                }
            }
        }
        print("Specific search paths: \(paths)")
        return paths
    }

    private func findFileRecursively(_ fileName: String, in directory: String, maxDepth: Int = 7, currentDepth: Int = 0) -> String? {
        if currentDepth == 1 { print("Searching in: \(directory)") }
        if currentDepth >= maxDepth { return nil }

        let skipDirs = ["build", ".git", "Pods", "DerivedData", ".build", ".swiftpm", "node_modules",
                        ".xcodeproj", ".xcworkspace", ".xcassets", "Resources", "Assets", "Frameworks"]
        if skipDirs.contains((directory as NSString).lastPathComponent) { return nil }
        guard FileManager.default.isReadableFile(atPath: directory) else { return nil }

        let filePath = (directory as NSString).appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: filePath) {
            print("Found file: \(filePath)")
            return filePath
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: directory)
            let sourceDirKeywords = ["source", "sources", "src", "classes", "app", "views", "models",
                                     "controllers", "axmanager", "macos", "ios", "utilities", "extensions"]
            for item in sourceDirKeywords {
                let itemPath = (directory as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue,
                   let found = findFileRecursively(fileName, in: itemPath, maxDepth: maxDepth, currentDepth: currentDepth + 1) {
                    return found
                }
            }
        } catch { }
        return nil
    }
}

extension XcodeHandler {
    func dumpXcodeHierarchy(_ element: AXUIElement) {
        print("Dumping Xcode hierarchy for text area...")
        print("Text Area Content Preview: \((try? element.axValue())?.prefix(20) ?? "")")
        print("Text Area Description: \((try? element.axDescription()) ?? "nil")")
        print("Text Area Role: \((element.axRole()) ?? "nil")")

        var rootElement = element
        for _ in 0..<10 {
            guard let parent = rootElement.getParent() else { break }
            rootElement = parent
        }

        print("\nTabs found in UI:")
        var tabInfos: [(element: AXUIElement, title: String, position: CGPoint)] = []
        collectTabElements(rootElement, tabInfos: &tabInfos)
        for (i, tabInfo) in tabInfos.enumerated() {
            print("Tab #\(i): \(tabInfo.title) at position \(tabInfo.position.x),\(tabInfo.position.y)")
        }

        var currentElement = element
        let maxDepth = 15
        for depth in 0..<maxDepth {
            print("\nLevel \(depth):")
            print("Role: \((currentElement.axRole()) ?? "nil")")
            print("Title: \((currentElement.axTitle()) ?? "nil")")
            print("Description: \((try? currentElement.axDescription()) ?? "nil")")

            var attributeNames: CFArray?
            if AXUIElementCopyAttributeNames(currentElement, &attributeNames) == .success,
               let attributeNames = attributeNames {
                let count = CFArrayGetCount(attributeNames)
                for i in 0..<count {
                    let nameRef = CFArrayGetValueAtIndex(attributeNames, i)
                    let name = unsafeBitCast(nameRef, to: CFString.self) as String
                    if name.lowercased().contains("path") ||
                       name.lowercased().contains("url") ||
                       name.lowercased().contains("file") ||
                       name.lowercased().contains("document") {

                        var value: AnyObject?
                        if AXUIElementCopyAttributeValue(currentElement, name as CFString, &value) == .success,
                           let value = value {
                            print("Found potential path attribute: \(name) = \(value)")
                        }
                    }
                }
            }

            guard let parent = currentElement.getParent() else {
                print("Reached top of hierarchy at depth \(depth)")
                break
            }
            currentElement = parent
        }
    }
}
#endif
