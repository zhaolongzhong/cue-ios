import Foundation
import SwiftUI

public enum Provider: String, CaseIterable, Codable, Equatable, Identifiable, Hashable, Sendable {
    case openai = "OPENAI_API_KEY"
    case anthropic = "ANTHROPIC_API_KEY"
    case gemini = "GEMINI_API_KEY"
    case cue = "CUE_API_KEY"
    case local = "LOCAL_API_KEY"

    public  var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .gemini: return "Gemini"
        case .cue: return "Cue"
        case .local: return "Local"
        }
    }

    var description: String {
        switch self {
        case .openai: return "GPT-4 and other OpenAI models inx"
        case .anthropic: return "Claude and other Anthropic models"
        case .gemini: return "Gemini Flash and Pro 2.0 models"
        case .cue: return "Many models"
        case .local: return "Run models on your device"
        }
    }

    var placeholder: String {
        switch self {
        case .openai: return "sk-..."
        case .anthropic: return "sk-ant-..."
        default:
            return "..."
        }
    }

    var iconName: String {
        switch self {
        case .openai: return "openai-icon"
        case .anthropic: return "anthropic"
        case .gemini: return "sparkle"
        case .cue: return "lasso.badge.sparkles"
        #if os(macOS)
        case .local: return "desktopcomputer.and.macbook"
        #else
        case .local: return "lock.iphone"
        #endif
        }
    }

    var isSystemIcon: Bool {
        switch self {
        case .openai, .anthropic:
            return false
        case .gemini, .local, .cue:
            return true
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .openai, .anthropic, .gemini:
            return true
        case .cue, .local:
            return false
        }
    }
}

extension Provider {
    @ViewBuilder
    var iconView: some View {
        iconViewWithSize(14)
    }

    @ViewBuilder
    func iconViewWithSize(_ size: CGFloat) -> some View {
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
extension Provider {
    nonisolated(unsafe) static var localBaseURL: String = "http://localhost:11434"
}
