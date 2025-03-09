import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

public enum AccessibleApplication: CaseIterable {
    case xcode
    case terminal
    case visualStudioCode
    case textEdit
    case notes
}

extension AccessibleApplication {
    var bundleId: String {
        switch self {
        case .xcode:
            return "com.apple.dt.Xcode"
        case .terminal:
            return "com.apple.Terminal"
        case .textEdit:
            return "com.apple.TextEdit"
        case .notes:
            return "com.apple.Notes"
        case .visualStudioCode:
            return "com.microsoft.VSCode"
        }
    }
    var name: String {
        switch self {
        case .xcode:
            return "Xcode"
        case .terminal:
            return "Terminal"
        case .textEdit:
            return "TextEdit"
        case .notes:
            return "Notes"
        case .visualStudioCode:
            return "Visual Studio Code"
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
}

#if os(macOS)
struct AXAppSelectionMenu: View {
    @State private var selectedApp: AccessibleApplication = .textEdit
    let onStartAXApp: ((AccessibleApplication) -> Void)?

    var body: some View {
        Menu {
            ForEach(AccessibleApplication.allCases, id: \.self) { app in
                Button {
                    selectedApp = app
                    onStartAXApp?(selectedApp)
                } label: {
                    HStack {
                        app.icon
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text(app.name)
                            .frame(minWidth: 200, alignment: .leading)
                    }
                }
            }
        } label: {
            Image(systemName: "link.badge.plus")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .withIconHover()
    }
}
#endif
