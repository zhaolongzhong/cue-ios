import SwiftUI
import Dependencies

struct EmailSummarizationView: View {
    @StateObject private var viewModel = EmailSummarizationViewModel()
    @State private var selectedCategory: EmailCategory?
    @ObservedObject var selectionManager: AssistantSelectionManager

    var body: some View {
        ZStack {
            NavigationSplitView {
                EmailCategorySidebar(
                    selectedCategory: $selectedCategory,
                    emailSummaries: viewModel.emailSummaries
                )
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        backButton
                    }
                    #else
                    ToolbarItem(placement: .navigation) {
                        backButton
                    }
                    #endif
                }
            } detail: {
                EmailContentList(
                    selectedCategory: selectedCategory,
                    emailSummaries: viewModel.emailSummaries
                )
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .opacity(viewModel.processingState == .ready ? 1 : 0)
            .overlay(
                stopButton
                    .padding(.all, 8),
                alignment: .topTrailing
            )
            .ignoresSafeArea(edges: .top)

            if viewModel.processingState != .ready {
                processingOverlay
            }
        }
        .task {
            await viewModel.startProcessing()
        }
    }

    private var backButton: some View {
        Button {
            viewModel.stopProcessing()
            selectionManager.isEmailViewPresented = false
        } label: {
            HStack {
                Image(systemName: "chevron.left")
                Text("Back")
            }
        }
        .buttonStyle(.plain)
        .opacity(viewModel.processingState == .ready ? 1 : 0)
    }

    private var stopButton: some View {
        Button {
            viewModel.stopProcessing()
        } label: {
            Image(systemName: "stop.fill")
                .font(.title3)
                .padding(8)
                .background(Circle().fill(Color.gray.opacity(0.2)))
        }
        .buttonStyle(.plain)
    }

    private var processingOverlay: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(0.8)
                .padding(.bottom, 10)

            Text(viewModel.processingState.description)
                .font(.headline)

            progressSteps
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var progressSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            progressStep("Getting tasks from inbox", isComplete: viewModel.processingState != .idle)
            progressStep("Organizing tasks", isComplete: viewModel.processingState != .idle && viewModel.processingState != .gettingInbox)
            progressStep("Analyzing messages", isComplete: viewModel.processingState != .idle && viewModel.processingState != .gettingInbox && viewModel.processingState != .organizingTasks)
            progressStep("Almost ready", isComplete: viewModel.processingState == .almostReady || viewModel.processingState == .ready)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func progressStep(_ text: String, isComplete: Bool) -> some View {
        HStack {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isComplete ? .green : .secondary)
            Text(text)
                .foregroundColor(isComplete ? .primary : .secondary)
        }
    }
}

// MARK: - Sidebar View
private struct EmailCategorySidebar: View {
    @Binding var selectedCategory: EmailCategory?
    let emailSummaries: [EmailSummary]

    private var categoryCounts: [EmailCategory: Int] {
        Dictionary(grouping: emailSummaries) { $0.category }
            .mapValues { $0.count }
    }

    var body: some View {
        List(selection: $selectedCategory) {
            ForEach(EmailCategory.allCases, id: \.self) { category in
                NavigationLink(value: category) {
                    HStack {
                        Label {
                            Text(category.displayName)
                        } icon: {
                            categoryIcon(for: category)
                        }
                        Spacer()
                        Text("\(categoryCounts[category, default: 0])")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Categories")
    }

    @ViewBuilder
    private func categoryIcon(for category: EmailCategory) -> some View {
        switch category {
        case .newsletters:
            Image(systemName: "newspaper")
        case .updates:
            Image(systemName: "bell")
        case .actionItems:
            Image(systemName: "checklist")
        case .replies:
            Image(systemName: "arrow.turn.up.left")
        }
    }
}

// MARK: - Content List View
private struct EmailContentList: View {
    let selectedCategory: EmailCategory?
    let emailSummaries: [EmailSummary]

    private var filteredEmails: [EmailSummary] {
        guard let category = selectedCategory else {
            return emailSummaries.sortedByPriority()
        }
        return emailSummaries
            .filter { $0.category == category }
            .sortedByPriority()
    }

    var body: some View {
        List(filteredEmails) { email in
            EmailRow(email: email)
        }
        .navigationTitle(selectedCategory?.displayName ?? "All Emails")
        .overlay {
            if filteredEmails.isEmpty {
                ContentUnavailableView(
                    "No Emails",
                    systemImage: "tray.fill",
                    description: Text("No emails in this category")
                )
            }
        }
    }
}

// MARK: - Email Row View
private struct EmailRow: View {
    let email: EmailSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(email.title)
                    .font(.headline)

                Spacer()

                if email.requiresAction {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                }

                Text(email.date, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(email.snippet)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            if !email.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(email.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
