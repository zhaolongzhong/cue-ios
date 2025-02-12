import SwiftUI

struct EmailCategoryView: View {
    @Binding var selectedCategory: EmailCategory?
    let emailSummaries: [EmailSummary]
    @Environment(\.dismiss) private var dismiss

    private var categoryCounts: [EmailCategory: Int] {
        Dictionary(grouping: emailSummaries) { $0.category }
            .mapValues { $0.count }
    }

    var body: some View {
        List {
            Button {
                selectedCategory = nil
                #if os(iOS)
                dismiss()
                #endif
            } label: {
                HStack {
                    Label("All Emails", systemImage: "tray")
                    Spacer()
                    Text("\(emailSummaries.count)")
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary)
            }
            .buttonStyle(.plain)

            ForEach(EmailCategory.allCases, id: \.self) { category in
                Button {
                    selectedCategory = category
                    #if os(iOS)
                    dismiss()
                    #endif
                } label: {
                    HStack {
                        Label {
                            Text(category.displayName)
                        } icon: {
                            categoryIcon(for: category)
                        }
                        Spacer()
                        Text("\(categoryCounts[category, default: 0])")
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }
}
