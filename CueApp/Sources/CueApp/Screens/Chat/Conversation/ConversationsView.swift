//
//  ConversationsView.swift
//  CueApp
//

import SwiftUI

struct ConversationsView: View {
    @ObservedObject var viewModel: ConversationsViewModel
    @State private var editingConversationId: String?
    @State private var editedTitle: String = ""
    @State private var conversationToDelete: String?
    @State private var isRenaming: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var showMultiDeleteAlert: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    private let animationDuration: Double = 0.2
    private let provider: Provider

    var onSelectConversation: (String) -> Void

    init(
        viewModel: ConversationsViewModel,
        provider: Provider,
        onSelectConversation: @escaping (String) -> Void
    ) {
        self.provider = provider
        self.viewModel = viewModel
        self.onSelectConversation = onSelectConversation
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                headerView
                if viewModel.isSelectMode {
                    selectModeToolbar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                searchView
                Divider()
                    .padding(.vertical, 8)
                conversationListView
            }
        }
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
        .alert("Delete Selected Conversations?", isPresented: $showMultiDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteSelectedConversations()
                }
            }
        } message: {
            Text("The selected conversations will be permanently deleted.")
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                    )
            }
        }
        .onChange(of: viewModel.selectedConversationId) { _, newValue in
            if let id = newValue, !viewModel.isSelectMode {
                onSelectConversation(id)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSelectMode)
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text("Chats")
                .withSideBarTitle()

            Menu {
                Button("New chat") {
                    Task {
                        await viewModel.createConversation(provider: provider)
                    }
                }
                Button("Select") {
                    viewModel.toggleSelectMode()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .asIcon()
            }
            .help("More Options")
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .withIconHover()
        }
        .padding()
    }

    private var selectModeToolbar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.selectAllConversations()
            } label: {
                Text("Select All")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .withHoverEffect()

            Spacer()

            Button {
                viewModel.deselectAllConversations()
                viewModel.toggleSelectMode()
            } label: {
                Text("Cancel")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .withHoverEffect()

            Button {
                if !viewModel.selectedConversationIds.isEmpty {
                    showMultiDeleteAlert = true
                }
            } label: {
                Text("Delete")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.selectedConversationIds.isEmpty)
            .opacity(viewModel.selectedConversationIds.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var searchView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .padding(.leading, 8)

            TextField("Search", text: $viewModel.searchText)
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
                                ConversationRow(
                                    conversation: conversation,
                                    isSelected: viewModel.selectedConversationId == conversation.id,
                                    isSelectMode: viewModel.isSelectMode,
                                    isSelected_MultiSelect: viewModel.isConversationSelected(conversation.id),
                                    onSelect: {
                                        viewModel.selectConversation(conversation.id)
                                        onSelectConversation(conversation.id)
                                    },
                                    onToggleSelection: {
                                        viewModel.toggleConversationSelection(conversation.id)
                                    },
                                    onDelete: {
                                        conversationToDelete = conversation.id
                                        showDeleteAlert = true
                                    },
                                    onRename: {
                                        editingConversationId = conversation.id
                                        editedTitle = conversation.title
                                        isRenaming = true
                                    }
                                )
                                .padding(.horizontal, 8)
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

    private func editConversationRow(for conversation: ConversationModel) -> some View {
        HStack {
            TextField("Title", text: $editedTitle, onCommit: {
                if !editedTitle.isEmpty {
                    Task {
                        await viewModel.updateTitle(for: conversation.id, newTitle: editedTitle)
                    }
                }
                editingConversationId = nil
                isTextFieldFocused = false
            })
            .textFieldStyle(PlainTextFieldStyle())
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.separator.opacity(0.5))
            )
            .focused($isTextFieldFocused) // Connect to focus state
            .onAppear {
                // Automatically focus the text field when it appears
                // Adding a slight delay helps ensure the view is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                }
            }

            Button {
                if !editedTitle.isEmpty {
                    Task {
                        await viewModel.updateTitle(for: conversation.id, newTitle: editedTitle)
                    }
                }
                editingConversationId = nil
                isTextFieldFocused = false
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)

            Button {
                editingConversationId = nil
                isTextFieldFocused = false
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
