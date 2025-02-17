import SwiftUI

enum EmailRoute: Hashable {
    case emailDetail(EmailSummary)
}

struct EmailScreen: View {
    // MARK: - Environment & Observed Objects
    @EnvironmentObject private var apiKeysProviderViewModel: APIKeysProviderViewModel
    @ObservedObject private var viewModel: EmailScreenViewModel

    // MARK: - State Properties
    #if os(macOS)
    @Binding private var selectedEmailCategory: EmailCategory?
    #endif
    #if os(iOS)
    @State private var selectedEmailCategory: EmailCategory? = .newsletters
    #endif
    @State private var showingCategories = false
    @State private var showMicAlert = false
    @State private var selectedMessage: EmailSummary?
    @State private var showToolbar = true
    @State private var progressViewOffset: CGFloat = 1000
    @State private var showingMaxEmailAlert = false
    @State private var maxEmailInput = ""
    @AppStorage("max_emails") private var maxEmails = 20

    // MARK: - Initialization

    #if os(macOS)
    public init(emailScreenViewModel: EmailScreenViewModel, selectedEmailCategory: Binding<EmailCategory?>) {
        self.viewModel = emailScreenViewModel
        self._selectedEmailCategory = selectedEmailCategory
    }
    #endif

    #if os(iOS)
    public init(emailScreenViewModel: EmailScreenViewModel) {
        self.viewModel = emailScreenViewModel
    }
    #endif

    // MARK: - Body

    var body: some View {
        Group {
            #if os(macOS)
            macOSLayout
            #endif
            #if os(iOS)
            iOSLayout
            #endif
        }
        .onAppear(perform: handleOnAppear)
        .onChange(of: viewModel.showMicAlert) { _, granted in
            handleMicAlertChange(granted)
        }
        .alert("Microphone Access Required", isPresented: $showMicAlert) {
            microphoneAlert
        } message: {
            Text("Please enable microphone access in Settings to use voice chat.")
        }
        .toastContainer()
    }

    // MARK: - Platform Specific Layouts

    #if os(macOS)
    private var macOSLayout: some View {
        EmailScreenContentView(
            emailViewModel: viewModel,
            selectedCategory: $selectedEmailCategory
        )
        .overlay(progressOverlay, alignment: .topTrailing)
        .toolbar {
            if !viewModel.processingState.isLoading {
                macOSToolbarContent
            }
        }
        .toolbarRole(.editor)
    }
    #endif

    #if os(iOS)
    private var iOSLayout: some View {
        EmailScreenContentView(
            emailViewModel: viewModel,
            selectedCategory: $selectedEmailCategory
        )
        .navigationDestination(for: EmailRoute.self) { route in
            switch route {
            case .emailDetail(let email):
                EmailDetailView(emailViewModel: viewModel, emailSummary: email)
            }
        }
        .overlay(progressOverlay, alignment: .topTrailing)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            iOSToolbarContent
        }
    }
    #endif

    // MARK: - Common Components

    private var microphoneAlert: some View {
        Group {
            Button("Open Settings") {
                AudioPermissionHandler.openSettings()
                showMicAlert = false
            }
            Button("Cancel", role: .cancel) {
                showMicAlert = false
            }
        }
    }

    private var micButton: some View {
        Group {
            if viewModel.voiceChatState == .active {
                EndSessionButton {
                    Task {
                        handleEndSession()
                    }
                }
            } else {
                CircularButton(
                    systemImage: "mic",
                    backgroundColor: AppTheme.Colors.primaryText
                ) {
                    Task {
                        await handleMicButtonTap()
                    }
                }
            }
        }
        .padding(.all, 8)
    }

    private var progressOverlay: some View {
        ZStack(alignment: .top) {
            if viewModel.processingState.isLoading {
                ProgressStepCard(sectionTitle: viewModel.processingState.description)
                    #if os(macOS)
                    .offset(y: progressViewOffset)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom),
                        removal: .move(edge: .bottom)
                    ))
                    .onAppear {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            progressViewOffset = 0
                        }
                    }
                    #endif
            }
        }
    }

    private var settingsContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Button {
                    showingMaxEmailAlert = true
                } label: {
                    Label {
                        Text("Max emails (\(maxEmails))")
                    } icon: {
                        Image(systemName: "envelope.badge")
                            .foregroundStyle(.primary.opacity(0.8))
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.primary)
            }
            .menuIndicator(.hidden)
            .numberInputAlert(
                title: "Set Maximum Emails",
                message: "Enter the maximum number of emails for each session.",
                isPresented: $showingMaxEmailAlert,
                inputValue: $maxEmailInput,
                onSave: { newValue in
                    self.maxEmails = newValue
                }
            )
        }
    }

    // MARK: - Platform Specific Components

    #if os(macOS)
    @ToolbarContentBuilder
    private var macOSToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Text("\(viewModel.weekDay), ")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.leading, 16)
        }
        ToolbarItem(placement: .navigation) {
            Text(viewModel.monthDay)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary.opacity(0.7))
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Spacer()
            micButton
                .padding(.vertical, 8)
        }
        settingsContent
    }
    #endif

    #if os(iOS)
    @ToolbarContentBuilder
    private var iOSToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                micButton
                categoryMenu
            }
        }
        settingsContent
    }

    private var categoryMenu: some View {
        Menu {
            categoryMenuContent
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .fontWeight(.medium)
        }
        .buttonStyle(.bordered)
        .tint(.primary)
    }

    @ViewBuilder
    private var categoryMenuContent: some View {
        Button {
            selectedEmailCategory = nil
        } label: {
            Label("All Emails (\(viewModel.emailSummaries.count))", systemImage: "tray")
        }

        Divider()

        ForEach(EmailCategory.allCases, id: \.self) { category in
            let count = viewModel.emailSummaries.filter { $0.category == category }.count
            Button {
                selectedEmailCategory = category
            } label: {
                Label {
                    Text("\(category.displayName) (\(count))")
                } icon: {
                    categoryIcon(for: category)
                }
            }
        }
    }
    #endif

    // MARK: - Action Handlers

    private func handleOnAppear() {
        let apiKey = apiKeysProviderViewModel.openAIKey
        viewModel.updateApiKey(apiKey)

        if viewModel.processingState != .ready {
            Task {
                await viewModel.startProcessing()
            }
        }
    }

    private func handleMicAlertChange(_ granted: Bool) {
        if !granted {
            showMicAlert = true
        }
    }

    private func handleEndSession() {
        if viewModel.voiceChatState == .active {
            viewModel.stopSession()
        }
    }

    private func handleMicButtonTap() async {
        if viewModel.voiceChatState == .active {
            viewModel.stopSession()
        } else {
            await viewModel.startVoiceChat()
        }
    }
}
