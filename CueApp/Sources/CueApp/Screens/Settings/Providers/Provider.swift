import Foundation
import SwiftUI

public enum Provider: String, CaseIterable, Identifiable {
    case openai = "OPENAI_API_KEY"
    case anthropic = "ANTHROPIC_API_KEY"
    case gemini = "GEMINI_API_KEY"
    case cue = "CUE_API_KEY"

    public  var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .gemini: return "Gemini"
        case .cue: return "Cue"
        }
    }

    var placeholder: String {
        switch self {
        case .openai: return "sk-..."
        case .anthropic: return "sk-ant-..."
        case .gemini: return "..."
        case .cue: return "..."
        }
    }

    var iconName: String {
        switch self {
        case .openai: return "openai"
        case .anthropic: return "anthropic"
        case .gemini: return "sparkle"
        case .cue: return ""
        }
    }

    var isSystemIcon: Bool {
        switch self {
        case .openai, .anthropic, .cue:
            return false
        case .gemini:
            return true
        }
    }
}

extension Provider {
    @ViewBuilder
    var iconView: some View {
        let size: CGFloat = 14
        if self == .cue {
            EmptyView()
        } else if isSystemIcon {
            Image(systemName: iconName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(iconName, bundle: Bundle.module)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}
