import SwiftUI

struct EmailScreen: View {
    @StateObject private var viewModel: EmailScreenViewModel
    @State private var selectedCategory: EmailCategory?
    @State private var showingCategories: Bool = false
    @State private var showMicAlert: Bool = false
    private let onClose: () -> Void

    #if os(macOS)
    @ObservedObject var sharedNavState: SharedNavigationState
    public init(apiKey: String, sharedNavState: SharedNavigationState, onClose: @escaping () -> Void) {
        self.onClose = onClose
        self.sharedNavState = sharedNavState
        self._viewModel = StateObject(wrappedValue: EmailScreenViewModel(apiKey: apiKey))
    }
    #elseif os(iOS)
    public init(apiKey: String, onClose: @escaping () -> Void) {
        self.onClose = onClose
        self._viewModel = StateObject(wrappedValue: EmailScreenViewModel(apiKey: apiKey))
    }
    #endif

    var body: some View {
        Group {
            #if os(macOS)
            ZStack {
                NavigationSplitView(columnVisibility: $sharedNavState.columnVisibility) {
                    EmailCategoryView(
                        selectedCategory: $selectedCategory,
                        emailSummaries: viewModel.emailSummaries
                    )
                    .navigationSplitViewColumnWidth(min: WindowSize.sidebarMiniWidth, ideal: WindowSize.sidebarIdealWidth, max: WindowSize.sidebarMaxWidth)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            backButton
                        }
                    }
                } detail: {
                    EmailListView(
                        selectedCategory: $selectedCategory,
                        emailSummaries: viewModel.emailSummaries
                    )
                }
                .opacity(viewModel.processingState == .ready ? 1 : 0)
                .overlay(
                    ZStack {
                        if viewModel.processingState != .ready {
                            ProcessingOverlay(viewModel: viewModel)
                        }
                        VStack {
                            HStack(spacing: 12) {
                                Spacer()
                                micButton
                            }
                            .padding(.all, 8)
                            Spacer()
                        }
                    },
                    alignment: .topTrailing
                )
                .ignoresSafeArea(edges: .top)
            }
            .onChange(of: viewModel.showMicAlert) { _, granted in
                if !granted { showMicAlert = true }
            }
            .task {
                await viewModel.startProcessing()
            }
            #endif
            #if os(iOS)
            VStack {
                EmailListView(
                    selectedCategory: $selectedCategory,
                    emailSummaries: viewModel.emailSummaries
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 16) {
                            Menu {
                                Button {
                                    selectedCategory = nil
                                } label: {
                                    Label("All Emails (\(viewModel.emailSummaries.count))", systemImage: "tray")
                                }
                                Divider()
                                ForEach(EmailCategory.allCases, id: \.self) { category in
                                    let count = viewModel.emailSummaries.filter { $0.category == category }.count
                                    Button {
                                        selectedCategory = category
                                    } label: {
                                        Label {
                                            Text("\(category.displayName) (\(count))")
                                        } icon: {
                                            categoryIcon(for: category)
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .tint(.primary)
                            micButton
                        }
                    }
                }
                .overlay {
                    if viewModel.processingState != .ready {
                        ProcessingOverlay(viewModel: viewModel)
                    }
                }
            }
            .task {
                await viewModel.startProcessing()
            }
            #endif
        }
        .alert("Microphone Access Required", isPresented: $showMicAlert) {
            Button("Open Settings") {
                AudioPermissionHandler.openSettings()
                showMicAlert = false
            }
            Button("Cancel", role: .cancel) { showMicAlert = false }
        } message: {
            Text("Please enable microphone access in Settings to use voice chat.")
        }
    }

    private var backButton: some View {
        Button {
            viewModel.stopSession()
            onClose()
        } label: {
            HStack {
                Image(systemName: "chevron.left")
                Text("Back")
            }
        }
        .buttonStyle(.plain)
        .opacity(viewModel.processingState == .ready ? 1 : 0)
    }

    private var micButton: some View {
        Group {
            if viewModel.voiceChatState == .active || viewModel.processingState != .ready {
                StopButton {
                    Task {
                        if viewModel.voiceChatState == .active {
                            viewModel.stopVoiceChat()
                        } else {
                            onClose()
                        }
                    }
                }
                .tint(.primary)
            } else {
                CircularButton(systemImage: "mic", backgroundColor: AppTheme.Colors.primaryText) {
                    Task {
                        if viewModel.voiceChatState == .active {
                            viewModel.stopVoiceChat()
                        } else {
                            await viewModel.startVoiceChat()
                        }
                    }
                }
            }
        }
        .padding(.all, 8)
    }
}
