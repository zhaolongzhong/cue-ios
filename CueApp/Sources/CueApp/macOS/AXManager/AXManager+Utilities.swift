//
//  AXManager+Utilities.swift
//  CueApp
//

import Accessibility
#if os(macOS)
import AppKit

extension AXManager {
    // MARK: - Debug Helpers

    func dumpWindowStructure(_ appElement: AXUIElement) {
        guard let windows = getAttributeElements(appElement, attribute: kAXWindowsAttribute as CFString) else {
            print("Failed to get windows")
            return
        }
        for (i, window) in windows.enumerated() {
            let title = window.axTitle() ?? "Untitled"
            print("Window #\(i): \(title)")

            if let doc = window.getDocument() {
                print("  - Has document")
                dumpAllAttributes(doc)
            } else {
                print("  - No document found")
            }

            let textAreas = findTextAreasInWindow(window)
            print("  - Contains \(textAreas.count) text areas")
            for (j, textArea) in textAreas.prefix(3).enumerated() {
                let content = (try? textArea.axValue()) ?? ""
                let preview = content.prefix(30).replacingOccurrences(of: "\n", with: "\\n")
                print("    TextArea #\(j): \"\(preview)...\"")
            }
        }
    }

    func dumpAllAttributes(_ element: AXUIElement) {
        guard let attributeNames = AXUIElementCopyAttributeNamesAsArray(element) else {
            print("Failed to get attribute names")
            return
        }
        print("Element has \(attributeNames.count) attributes:")
        for name in attributeNames {
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
            if result == .success, let value = value {
                print("  \(name): \(value)")
            } else {
                print("  \(name): <failed to retrieve>")
            }
        }
    }

    func getUniqueIdentifierForTextArea(_ textArea: AXUIElement) -> String {
        let content = (try? textArea.axValue()) ?? ""
        let contentHash = abs(content.hashValue)
        let size = (try? textArea.axSize()) ?? .zero
        let sizeDesc = "\(Int(size.width))x\(Int(size.height))"
        let randomComponent = Int.random(in: 1000...9999)
        return "\(contentHash)_\(sizeDesc)_\(randomComponent)"
    }

    // MARK: - Private Helpers

    private func getAttributeElements(_ element: AXUIElement, attribute: CFString) -> [AXUIElement]? {
        var arrayRef: CFArray?
        let result = AXUIElementCopyAttributeValues(element, attribute, 0, 100, &arrayRef)
        guard result == .success, let elements = arrayRef as? [AXUIElement] else { return nil }
        return elements
    }
}

// MARK: - Global Helper Functions

func extractFilePath(from document: AXUIElement) -> String? {
    if let path = document.axDocumentURI(), !path.isEmpty { return path }
    if let path = try? document.axValue(), !path.isEmpty { return path }
    if let path = document.axURL(), !path.isEmpty { return path }
    return nil
}

func getUniqueDocumentInfo(_ textArea: AXUIElement, appElement: AXUIElement) -> (fileName: String?, filePath: String?) {
    if let document = getDocumentForTextArea(textArea) {
        let fileName = document.axTitle() ?? document.getParent()?.axTitle()
        let filePath = extractFilePath(from: document)
        if fileName != nil || filePath != nil { return (fileName, filePath) }
    }

    var currentElement = textArea
    var containerWindow: AXUIElement?
    for _ in 0..<10 {
        guard let parent = currentElement.getParent() else { break }
        if parent.axRole() == "AXWindow" {
            containerWindow = parent
            break
        }
        currentElement = parent
    }

    if let window = containerWindow {
        let windowTitle = window.axTitle()
        var filePath = window.getDocument().flatMap { extractFilePath(from: $0) } ?? nil
        if filePath == nil, let title = windowTitle, !title.isEmpty, title != "Untitled" {
            filePath = findPathInCommonLocations(fileName: title)
        }
        return (windowTitle, filePath)
    }

    return getDocumentInfoForTextArea(textArea, appElement: appElement)
}

func getDocumentForTextArea(_ textArea: AXUIElement) -> AXUIElement? {
    var currentElement = textArea
    for _ in 0..<10 {
        guard let parent = currentElement.getParent() else { break }
        if parent.axRole() == "AXWindow" { return parent.getDocument() }
        currentElement = parent
    }
    return nil
}

func getDocumentInfoForTextArea(_ textArea: AXUIElement, appElement: AXUIElement) -> (fileName: String?, filePath: String?) {
    if let info = getDocumentInfoFromFocusedWindow(appElement) { return info }
    return getDocumentInfoByTraversingHierarchy(from: textArea)
}

func getDocumentInfoFromFocusedWindow(_ appElement: AXUIElement) -> (fileName: String?, filePath: String?)? {
    guard let focusedWindow = appElement.getFocusedWindow() else { return nil }
    let fileName = focusedWindow.axTitle()
    let filePath = focusedWindow.getDocument().flatMap { extractFilePath(from: $0) }
    return (fileName, filePath)
}

private func getDocumentInfoByTraversingHierarchy(from element: AXUIElement) -> (fileName: String?, filePath: String?) {
    var currentElement = element
    for _ in 0..<10 {
        guard let parent = currentElement.getParent() else { break }
        let role = parent.axRole() ?? ""
        if role == "AXDocument" || role == "AXWebArea" {
            let fileName = parent.axTitle()
            let filePath = extractFilePath(from: parent)
            return (fileName, filePath)
        }
        currentElement = parent
    }
    return (nil, nil)
}

func findPathInCommonLocations(fileName: String) -> String? {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let locations = [
        home.appendingPathComponent("Documents").path,
        home.appendingPathComponent("Desktop").path,
        home.appendingPathComponent("Downloads").path,
        NSTemporaryDirectory()
    ]
    for location in locations {
        let potentialPath = (location as NSString).appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: potentialPath) {
            return potentialPath
        }
    }
    return nil
}

func dumpAllAttributes(of element: AXUIElement) {
    if let names = AXUIElementCopyAttributeNamesAsArray(element) {
        print("Element has \(names.count) attributes:")
        for name in names {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success {
                print("   \(name): \(String(describing: value))")
            } else {
                print("   \(name): (no value)")
            }
        }
    } else {
        print("Failed to dump attributes for element")
    }
}

func collectTabElements(_ element: AXUIElement, tabInfos: inout [(element: AXUIElement, title: String, position: CGPoint)]) {
    if let role = element.axRole(), role.contains("Tab"),
       let title = element.axTitle(), !title.isEmpty {
        let position = element.axPosition()
        tabInfos.append((element, title, position))
    }
    guard let children = getAttributeElements(element, attribute: kAXChildrenAttribute as CFString) else { return }
    for child in children {
        collectTabElements(child, tabInfos: &tabInfos)
    }
}

private func getAttributeElements(_ element: AXUIElement, attribute: CFString) -> [AXUIElement]? {
    var arrayRef: CFArray?
    let result = AXUIElementCopyAttributeValues(element, attribute, 0, 100, &arrayRef)
    guard result == .success, let elements = arrayRef as? [AXUIElement] else { return nil }
    return elements
}

func getAllWindowsWithDocuments(appElement: AXUIElement) -> [(window: AXUIElement, fileName: String?, filePath: String?)] {
    var windowsInfo: [(AXUIElement, String?, String?)] = []
    guard let windows = getAttributeElements(appElement, attribute: kAXWindowsAttribute as CFString) else {
        print("Failed to get windows")
        return []
    }
    for window in windows {
        let windowTitle = window.axTitle()
        var filePath: String?
        if let document = window.getDocument() {
            filePath = extractFilePath(from: document)
        }
        if filePath == nil, let title = windowTitle, !title.isEmpty, title != "Untitled" {
            filePath = findPathInCommonLocations(fileName: title)
        }
        windowsInfo.append((window, windowTitle, filePath))
    }
    return windowsInfo
}

func findWindowContainingTextArea(_ textArea: AXUIElement,
                                  windows: [(window: AXUIElement, fileName: String?, filePath: String?)]) -> (fileName: String?, filePath: String?)? {
    guard let textAreaSize = try? textArea.axSize() else { return nil }
    let textAreaPreview = String((try? textArea.axValue())?.prefix(20) ?? "")
    for windowInfo in windows {
        let textAreas = findTextAreasInWindow(windowInfo.window)
        for windowTextArea in textAreas {
            let content = (try? windowTextArea.axValue()) ?? ""
            let windowTextAreaSize = (try? windowTextArea.axSize()) ?? .zero
            if content.hasPrefix(textAreaPreview) &&
                abs(windowTextAreaSize.width - textAreaSize.width) < 10 &&
                abs(windowTextAreaSize.height - textAreaSize.height) < 10 {
                return (windowInfo.fileName, windowInfo.filePath)
            }
        }
    }
    return nil
}

func findTextAreasInWindow(_ window: AXUIElement) -> [AXUIElement] {
    guard let children = getAttributeElements(window, attribute: kAXChildrenAttribute as CFString) else { return [] }
    var textAreas: [AXUIElement] = []
    func recursiveSearch(in element: AXUIElement, depth: Int = 0, maxDepth: Int = 5) {
        if depth > maxDepth { return }
        if element.axRole() == "AXTextArea" {
            textAreas.append(element)
            return
        }
        guard let children = getAttributeElements(element, attribute: kAXChildrenAttribute as CFString) else { return }
        for child in children {
            recursiveSearch(in: child, depth: depth + 1, maxDepth: maxDepth)
        }
    }
    for child in children {
        recursiveSearch(in: child)
    }
    return textAreas
}

func getWindowMappedDocumentInfo(_ textArea: AXUIElement, appElement: AXUIElement) -> (fileName: String?, filePath: String?) {
    let windowsWithDocs = getAllWindowsWithDocuments(appElement: appElement)
    if let docInfo = findWindowContainingTextArea(textArea, windows: windowsWithDocs) {
        return docInfo
    }
    return getUniqueDocumentInfo(textArea, appElement: appElement)
}

private func AXUIElementCopyAttributeNamesAsArray(_ element: AXUIElement) -> [String]? {
    var namesCF: CFArray?
    if AXUIElementCopyAttributeNames(element, &namesCF) == .success,
       let names = namesCF as? [String] {
        return names
    }
    return nil
}

#endif
