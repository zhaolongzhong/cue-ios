//
//  ProviderKeyRow.swift
//  CueApp
//

import SwiftUI

struct ProviderKeyRow: View {
    let provider: Provider
    @ObservedObject var viewModel: ProviderDetailViewModel
    @State private var showDeleteAlert = false

    var body: some View {
        HStack {
            Image(systemName: "key")
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("API Key")
                        .font(.body)
                        .fontWeight(.medium)
                    Spacer()

                    Menu {
                        Button(viewModel.getAPIKey().isEmpty ? "Add" : "Edit") {
                            viewModel.promptForAPIKey()
                        }
                        if !viewModel.getAPIKey().isEmpty {
                            Button("Delete", role: .destructive) {
                                showDeleteAlert = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .menuIndicator(.hidden)
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                    .fixedSize()
                }
                .contextMenu {
                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(viewModel.getAPIKey(), forType: .string)
                        #else
                        UIPasteboard.general.string = viewModel.getAPIKey()
                        #endif
                    } label: {
                        Label("Copy API Key", systemImage: "doc.on.doc")
                    }
                }

                HStack(spacing: 16) {
                    if viewModel.getAPIKey().isEmpty {
                        Text("Not configured")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        SecretView(secret: viewModel.getAPIKey())
                    }
                    Spacer()
                }
            }
        }
        .contextMenu {
            Button {
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(viewModel.getAPIKey(), forType: .string)
                #else
                UIPasteboard.general.string = viewModel.getAPIKey()
                #endif
            } label: {
                Label("Copy API Key", systemImage: "doc.on.doc")
            }
        }
        .padding(.all, 8)
        #if os(macOS)
        .background(AppTheme.Colors.separator.opacity(0.5))
        #else
        .background(AppTheme.Colors.secondaryBackground.opacity(0.2))
        #endif
        .cornerRadius(8)
        .alert("Delete API Key",
               isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteKey()
            }
        } message: {
            Text("Are you sure you want to delete this API key?")
        }
    }
}
