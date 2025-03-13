//
//  ToolSelectionMenu.swift
//  CueApp
//

import SwiftUI
import CueOpenAI

struct ToolSelectionMenu: View {
    @State private var searchText: String = ""
    @State private var isPopoverShown: Bool = false
    @State private var internalSelectedTools: Set<String> = []

    let availableCapabilities: [Capability]
    let selectedCapabilities: [Capability]
    let onCapabilitiesSelected: (([Capability]) -> Void)?

    var filteredCapabilities: [Capability] {
        if searchText.isEmpty {
            return availableCapabilities
        } else {
            return availableCapabilities.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        Button {
            isPopoverShown.toggle()
        } label: {
            Image(systemName: "hammer")
        }
        .buttonStyle(BorderlessButtonStyle())
        .withIconHover()
        .popover(isPresented: $isPopoverShown) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .frame(width: 16)

                    TextField("Search", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .frame(width: 204)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .frame(width: 16)
                    } else {
                        Spacer()
                            .frame(width: 16)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(filteredCapabilities, id: \.name) { tool in
                            HStack {
                                Text(tool.name.capitalized)
                                    .lineLimit(1)
                                if tool.isBuiltIn {
                                    Text("(Built-in)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                }
                                if tool.isMCPServer {
                                    Text("(MCP)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button {
                                    if internalSelectedTools.contains(tool.name) {
                                        internalSelectedTools.remove(tool.name)
                                    } else {
                                        internalSelectedTools.insert(tool.name)
                                    }

                                    let selectedToolObjects = availableCapabilities.filter { internalSelectedTools.contains($0.name) }
                                    onCapabilitiesSelected?(selectedToolObjects)
                                } label: {
                                    Image(systemName: internalSelectedTools.contains(tool.name) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(internalSelectedTools.contains(tool.name) ? .primary : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(height: 40)
                            .frame(minWidth: 200, alignment: .leading)
                            .padding(.horizontal, 8)
                            .withHoverEffect(verticalPadding: 0)
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .frame(minHeight: 200, maxHeight: 300)

                Divider()
                Button {
                    isPopoverShown = false
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.bottom, 8)
            .frame(width: 280)
        }
        .onAppear {
            syncWithExternalState()
        }
        .onChange(of: selectedCapabilities) { _, _ in
            syncWithExternalState()
        }
    }

    // Helper method to sync internal state with external state
    private func syncWithExternalState() {
        internalSelectedTools = Set(selectedCapabilities.map { $0.name })
    }
}
