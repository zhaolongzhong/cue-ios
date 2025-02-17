import SwiftUI
import Combine

// MARK: - Toast Models & Types

struct ToastData: Equatable, Sendable {
    let message: String
    let style: ToastStyle
    let duration: TimeInterval
    let id = UUID()
    let shouldShowCloseButton: Bool
}

enum ToastStyle: Sendable {
    case success
    case error
    case warning

    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        }
    }
}

// MARK: - Toast Manager

@MainActor
final class ToastManager: ObservableObject, @unchecked Sendable {
    @Published private(set) var currentToast: ToastData?
    private var dismissTask: Task<Void, Never>?

    nonisolated init() {}

    func show(
        _ message: String,
        style: ToastStyle = .success,
        duration: TimeInterval = 3.0,
        shouldShowCloseButton: Bool = false
    ) {
        dismissTask?.cancel()

        let toast = ToastData(
            message: message,
            style: style,
            duration: duration,
            shouldShowCloseButton: shouldShowCloseButton
        )

        withAnimation(.spring()) {
            currentToast = toast
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

            guard let self = self, !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.spring()) {
                    self.currentToast = nil
                }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil

        withAnimation(.spring()) {
            currentToast = nil
        }
    }
}

// MARK: - Environment Key

private struct ToastManagerKey: EnvironmentKey {
    static let defaultValue: ToastManager = {
        let manager = ToastManager()
        return manager
    }()
}

extension EnvironmentValues {
    var toastManager: ToastManager {
        get { self[ToastManagerKey.self] }
        set { self[ToastManagerKey.self] = newValue }
    }
}

// MARK: - Toast View

struct Toast: View {
    let data: ToastData
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: data.style.iconName)
                .foregroundColor(data.style.color)
            Text(data.message)
                .font(.body)
            Spacer()
            if data.shouldShowCloseButton {
                DismissButton(action: onDismiss)
            }
        }
        .padding(.all, 16)
        .background(AppTheme.Colors.background)
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding(.horizontal)
        .frame(maxWidth: 400)
    }
}

// MARK: - Toast Container Modifier

struct ToastContainerModifier: ViewModifier {
    @StateObject private var manager = ToastManager()

    func body(content: Content) -> some View {
        ZStack {
            content

            GeometryReader { _ in
                if let toast = manager.currentToast {
                    VStack {
                        Toast(data: toast) {
                            manager.dismiss()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .offset(y: 16) // Add some padding from the top
                }
            }
        }
        .environment(\.toastManager, manager)
    }
}

// MARK: - View Extensions

extension View {
    func toastContainer() -> some View {
        modifier(ToastContainerModifier())
    }
}
