import SwiftUI
import CueGemini

public struct GeminiLiveChatView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: GeminiChatViewModel
    @FocusState private var isFocused: Bool
    @State private var showingToolsList = false

    public init(apiKey: String) {
        _viewModel = StateObject(wrappedValue: GeminiChatViewModel(apiKey: apiKey))
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                GlassmorphismParticleBackgroundView(screenSize: geometry.size)
                    .opacity(colorScheme == .dark ? 0.6 : 0.9)
                    .ignoresSafeArea(.all)
                    .zIndex(0)

                VStack(spacing: 16) {
                    Spacer()
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(viewModel.messageContent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 48)
                                .id("messageBottom")
                        }
                        .frame(maxHeight: .infinity)
                        .onChange(of: viewModel.messageContent) { _, newValue in
                            if !newValue.isEmpty {
                                withAnimation {
                                    proxy.scrollTo("messageBottom", anchor: .bottom)
                                }
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .padding(.vertical, 60)

                    controlButtons
                    RichTextField(onShowTools: {
                        showingToolsList = true
                    }, onSend: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }, toolCount: viewModel.availableTools.count, inputMessage: $viewModel.newMessage, isFocused: $isFocused)
                    .padding(.horizontal, 8)
                }
                .padding(.vertical)
                .zIndex(1)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    DismissButton(action: {
                        viewModel.disconnect()
                        dismiss()
                    })
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
        }
        .onAppear {
            Task {
                await viewModel.startServer()
            }
        }
        .onChange(of: viewModel.error) { _, error in
            if let error = error {
                coordinator.showError(error.message)
                viewModel.clearError()
            }
        }
        .sheet(isPresented: $showingToolsList) {
            ToolsListView(tools: viewModel.availableTools)
        }
    }

    private var controlButtons: some View {
        HStack(alignment: .center, spacing: 50) {
            Button(action: handleConnectionButton) {
                Image(systemName: connectionButtonIcon)
                    .font(.system(size: platformButtonFontSize, weight: .bold))
                    .frame(width: platformButtonSize, height: platformButtonSize)
                    .foregroundColor(connectionButtonColor)
                    .background(Circle().fill(AppTheme.Colors.controlButtonBackground))
            }
            .buttonStyle(.plain)
        }
    }

    private func handleConnectionButton() {
        Task {
            if viewModel.state.isConnected {
                viewModel.disconnect()
            } else {
                do {
                    try await viewModel.connect()
                } catch {
                    AppLog.log.error("Failed to connect: \(error.localizedDescription)")
                }
            }
        }
    }

    private var connectionButtonIcon: String {
        if viewModel.state.isConnected {
            return "xmark"
        } else {
            return "mic"
        }
    }

    private var connectionButtonColor: Color {
        if viewModel.state.isConnected {
            return .red
        } else {
            return .gray
        }
    }
}
