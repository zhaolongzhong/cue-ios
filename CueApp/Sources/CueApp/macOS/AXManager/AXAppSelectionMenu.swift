//
//  AXAppSelectionMenu.swift
//  CueApp
//

import SwiftUI

struct AXAppSelectionMenu: View {
    @State private var selectedApp: AccessibleApplication = .textEdit
    @State private var isPopoverShown: Bool = false

    let onUpdateAXApp: ((AccessibleApplication, Bool) -> Void)

    var body: some View {
        Button {
            isPopoverShown.toggle()
        } label: {
            Image(systemName: "link.badge.plus")
        }
        .buttonStyle(BorderlessButtonStyle())
        .withIconHover()
        .popover(isPresented: $isPopoverShown) {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(AccessibleApplication.allCases, id: \.self) { app in
                            HStack {
                                app.icon
                                    .resizable()
                                    .asIcon(frameSize: 24)

                                Text(app.name)

                                if app.isVSCodeIDE {
                                    Text(" • Require Extension")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if app.isVSCodeIDE {
                                    Button {
                                        print("Set up")
                                    } label: {
                                        Text("Set up")
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Button {
                                        selectedApp = app
                                        onUpdateAXApp(selectedApp, true)
                                        isPopoverShown = false
                                    } label: {
                                        Text("Add")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(height: 40)
                            .frame(minWidth: 200, alignment: .leading)
                            .padding(.horizontal, 8)
                            .withHoverEffect(verticalPadding: 0)
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.vertical, 8)
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
            .frame(maxWidth: 320)
        }
    }
}
