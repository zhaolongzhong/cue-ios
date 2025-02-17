import SwiftUI
import Dependencies

struct EmailCategoryView: View {
    @Dependency(\.authRepository) var authRepository
    @Binding var selectedCategory: EmailCategory?
    let emailSummaries: [EmailSummary]
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var categoryCounts: [EmailCategory: Int] {
        Dictionary(grouping: emailSummaries) { $0.category }
            .mapValues { $0.count }
    }

    var body: some View {
        VStack {
            contentView
            Spacer()
            settingsSection
        }
        .applyListStyle()
    }

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            CategoryRowShimmer()
        } else {
            categoryList
        }
    }

    private var categoryList: some View {
        List {
            allEmailsRow
            categoryRows
        }
    }

    private var allEmailsRow: some View {
        CategoryRow(
            category: nil,
            count: emailSummaries.count,
            isSelected: selectedCategory == nil,
            action: handleAllEmailsSelection
        )
    }

    private var categoryRows: some View {
        ForEach(EmailCategory.allCases, id: \.self) { category in
            CategoryRow(
                category: category,
                count: categoryCounts[category, default: 0],
                isSelected: selectedCategory == category,
                action: { handleCategorySelection(category) }
            )
        }
    }

    private var settingsSection: some View {
        SettingsMenu(currentUser: authRepository.currentUser)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
    }

    // MARK: - Action Handlers

    private func handleAllEmailsSelection() {
        selectedCategory = nil
        dismissOnIOS()
    }

    private func handleCategorySelection(_ category: EmailCategory) {
        selectedCategory = category
        dismissOnIOS()
    }

    private func dismissOnIOS() {
        #if os(iOS)
        dismiss()
        #endif
    }
}

// MARK: - Supporting Views

struct CategoryRow: View {
    @Environment(\.colorScheme) var colorScheme
    let category: EmailCategory?
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                categoryLabel
                Spacer()
                countBadge
            }
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(selectionBackground)
    }

    private var categoryLabel: some View {
        Label {
            Text(category?.displayName ?? "All Emails")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .primary.opacity(0.8) : .secondary.opacity(0.8))
                .padding(.leading, 8)
        } icon: {
            categoryIconView
        }
    }

    private var categoryIconView: some View {
        Group {
            if let category = category {
                categoryIcon(for: category)
            } else {
                Image(systemName: "tray")
                    .foregroundStyle(.primary.opacity(0.8))
            }
        }
    }

    private var countBadge: some View {
        Text("\(count)")
            .font(.system(size: 12))
            .fontWeight(.semibold)
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(width: 28, height: 20)
            .background(countBadgeBackground)
    }

    private var countBadgeBackground: some View {
        Capsule().fill(
            isSelected ? .blue.opacity(0.8) :
                (colorScheme == .dark ? AppTheme.Colors.background : .white.opacity(0.8))
        )
    }

    private var selectionBackground: some View {
        Capsule()
            .fill(isSelected ?
                (colorScheme == .dark ? AppTheme.Colors.background.opacity(0.5) : .white.opacity(0.6)) :
                Color.clear
            )
    }
}

struct CategoryRowShimmer: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        List {
            ForEach(0..<4) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.2))
                    .frame(height: 18)
                    .shimmer(peakOpacity: 0.2)
                    .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    @ViewBuilder
    func applyListStyle() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self
        #endif
    }
}
