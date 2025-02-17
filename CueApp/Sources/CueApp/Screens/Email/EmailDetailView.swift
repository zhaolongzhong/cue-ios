import SwiftUI
import WebKit

struct EmailDetailView: View {
    @ObservedObject var emailViewModel: EmailScreenViewModel
    let emailSummary: EmailSummary
    @StateObject private var viewModel = EmailDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingReplySheet = false
    @State private var replyViewOffset: CGFloat = 1000

    var body: some View {
        Group {
            #if os(macOS)
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    BackgroundContainer()
                    contentView
                        .frame(maxHeight: geometry.size.height)

                    if showingReplySheet {
                        replySheetView
                            .frame(height: geometry.size.height * 0.7)
                            .transition(.move(edge: .bottom))
                            .padding(.top, 100)
                    }
                }
                .frame(maxHeight: geometry.size.height)
                .onChange(of: showingReplySheet, handleReplySheetChange)
            }
            #endif
            #if os(iOS)
            contentView
                .sheet(isPresented: $showingReplySheet) {
                    if let emailDetails = emailViewModel.originalEmails[emailSummary.id] {
                        NavigationStack {
                            EmailReplyView(
                                emailSummary: emailSummary,
                                emailDetails: emailDetails,
                                emailViewModel: emailViewModel,
                                onDismiss: handleReplyDismiss
                            )
                        }
                    }
                }
        #endif
        }
        .defaultNavigationBar(showCustomBackButton: true, title: "Details")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Spacer()
                Menu {
                    Button {
                        handleReply(emailSummary)
                    } label: {
                        Label {
                            Text("Reply")
                        } icon: {
                            Image(systemName: "arrow.turn.up.left")
                                .foregroundStyle(.primary.opacity(0.8))
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.primary)
                }
                .menuIndicator(.hidden)
            }
        }
        .onAppear(perform: handleOnAppear)
    }

    @ViewBuilder
     private var contentView: some View {
         ZStack(alignment: .top) {
             BackgroundContainer()

             switch viewModel.state {
             case .loading:
                 loadingView
             case .error(let error):
                 ErrorView(error: error)
             case .loaded(let message):
                 emailDetailContent(message)
             case .empty:
                 EmptyView()
             }
         }
     }

    private var replySheetView: some View {
        Group {
            if let emailDetails = emailViewModel.originalEmails[emailSummary.id] {
                EmailReplyView(
                    emailSummary: emailSummary,
                    emailDetails: emailDetails,
                    emailViewModel: emailViewModel,
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
    private func emailDetailContent(_ message: GmailMessage) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    emailHeaderSection(message)
                    tagsSection
                    contentDivider
                    emailBodySection(message, geometry: geometry)
                    actionRequiredSection
                }
                .padding([.horizontal])
            }
        }
        .padding()
        .background(.background)
    }

    @ViewBuilder
    private func emailHeaderSection(_ message: GmailMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.subject)
                .font(.headline)

            #if os(macOS)
            HStack {
                Text("From:")
                    .foregroundColor(.secondary)
                    .fontWeight(.bold)
                Text(message.from)
                    .foregroundColor(.secondary)
                Spacer()
                Text(message.messageDate)
                    .foregroundColor(.secondary)
            }
            #endif
            #if os(iOS)
            Text("From: \(message.from)")
                .foregroundColor(.secondary)
                .font(.footnote)
            Text(message.receivedAt?.relativeDate ?? "")
                .foregroundColor(.secondary)
                .font(.footnote)
            #endif
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        if !emailSummary.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(emailSummary.tags, id: \.self) { tag in
                        TagView(tag: tag)
                    }
                }
            }
        }
    }

    private var contentDivider: some View {
        Divider()
            .padding(.horizontal)
    }

    private func emailBodySection(_ message: GmailMessage, geometry: GeometryProxy) -> some View {
        WebView(htmlContent: message.htmlContent ?? message.plainTextContent ?? extractEmailBody(from: message))
            .frame(minHeight: geometry.size.height)
    }

    @ViewBuilder
    private var actionRequiredSection: some View {
        if emailSummary.requiresAction {
            ActionRequiredView()
                .padding(.horizontal)
        }
    }

    // MARK: - Helper Methods

    private func handleOnAppear() {
        viewModel.loadEmailDetails(emailId: emailSummary.id)
        if !emailSummary.isRead {
            viewModel.markAsRead(emailId: emailSummary.id)
        }
    }
}

// MARK: - Supporting Views

struct ActionRequiredView: View {
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
            Text("Action Required")
                .font(.callout)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text("Error loading email")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Email Reply

extension EmailDetailView {
    private func handleReply(_ email: EmailSummary) {
        if emailViewModel.originalEmails[email.id] != nil {
            showingReplySheet = true
        } else {
            Task {
                _ = await emailViewModel.getEmail(email.id)
                showingReplySheet = true
            }
        }
    }

    private func handleReplyDismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            replyViewOffset = 1000
            showingReplySheet = false
        }
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
