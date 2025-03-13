//
//  ServerRow.swift
//  CueApp
//

import SwiftUI
import CueMCP

struct ServerRow: View {
    let serverName: String
    let server: MCPServerConfig
    let onShowTools: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(serverName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Command: \(server.command) \(server.args.joined(separator: " "))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let env = server.env, !env.isEmpty {
                        CountLabel(count: env.count, label: "environment variable")
                    }
                }
                Spacer()
                ActionButtons(
                    onShowTools: onShowTools,
                    onEdit: onEdit,
                    onDelete: onDelete
                )
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Count Label Component
struct CountLabel: View {
    let count: Int
    let label: String

    var body: some View {
        Text("\(count) \(label)\(count > 1 ? "s" : "")")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

// MARK: - Action Buttons Component
struct ActionButtons: View {
    let onShowTools: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button(action: onShowTools) {
                    Label("Tools", systemImage: "wrench.and.screwdriver")
                }

                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}
