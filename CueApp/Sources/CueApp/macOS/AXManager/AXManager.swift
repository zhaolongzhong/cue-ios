import Accessibility
import AppKit
import os

final class AXManager: ObservableObject {
    @Published var textAreaContentList: [TextAreaContent] = []
    private var app: AccessibleApplication
    private var targetBundleId: String
    private var observer: AXObserver?
    private let logger = Logger(subsystem: "AXManager", category: "axManager")

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

    // MARK: - Loading Text Areas

    func loadTextAreas() {
        guard let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: targetBundleId).first else {
            return
        }
        let pid = runningApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        let textAreas = findTextAreas(in: appElement)
        textAreaContentList = textAreas.enumerated().map { index, element in
            return TextAreaContent(
                id: index,
                content: (try? element.axValue()) ?? "",
                size: (try? element.axSize()) ?? .zero,
                selectionRange: (try? element.axSelectionRange()),
                selectionLines: element.axSelectionLines(),
                selectionLinesRange: element.axSelectionLineRange()
            )
        }

        debugPrint("\n=== Text Area Content Summary ===")
        debugPrint("Total textAreaContent loaded: \(textAreaContentList.count)\n")

        for (index, content) in textAreaContentList.enumerated() {
            debugPrint("📝 Text Area #\(index)")
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

    private func findTextAreas(in appElement: AXUIElement) -> [AXUIElement] {
        appElement.findElements(ofRole: kAXTextAreaRole as CFString, depth: 0).filter { element in
            let description = try? element.axDescription()
            if description == "Console" || description == "debug console" {
                // skip console log for xcode
                return false
            }
            return element.isTextFieldOfReasonableSize
        }
    }
}

extension AXManager {
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
}
