//
//  ConversationsView.swift
//  CueApp
//

import SwiftUI

struct ConversationsView: View {
    @Binding var isShowing: Bool
    @StateObject var viewModel: ConversationsViewModel
    @State private var editingConversationId: String?
    @State private var editedTitle: String = ""
    @State private var showDeleteAlert: Bool = false
    @State private var conversationToDelete: String?
    @State private var isRenaming: Bool = false

    private let animationDuration: Double = 0.25

    var onSelectConversation: (String) -> Void

    init(
        isShowing: Binding<Bool>,
        provider: Provider,
        selectedConversationId: String?,
        onSelectConversation: @escaping (String) -> Void
    ) {
        self._isShowing = isShowing
        self._viewModel = StateObject(
            wrappedValue: ConversationsViewModel(
                selectedConversationId: selectedConversationId,
                provider: provider
            )
        )
        self.onSelectConversation = onSelectConversation
    }

    var body: some View {
        ZStack {
            #if os(macOS)
            VisualEffectView(material: .toolTip, blendingMode: .behindWindow)
                .ignoresSafeArea()
            #endif
            VStack(alignment: .leading, spacing: 0) {
                headerView
                searchView
                Divider()
                    .padding(.vertical, 8)
                conversationListView
            }
        }
        .frame(width: 280)
        #if os(iOS)
        .edgesIgnoringSafeArea(.vertical)
        #endif
        .alert("Delete Conversation?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let id = conversationToDelete {
                    Task {
                        await viewModel.deleteConversation(id)
                    }
                }
            }
        } message: {
            Text("This conversation will be permanently deleted.")
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .background(
                        RoundedRectangle(cornerRadius:
                                            8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                    )
            }
        }
        .onChange(of: viewModel.selectedConversationId) { _, newValue in
            if let id = newValue {
                onSelectConversation(id)
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text("Sessions")
                .font(.headline)
                .foregroundColor(.almostPrimary)
                .padding(.all)

            Spacer()
        }
        .padding(.top)
    }

    private var searchView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .padding(.leading, 8)

            TextField("Search sessions", text: $viewModel.searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 8)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 8)
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.Colors.separator.opacity(0.5))
        )
        .padding(.horizontal)
    }

    private var conversationListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if viewModel.conversations.isEmpty {
                    emptyStateView
                        .transition(.opacity)
                        .animation(.easeInOut(duration: animationDuration), value: viewModel.searchText)
                } else {
                    ForEach(viewModel.conversations) { conversation in
                        Group {
                            if editingConversationId == conversation.id {
                                editConversationRow(for: conversation)
                            } else {
                                conversationRow(for: conversation)
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                        .id(conversation.id)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            // Use conditional content without transitions to avoid weird animations
            Group {
                if viewModel.searchText.count >= 3 {
                    VStack(spacing: 8) {
                        Text("No matching conversations")
                            .font(.headline)

                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
        .animation(.default, value: viewModel.searchText.count >= 3)
    }

    private func conversationRow(for conversation: ConversationModel) -> some View {
        HStack {
            Button {
                viewModel.selectConversation(conversation.id)
                onSelectConversation(conversation.id)
                withAnimation(.easeInOut(duration: 0.3)) {
                    isShowing = false
                }
            } label: {
                HStack {

                    Text(conversation.title)
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            Menu {
                Button {
                    editingConversationId = conversation.id
                    editedTitle = conversation.title
                    isRenaming = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button(role: .destructive, action: {
                    conversationToDelete = conversation.id
                    showDeleteAlert = true
                }, label: {
                    Label("Delete", systemImage: "trash")
                })
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .frame(width: 32)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(viewModel.selectedConversationId == conversation.id  ? AppTheme.Colors.separator.opacity(0.5) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private func editConversationRow(for conversation: ConversationModel) -> some View {
        HStack {
            TextField("Title", text: $editedTitle, onCommit: {
                if !editedTitle.isEmpty {
                    Task {
                        await viewModel.updateTitle(for: conversation.id, newTitle: editedTitle)
                    }
                }
                editingConversationId = nil
            })
            .textFieldStyle(PlainTextFieldStyle())
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.separator.opacity(0.5))
            )

            Button {
                if !editedTitle.isEmpty {
                    Task {
                        await viewModel.updateTitle(for: conversation.id, newTitle: editedTitle)
                    }
                }
                editingConversationId = nil
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)

            Button {
                editingConversationId = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.15))
        )
    }
}
