import SwiftUI
import Dependencies

struct EmailCategoryView: View {
    @Dependency(\.authRepository) var authRepository
    @Binding var selectedCategory: EmailCategory?
    let emailSummaries: [EmailSummary]
    @Environment(\.dismiss) private var dismiss

    private var categoryCounts: [EmailCategory: Int] {
        Dictionary(grouping: emailSummaries) { $0.category }
            .mapValues { $0.count }
    }

    var body: some View {
        VStack {
            List {
                CategoryRow(
                    category: nil,
                    count: emailSummaries.count,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                    #if os(iOS)
                    dismiss()
                    #endif
                }

                ForEach(EmailCategory.allCases, id: \.self) { category in
                    CategoryRow(
                        category: category,
                        count: categoryCounts[category, default: 0],
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        #if os(iOS)
                        dismiss()
                        #endif
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
            Spacer()
            SettingsMenu(currentUser: authRepository.currentUser)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }
}

struct CategoryRow: View {
    @Environment(\.colorScheme) var colorScheme
    let category: EmailCategory?
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label {
                    Text(category?.displayName ?? "All Emails")
                        .font(.body)
                        .foregroundColor(.primary.opacity(0.9))
                } icon: {
                    if let category = category {
                        categoryIcon(for: category)
                    } else {
                        Image(systemName: "tray")
                            .foregroundStyle(.primary.opacity(0.8))
                    }
                }
                Spacer()
                Text("\(count)")
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 20, height: 20)
                    .background(
                        isSelected ? .blue.opacity(0.8) : (colorScheme == .dark ?  AppTheme.Colors.background : .white.opacity(0.8)))
                    .clipShape(Circle())
                    .font(.system(size: 10))
            }
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
        .padding(.all, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? AppTheme.Colors.separator.opacity(0.5) : Color.clear)
        ).padding(.vertical, 2)
    }
}
