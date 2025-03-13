import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

public enum AccessibleApplication: CaseIterable, Sendable {
    case xcode
    case androidStudio
    case visualStudioCode
    case cursor
    case windsurf
    case terminal
    case notes
    case textEdit
    case scriptEditor
}

extension AccessibleApplication {
    var bundleId: String {
        switch self {
        case .xcode:
            return "com.apple.dt.Xcode"
        case .androidStudio:
            return "com.google.android.studio"
        case .visualStudioCode:
            return "com.microsoft.VSCode"
        case .cursor:
            return "com.todesktop.230313mzl4w4u92"
        case .windsurf:
            return "com.exafunction.windsurf"
        case .terminal:
            return "com.apple.Terminal"
        case .textEdit:
            return "com.apple.TextEdit"
        case .notes:
            return "com.apple.Notes"
        case .scriptEditor:
            return "com.apple.ScriptEditor2"
        }
    }

    var name: String {
        switch self {
        case .xcode:
            return "Xcode"
        case .androidStudio:
            return "Android Studio"
        case .visualStudioCode:
            return "Code"
        case .cursor:
            return "Cursor"
        case .windsurf:
            return "Windsurf"
        case .terminal:
            return "Terminal"
        case .textEdit:
            return "TextEdit"
        case .notes:
            return "Notes"
        case .scriptEditor:
            return "Script Editor"
        }
    }

    var icon: Image {
        #if os(macOS)
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: self.bundleId) {
            let nsImage = NSWorkspace.shared.icon(forFile: appURL.path)
            nsImage.size = NSSize(width: 16, height: 16)
            return Image(nsImage: nsImage)
        }
        #endif
        return Image(systemName: "app")
    }

    var isVSCodeIDE: Bool {
        switch self {
        case .visualStudioCode, .windsurf, .cursor:
            return true
        default:
            return false
        }

    }

    static func fromEditorName(_ editorName: String) -> AccessibleApplication? {
        let normalizedName = editorName.lowercased()

        if normalizedName.contains("visual studio code") ||
           normalizedName.contains("vs code") ||
           normalizedName.contains("vscode") {
            return .visualStudioCode
        }

        if normalizedName.contains("windsurf") {
            return .windsurf
        }

        if normalizedName.contains("cursor") {
            return .cursor
        }

        if normalizedName.contains("xcode") {
            return .xcode
        }

        if normalizedName.contains("android studio") {
            return .androidStudio
        }

        if normalizedName.contains("terminal") {
            return .terminal
        }

        if normalizedName.contains("textedit") || normalizedName.contains("text edit") {
            return .textEdit
        }

        if normalizedName.contains("notes") {
            return .notes
        }

        if normalizedName.contains("script editor") ||
           normalizedName.contains("scripteditor") ||
           normalizedName.contains("applescript editor") {
            return .scriptEditor
        }

        return nil
    }
}
