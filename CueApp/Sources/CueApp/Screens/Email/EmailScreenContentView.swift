import SwiftUI

struct EmailScreenContentView: View {
    @Binding var selectedCategory: EmailCategory?
    @State private var navigationPath = NavigationPath()
    @ObservedObject private var viewModel: EmailScreenViewModel
    @State private var showingReplySheet = false
    @State private var selectedEmailForReply: EmailSummary?
    @State private var replyViewOffset: CGFloat = 1000
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @Environment(\.toastManager) private var toastManager

    init(emailViewModel: EmailScreenViewModel, selectedCategory: Binding<EmailCategory?>) {
        self.viewModel = emailViewModel
        _selectedCategory = selectedCategory
    }

    private var filteredEmails: [EmailSummary] {
        guard let category = selectedCategory else {
            return viewModel.emailSummaries
        }
        return viewModel.emailSummaries
            .filter { $0.category == category }
    }

    var body: some View {
        #if os(macOS)
        NavigationStack(path: $navigationPath) {
            mainContent
                .onChange(of: showingReplySheet, handleReplySheetChange)
        }
        .navigationDestination(for: EmailRoute.self) { route in
            switch route {
            case .emailDetail(let email):
                EmailDetailView(emailViewModel: viewModel, emailSummary: email)
            }
        }
        .overlay { emptyStateOverlay }
        .frame(minWidth: 400)
        .onDisappear {
            Task {
                await viewModel.updateState(.idle)
            }
        }
        #endif
        #if os(iOS)
        mainContent
            .sheet(isPresented: $showingReplySheet) {
                if let email = selectedEmailForReply,
                   let emailDetails = viewModel.originalEmails[email.id] {
                    NavigationStack {
                        EmailReplyView(
                            emailSummary: email,
                            emailDetails: emailDetails,
                            emailViewModel: viewModel,
                            onDismiss: handleReplyDismiss
                        )
                    }
                }
            }
        #endif
    }

    @ViewBuilder
    private var mainContent: some View {
        ZStack(alignment: .top) {
            BackgroundContainer()

            if viewModel.processingState.isLoading {
                loadingView
            } else if !filteredEmails.isEmpty {
                emailContentView
            }

            if showingReplySheet {
                replySheetView
            }
        }
    }

    @ViewBuilder
    private var emailContentView: some View {
        ScrollView {
            if selectedCategory == nil {
                allEmailSection
            } else {
                sectionViews
            }
        }
    }

    @ViewBuilder
    private var allEmailSection: some View {
        ForEach(filteredEmails) { email in
            EmailRow(email: email)
                .onTapGesture {
                    openEmailDetail(email)
                }
                .contextMenu {
                    Button {
                        handleArchive([email])
                    } label: {
                        Text("Archive")
                    }

                    Button {
                        selectedEmailForReply = email
                        showingReplySheet = true
                    } label: {
                        Text("Reply")
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical)
            Divider()
                .padding(.horizontal, 32)
        }
    }

    @ViewBuilder
    private var sectionViews: some View {
        switch selectedCategory {
        case .newsletters:
            NewslettersSection(
                sectionTitle: "Newsletters",
                sectionOtherTitle: "Other newsletters",
                emailSummaries: filteredEmails,
                showGradientBorder: true,
                onOpenDetail: openEmailDetail,
                onArchive: handleArchive
            )
        case .updates:
            NewslettersSection(
                sectionTitle: "Updates",
                sectionOtherTitle: "Other updates",
                emailSummaries: filteredEmails,
                onOpenDetail: openEmailDetail,
                onArchive: handleArchive
            )
        case .actionItems:
            ActionItemsSection(
                sectionTitle: "Action Items",
                emailSummaries: filteredEmails,
                onOpenDetail: openEmailDetail,
                onArchive: handleArchive
            )
        case .replies:
            RepliesSection(
                sectionTitle: "Replies",
                emailSummaries: filteredEmails,
                onReply: handleReply,
                onOpenDetail: openEmailDetail,
                onArchive: handleArchive
            )
        default:
            EmptyView()
        }
    }

    private var replySheetView: some View {
        Group {
            if let email = selectedEmailForReply,
               let emailDetails = viewModel.originalEmails[email.id] {
                EmailReplyView(
                    emailSummary: email,
                    emailDetails: emailDetails,
                    emailViewModel: viewModel,
                    onDismiss: handleReplyDismiss
                )
                .padding(.top, 20)
                .offset(y: replyViewOffset)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom),
                    removal: .move(edge: .bottom)
                ))
                .onAppear(perform: animateReplySheet)
            }
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var emptyStateOverlay: some View {
        if filteredEmails.isEmpty && !viewModel.processingState.isLoading {
            ContentUnavailableView(
                "No Emails",
                systemImage: "tray.fill",
                description: Text("No emails in this category")
            )
        }
    }

    // MARK: - Helper Functions

    private func openEmailDetail(_ email: EmailSummary) {
        #if os(iOS)
        homeViewModel.navigationPath.append(EmailRoute.emailDetail(email))
        #endif
        #if os(macOS)
        navigationPath.append(EmailRoute.emailDetail(email))
        #endif
    }

    private func handleArchive(_ emails: [EmailSummary]) {
        Task {
            await handleArchiveResult(emails)
        }
    }

    private func handleArchiveResult(_ emails: [EmailSummary]) async {
        let ids = emails.map(\.id)
        do {
            try await viewModel.archiveEmails(ids)
            toastManager.show("Email archived successfully")
        } catch {
            AppLog.log.error("Email error: \(error.localizedDescription)")
            toastManager.show("Failed to archive email", style: .error)
        }
    }

    private func handleReply(_ email: EmailSummary) {
        if viewModel.originalEmails[email.id] != nil {
            selectedEmailForReply = email
            showingReplySheet = true
        } else {
            Task {
                _ = await viewModel.getEmail(email.id)
                selectedEmailForReply = email
                showingReplySheet = true
            }
        }
    }

    private func handleReplyDismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            replyViewOffset = 1000
            showingReplySheet = false
        }
        selectedEmailForReply = nil
    }

    private func animateReplySheet() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            replyViewOffset = 0
        }
    }

    private func handleReplySheetChange(_ oldValue: Bool, _ newValue: Bool) {
        if newValue {
            replyViewOffset = 1000
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                replyViewOffset = 0
            }
        }
    }
}
