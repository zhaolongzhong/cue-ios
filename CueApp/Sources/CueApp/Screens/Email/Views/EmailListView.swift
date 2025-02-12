import SwiftUI

struct EmailListView: View {
    @Binding var selectedCategory: EmailCategory?
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
        ZStack {
            BackgroundContainer()
            VStack {
                #if os(macOS)
                Rectangle()
                    .fill(AppTheme.Colors.separator.opacity(0.5))
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
                #endif
                ScrollView {
                    LazyVStack {
                        ForEach(filteredEmails) { email in
                            EmailRow(email: email)
                        }
                    }
                }
            }
        }
        .navigationTitle(selectedCategory?.displayName ?? "Emails")
        .overlay {
            if filteredEmails.isEmpty {
                ContentUnavailableView(
                    "No Emails",
                    systemImage: "tray.fill",
                    description: Text("No emails in this category")
                )
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }
}
