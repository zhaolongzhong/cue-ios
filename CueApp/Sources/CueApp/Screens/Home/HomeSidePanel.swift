import SwiftUI
import Dependencies

final class SidePanelState: ObservableObject {
    @Published var isShowing = false
    @Published var selectedAssistant: Assistant?
    @Published var isShowingNewAssistant = false

    func togglePanel() {
        withAnimation(.easeOut) {
            isShowing.toggle()
        }
    }

    func hidePanel() {
        withAnimation(.easeOut) {
            isShowing = false
        }
    }

    func showPanel() {
        isShowing = true
    }
}

struct HomeSidePanel: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var apiKeyProviderViewModel: APIKeysProviderViewModel
    @ObservedObject var sidePanelState: SidePanelState
    @ObservedObject var assistantsViewModel: AssistantsViewModel
    @Binding var navigationPath: NavigationPath
    let onSelectAssistant: (Assistant) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if !apiKeyProviderViewModel.openAIKey.isEmpty || !apiKeyProviderViewModel.anthropicKey.isEmpty {
                            providersSection
                        }
                        assistantsSection
                    }
                }

                settingsRow
            }
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Cue")
                        .font(.title2)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        sidePanelState.isShowingNewAssistant = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            #endif
            .padding(.horizontal, 16)
            .background(AppTheme.Colors.secondaryBackground)
            .onAppear {
                Task {
                    await assistantsViewModel.fetchAssistants()
                }
            }
        }
        .sheet(isPresented: $sidePanelState.isShowingNewAssistant) {
            AddAssistantSheet(viewModel: assistantsViewModel)
        }
    }

    private var providersSection: some View {
        Section(header: providersHeader) {
            if !apiKeyProviderViewModel.openAIKey.isEmpty {
                openAIRow
            }
            if !apiKeyProviderViewModel.anthropicKey.isEmpty {
                anthropicRow
            }
        }
        #if os(iOS)
        .listSectionSpacing(.compact)
        #endif
    }

    private var providersHeader: some View {
        HStack {
            Text("Providers")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.secondary)
        }
    }

    private var assistantsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Assistants")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Divider()
            ForEach(assistantsViewModel.assistants) { assistant in
                AssistantRow(
                    assistant: assistant,
                    status: assistantsViewModel.getClientStatus(for: assistant),
                    actions: nil
                )
                .onTapGesture {
                    onSelectAssistant(assistant)
                }
            }
        }
    }

    private var openAIRow: some View {
        IconRow(
            title: "OpenAI",
            action: {
                navigationPath.append(HomeDestination.openai)
                sidePanelState.hidePanel()
            },
            iconName: "openai"
        )
    }

    private var anthropicRow: some View {
        IconRow(
            title: "Anthropic",
            action: {
                navigationPath.append(HomeDestination.anthropic)
                sidePanelState.hidePanel()
            },
            iconName: "anthropic"
        )
    }

    private var settingsRow: some View {
        IconRow(
            title: "Settings",
            action: {
                coordinator.showSettingsSheet()
            },
            iconName: "gearshape",
            isSystemImage: true
        )
    }
}
