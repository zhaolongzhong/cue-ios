//
//  ServerItemView.swift
//  CueApp
//

import SwiftUI
import CueMCP

struct ServerItemView: View {
    let serverName: String
    let server: MCPServerConfig
    let onTap: (String) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ServerItemHeader(
                serverName: serverName,
                server: server,
                showDetails: showDetails,
                onTap: onTap,
                onEdit: onEdit,
                onDelete: onDelete,
                toggleDetails: { showDetails.toggle() }
            )

            if showDetails {
                ServerItemDetails(server: server)
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.opacity)
                    .animation(.easeInOut, value: showDetails)
            }
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Header Component
struct ServerItemHeader: View {
    let serverName: String
    let server: MCPServerConfig
    let showDetails: Bool
    let onTap: (String) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let toggleDetails: () -> Void

    var body: some View {
        Button {
            onTap(serverName)
        } label: {
            HStack {
                ServerInfo(serverName: serverName, server: server)

                Spacer()

                ActionButtons(
                    showDetails: showDetails,
                    toggleDetails: toggleDetails,
                    onEdit: onEdit,
                    onDelete: onDelete
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding()
    }
}

// MARK: - Server Info Component
struct ServerInfo: View {
    let serverName: String
    let server: MCPServerConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(serverName)
                .font(.headline)
                .foregroundColor(.primary)

            Text(server.command)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !server.args.isEmpty {
                CountLabel(count: server.args.count, label: "argument")
            }

            if let env = server.env, !env.isEmpty {
                CountLabel(count: env.count, label: "environment variable")
            }
        }
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
    let showDetails: Bool
    let toggleDetails: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                toggleDetails()
            } label: {
                Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)

            Menu {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Details Component
struct ServerItemDetails: View {
    let server: MCPServerConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !server.args.isEmpty {
                ArgumentsSection(args: server.args)
            }

            if let env = server.env, !env.isEmpty {
                EnvironmentVariablesSection(env: env)
            }
        }
    }
}

// MARK: - Arguments Section Component
struct ArgumentsSection: View {
    let args: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Arguments")
                .font(.subheadline)
                .fontWeight(.medium)

            ForEach(args.indices, id: \.self) { index in
                Text(args[index])
                    .font(.system(.caption, design: .monospaced))
                    .padding(6)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Environment Variables Section Component
struct EnvironmentVariablesSection: View {
    let env: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Environment Variables")
                .font(.subheadline)
                .fontWeight(.medium)

            LazyVGrid(columns: [GridItem(.flexible())], spacing: 4) {
                ForEach(env.keys.sorted(), id: \.self) { key in
                    EnvironmentVariable(key: key, value: env[key] ?? "")
                }
            }
        }
    }
}

// MARK: - Environment Variable Component
struct EnvironmentVariable: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)

            Text("=")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
    }
}
