//
//  AXManager+AndroidStudio.swift
//  CueApp
//
import Accessibility

#if os(macOS)
import AppKit
import os

final class AndroidStudioHandler {
    private let logger = Logger(subsystem: "AndroidStudioHandler", category: "androidStudio")

    func isAndroidStudioOrJetBrainsIDE(_ app: NSRunningApplication) -> Bool {
        guard let bundleId = app.bundleIdentifier else { return false }
        let jetBrainsIdentifiers = [
            "com.google.android.studio",   // Android Studio
            "com.jetbrains.intellij",      // IntelliJ IDEA
            "com.jetbrains.pycharm",       // PyCharm
            "com.jetbrains.webstorm",      // WebStorm
            "com.jetbrains.CLion",         // CLion
            "com.jetbrains.AppCode",       // AppCode
            "com.jetbrains.rider",         // Rider
            "com.jetbrains.goland"         // GoLand
        ]
        return jetBrainsIdentifiers.contains { bundleId.hasPrefix($0) } ||
               bundleId.contains("jetbrains") ||
               bundleId.contains("intellij") ||
               bundleId.contains("android.studio")
    }

    func getAndroidStudioDocumentInfo(_ textArea: AXUIElement, appElement: AXUIElement) -> (fileName: String?, filePath: String?) {
        if let fileInfo = extractPathFromHierarchy(textArea) {
            return fileInfo
        }
        guard let tabInfo = findTabForTextArea(textArea) else {
            return getUniqueDocumentInfo(textArea, appElement: appElement)
        }
        return tabInfo
    }

    private func findTabForTextArea(_ textArea: AXUIElement) -> (fileName: String?, filePath: String?)? {
        var currentElement = textArea
        var depth = 0
        let maxDepth = 15
        var possibleTabTitles: [(element: AXUIElement, title: String)] = []

        while depth < maxDepth, let parent = currentElement.getParent() {
            if let title = parent.axTitle(), !title.isEmpty {
                possibleTabTitles.append((parent, title))
                if let role = parent.axRole(), role.contains("Tab") || role.contains("Editor") {
                    return processAndroidStudioTabInfo(title)
                }
            }
            if let description = try? parent.axDescription(),
               description.contains(".kt") || description.contains(".java") {
                return processAndroidStudioTabInfo(description)
            }
            currentElement = parent
            depth += 1
        }
        for (_, title) in possibleTabTitles.reversed() {
            if title.contains(".kt") || title.contains(".java") || title.contains(".xml") {
                return processAndroidStudioTabInfo(title)
            }
        }
        return nil
    }

    private func processAndroidStudioTabInfo(_ tabText: String) -> (fileName: String?, filePath: String?) {
        logger.debug("Processing Android Studio tab info: \(tabText)")
        let fileName: String? = {
            if let index = tabText.firstIndex(of: " ") {
                return String(tabText[..<index])
            }
            return tabText
        }()
        guard let fileNameUnwrapped = fileName, !fileNameUnwrapped.isEmpty else {
            return (nil, nil)
        }

        var moduleName: String?
        if tabText.contains("["), tabText.contains("]"),
           let start = tabText.firstIndex(of: "["),
           let end = tabText.firstIndex(of: "]") {
            let pathString = String(tabText[tabText.index(after: start)..<end])
            if pathString.contains("/") {
                let fullPath = "\(pathString)/\(fileNameUnwrapped)"
                if FileManager.default.fileExists(atPath: fullPath) {
                    return (fileNameUnwrapped, fullPath)
                }
            } else {
                moduleName = pathString
            }
        }
        let filePath: String?
        if let module = moduleName {
            filePath = FileLocator.shared.findFile(named: fileNameUnwrapped, inModule: module)
        } else {
            filePath = FileLocator.shared.findFile(named: fileNameUnwrapped)
        }
        return (fileNameUnwrapped, filePath)
    }

    private func extractPathFromHierarchy(_ textArea: AXUIElement) -> (fileName: String?, filePath: String?)? {
        var currentElement = textArea
        var depth = 0
        let maxDepth = 15

        while depth < maxDepth {
            if let helpText = getHelpAttribute(currentElement), !helpText.isEmpty {
                logger.debug("Found path in AXHelp attribute: \(helpText)")
                return extractFileInfoFromPath(helpText)
            }
            if let parent = currentElement.getParent() {
                if let helpText = getHelpAttribute(parent), !helpText.isEmpty {
                    logger.debug("Found path in parent's AXHelp attribute: \(helpText)")
                    return extractFileInfoFromPath(helpText)
                }
                currentElement = parent
                depth += 1
            } else {
                break
            }
        }
        return nil
    }

    private func getHelpAttribute(_ element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXHelpAttribute as CFString, &value)
        if result == .success, let stringValue = value as? String {
            return stringValue
        }
        return nil
    }

    private func extractFileInfoFromPath(_ pathString: String) -> (fileName: String?, filePath: String?) {
        logger.debug("Extracting file info from path: \(pathString)")
        var expandedPath = pathString
        if pathString.hasPrefix("~") {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            expandedPath = (pathString as NSString).replacingOccurrences(of: "~", with: homeDir)
        }
        let fileName = (expandedPath as NSString).lastPathComponent
        if FileManager.default.fileExists(atPath: expandedPath) {
            logger.debug("File exists at path: \(expandedPath)")
            let projectRoot = extractProjectRoot(from: expandedPath)
            if !projectRoot.isEmpty {
                logger.debug("Adding project root to FileLocator: \(projectRoot)")
                FileLocator.shared.addProjectRoot(projectRoot)
                addCommonAndroidSubdirectories(projectRoot)
            }
            return (fileName, expandedPath)
        }
        logger.debug("File not found at exact path, trying to find in project roots")
        let projectRoot = extractProjectRoot(from: expandedPath)
        if !projectRoot.isEmpty {
            logger.debug("Adding project root to FileLocator: \(projectRoot)")
            FileLocator.shared.addProjectRoot(projectRoot)
            addCommonAndroidSubdirectories(projectRoot)
            if let foundPath = FileLocator.shared.findFile(named: fileName) {
                return (fileName, foundPath)
            }
        }
        return (fileName, nil)
    }

    private func extractProjectRoot(from filePath: String) -> String {
        let projectIndicators = [
            "/app/src/main/java/",
            "/app/src/main/kotlin/",
            "/app/src/main/",
            "/app/src/"
        ]
        for indicator in projectIndicators {
            if filePath.contains(indicator) {
                let components = filePath.components(separatedBy: indicator)
                if let projectRoot = components.first, !projectRoot.isEmpty {
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: projectRoot, isDirectory: &isDir), isDir.boolValue {
                        return projectRoot
                    }
                }
            }
        }
        let filePathUrl = URL(fileURLWithPath: filePath)
        var currentUrl = filePathUrl.deletingLastPathComponent()
        for _ in 0..<10 {
            let parentUrl = currentUrl.deletingLastPathComponent()
            let parentPath = parentUrl.path
            let appDirPath = (parentPath as NSString).appendingPathComponent("app")
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: appDirPath, isDirectory: &isDir), isDir.boolValue {
                return parentPath
            }
            currentUrl = parentUrl
            if parentPath == "/" { break }
        }
        return ""
    }

    private func addCommonAndroidSubdirectories(_ projectRoot: String) {
        let commonDirs = ["", "app", "app/src", "app/src/main"]
        for dir in commonDirs {
            let path = dir.isEmpty ? projectRoot : (projectRoot as NSString).appendingPathComponent(dir)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                FileLocator.shared.addProjectRoot(path)
            }
        }
    }
}

extension AndroidStudioHandler {
    func dumpAndroidStudioHierarchy(_ textArea: AXUIElement) {
        logger.debug("Dumping Android Studio hierarchy for text area...")
        logger.debug("Text Area Content Preview: \((try? textArea.axValue())?.prefix(20) ?? "")")
        logger.debug("Text Area Description: \((try? textArea.axDescription()) ?? "nil")")
        logger.debug("Text Area Role: \(textArea.axRole() ?? "nil")")

        var rootElement = textArea
        for _ in 0..<10 {
            guard let parent = rootElement.getParent() else { break }
            rootElement = parent
        }

        logger.debug("\nTabs found in UI:")
        var tabInfos: [(element: AXUIElement, title: String, position: CGPoint)] = []
        collectTabElements(rootElement, tabInfos: &tabInfos)
        for (i, tabInfo) in tabInfos.enumerated() {
            logger.debug("Tab #\(i): \(tabInfo.title) at position \(tabInfo.position.x),\(tabInfo.position.y)")
        }

        var currentElement = textArea
        var depth = 0
        let maxDepth = 15
        var potentialProjectPaths: [String] = []

        while depth < maxDepth {
            logger.debug("\nLevel \(depth):")
            let role = currentElement.axRole() ?? "nil"
            let title = currentElement.axTitle() ?? "nil"
            let description = (try? currentElement.axDescription()) ?? "nil"
            logger.debug("Role: \(role)")
            logger.debug("Title: \(title)")
            logger.debug("Description: \(description)")
            CueApp.dumpAllAttributes(of: currentElement)

            if let title = currentElement.axTitle(),
               title.contains("["), title.contains("]"),
               let start = title.firstIndex(of: "["),
               let end = title.firstIndex(of: "]") {
                logger.debug("Found potential project indicator in title: \(title)")
                let projectName = title[title.index(after: start)..<end]
                logger.debug("Extracted project name: \(projectName)")
                let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
                let possibleLocations = [
                    "\(homeDir)/AndroidStudioProjects/\(projectName)",
                    "\(homeDir)/\(projectName)",
                    "\(homeDir)/Projects/\(projectName)",
                    "\(homeDir)/Development/\(projectName)",
                    "\(homeDir)/Dev/\(projectName)"
                ]
                for location in possibleLocations {
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: location, isDirectory: &isDir), isDir.boolValue {
                        logger.debug("Found existing project directory: \(location)")
                        potentialProjectPaths.append(location)
                    }
                }
            }

            var attributeNames: CFArray?
            if AXUIElementCopyAttributeNames(currentElement, &attributeNames) == .success,
               let names = attributeNames as? [String] {
                for name in names where name.lowercased().contains("path") ||
                                    name.lowercased().contains("url") ||
                                    name.lowercased().contains("file") ||
                                    name.lowercased().contains("document") ||
                                    name.lowercased().contains("project") ||
                                    name.lowercased().contains("root") {
                    var value: AnyObject?
                    if AXUIElementCopyAttributeValue(currentElement, name as CFString, &value) == .success,
                       let value = value,
                       let pathString = value as? String, pathString.contains("/") {
                        if pathString.contains("AndroidStudioProjects") ||
                           pathString.lowercased().contains("android") ||
                           pathString.contains("gradle") ||
                           (pathString.contains("/app/") && pathString.contains("/src/")) {
                            let androidPathComponents = [
                                "/app/src/main/java/",
                                "/app/src/main/kotlin/",
                                "/app/src/main/",
                                "/app/src/",
                                "/app/"
                            ]
                            var potentialRoot = pathString
                            for component in androidPathComponents {
                                if pathString.contains(component) {
                                    potentialRoot = pathString.components(separatedBy: component).first ?? potentialRoot
                                    break
                                }
                            }
                            var isDir: ObjCBool = false
                            if FileManager.default.fileExists(atPath: potentialRoot, isDirectory: &isDir), isDir.boolValue {
                                logger.debug("Found potential Android project root: \(potentialRoot)")
                                potentialProjectPaths.append(potentialRoot)
                            }
                        }
                    }
                }
            }

            if let desc = try? currentElement.axDescription(),
            desc.contains("gradle") || desc.contains("build.gradle") ||
            desc.contains("manifest") || desc.contains("AndroidManifest.xml") {
                logger.debug("Found Android project indicator in description: \(desc)")
            }

            guard let parent = currentElement.getParent() else {
                logger.debug("Reached top of hierarchy at depth \(depth)")
                break
            }

            currentElement = parent
            depth += 1
        }

        if !potentialProjectPaths.isEmpty {
            logger.debug("\nPotential Android project roots found:")
            for path in potentialProjectPaths {
                logger.debug("  \(path)")
                FileLocator.shared.addProjectRoot(path)
            }
        } else {
            logger.debug("\nNo Android project paths found.")
        }
    }
}
#endif
