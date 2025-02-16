public enum AccessibleApplication: CaseIterable {
    case xcode
    case textEdit
    case notes
    case visualStudioCode
}

extension AccessibleApplication {
    var bundleId: String {
        switch self {
        case .xcode:
            return "com.apple.dt.Xcode"
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
        case .textEdit:
            return "TextEdit"
        case .notes:
            return "Notes"
        case .visualStudioCode:
            return "Visual Studio Code"
        }
    }
}
