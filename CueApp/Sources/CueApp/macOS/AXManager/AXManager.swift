import Accessibility

#if os(macOS)
import AppKit
import os

enum IDEType {
    case androidStudio
    case xcode
    case other
}

final class AXManager: ObservableObject {
    @Published var textAreaContentList: [TextAreaContent] = []
    private var app: AccessibleApplication
    private var targetBundleId: String
    private var observer: AXObserver?
    private let logger = Logger(subsystem: "AXManager", category: "axManager")

    // For debouncing updates
    private var lastUpdateTime: Date = Date()
    private let updateThrottleInterval: TimeInterval = 0.5 // seconds

    // For tracking content changes
    private var lastContentHash: Int = 0

    init(app: AccessibleApplication = .textEdit) {
        self.app = app
        self.targetBundleId = app.bundleId
    }

    private func startObservingSelectionChanges() {
        guard let runningApp = NSRunningApplication
            .runningApplications(withBundleIdentifier:
                                    targetBundleId).first else {
            return
        }
        let pid = runningApp.processIdentifier
        setupObserver(for: pid)
    }

    private func setupObserver(for pid: pid_t) {
        guard observer == nil else { return }

        var newObserver: AXObserver?
        let observerCallback: AXObserverCallback = { _, _, notification, context in
            guard let context = context else { return }
            let manager = Unmanaged<AXManager>.fromOpaque(context).takeUnretainedValue()
            print("Notification received: \(notification)")
            manager.loadTextAreas()
        }
        // Use the static closure as the callback
        let result = AXObserverCreate(pid, observerCallback, &newObserver)
        guard result == .success, let newObserver = newObserver else {
            return
        }

        self.observer = newObserver

        let appElement = AXUIElementCreateApplication(pid)
        let contextPointer = Unmanaged.passUnretained(self).toOpaque()

        let notifications = [
            kAXSelectedTextChangedNotification,
//            kAXValueChangedNotification, // it might change too often for some app
            kAXFocusedUIElementChangedNotification
        ]

        for notification in notifications {
            let addResult = AXObserverAddNotification(newObserver,
                                                    appElement,
                                                    notification as CFString,
                                                    contextPointer)

            if addResult != .success {
                self.logger.debug("Failed to add notification \(notification): \(addResult.rawValue)")
            }
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                           AXObserverGetRunLoopSource(newObserver),
                           CFRunLoopMode.defaultMode)

    }

    func stopObserving() {
        guard let observer else { return }
        CFRunLoopRemoveSource(
            CFRunLoopGetCurrent(),
            AXObserverGetRunLoopSource(observer),
            CFRunLoopMode.defaultMode
        )
        self.observer = nil
    }

    func updateObservedApplication(to newApp: AccessibleApplication) {
        stopObserving()
        self.app = newApp
        self.targetBundleId = newApp.bundleId
        startObservingSelectionChanges()
    }

    // MARK: - Loading Text Areas

    func loadTextAreas() {
        guard let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: targetBundleId).first else {
                return
            }
        let pid = runningApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Get text areas first to check for content changes
        let textAreas = findTextAreas(in: appElement)

        // Calculate a content hash to detect changes
        var combinedContent = ""
        for element in textAreas {
            combinedContent += (try? element.axValue()) ?? ""
        }
        let contentHash = combinedContent.hashValue

        // Check time throttling only if content hasn't changed
        let now = Date()
        if contentHash == lastContentHash && !textAreaContentList.isEmpty {
            if now.timeIntervalSince(lastUpdateTime) < updateThrottleInterval {
                print("Throttling update - content unchanged")
                return
            } else {
                print("Content unchanged but throttle time elapsed - proceeding with update")
            }
        } else {
            // If content changed, reset the throttle timer but allow the update to proceed
            print("Content changed - proceeding with update")
        }

        // Get IDE type
        let ideType = detectIDEType(runningApp)

        // Get all windows and their documents for a global view
        let windowsWithDocs = getAllWindowsWithDocuments(appElement: appElement)
        print("Found \(windowsWithDocs.count) windows with documents:")
        for (index, windowInfo) in windowsWithDocs.enumerated() {
            print("Window #\(index): title=\(windowInfo.fileName ?? "nil"), path=\(windowInfo.filePath ?? "nil")")
        }

        textAreaContentList = textAreas.enumerated().map { index, element in
            let (fileName, filePath): (String?, String?) = {
                return getWindowMappedDocumentInfo(element, appElement: appElement)
            }()

           // Debug info
           let uniqueID = getUniqueIdentifierForTextArea(element)
            debugPrint("TextArea #\(index) (ID: \(uniqueID)): fileName: \(fileName ?? "nil"), filePath: \(filePath ?? "nil")")

            if index == 0 && filePath == nil {
                dumpHierarchyBasedOnIDEType(element, appElement: appElement, ideType: ideType)
            }

            return TextAreaContent(
                id: index,
                content: (try? element.axValue()) ?? "",
                size: (try? element.axSize()) ?? .zero,
                selectionRange: (try? element.axSelectionRange()),
                selectionLines: element.axSelectionLines(),
                selectionLinesRange: element.axSelectionLineRange(),
                fileName: fileName,
                filePath: filePath,
                app: self.app
            )
        }
        printTextAreaSummary()
    }

    private func findTextAreas(in appElement: AXUIElement) -> [AXUIElement] {
        appElement.findElements(ofRole: kAXTextAreaRole as CFString, depth: 0).filter { element in
            let description = try? element.axDescription()
            debugPrint("findTextAreas description: \(String(describing: description))")
            if description == "Console" || description == "debug console" {
                // skip console log for xcode
                return false
            }
            return element.isTextFieldOfReasonableSize
        }
    }
}

extension AXManager {
    func detectIDEType(_ runningApp: NSRunningApplication) -> IDEType {
        return .other
    }

    // Helper to print text area summary
    private func printTextAreaSummary() {
        debugPrint("\n=== Text Area Content Summary ===")
        debugPrint("Total textAreaContent loaded: \(textAreaContentList.count)\n")

        for (index, content) in textAreaContentList.enumerated() {
            debugPrint("📝 Text Area #\(index)")
            debugPrint("├─ File name: \(content.fileName ?? "nil")")
            debugPrint("├─ File path: \(content.filePath ?? "nil")")
            debugPrint("├─ Content length: \(content.content.count) characters")
            debugPrint("├─ Size: \(content.size.width)x\(content.size.height)")
            debugPrint("├─ Selection range: \(content.selectionRange?.description ?? "none")")
            debugPrint("├─ Selected lines: \(content.selectionLines.count), lines: \(content.selectionLines)")
            if let lineRange = content.selectionLinesRange {
                debugPrint("└─ Line range: \(lineRange.startLine)-\(lineRange.endLine)")
            } else {
                debugPrint("└─ Line range: none")
            }
        }
    }

    // Helper to dump hierarchy based on IDE type
    private func dumpHierarchyBasedOnIDEType(_ element: AXUIElement, appElement: AXUIElement, ideType: IDEType) {
        dumpWindowStructure(appElement)
    }
}
#endif
