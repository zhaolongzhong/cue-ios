//
//  WorkingAppView.swift
//  CueApp
//

import SwiftUI

struct WorkingAppView: View {
    let workingApps: [String: AccessibleApplication]
    let textAreaContents: [String: TextAreaContent]
    let onUpdateAXApp: (AccessibleApplication, Bool) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                if workingApps.isEmpty {
                    ForEach(Array(workingApps.values), id: \.self) { app in
                        HStack {
                            app.icon
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(app.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Button {
                                onUpdateAXApp(app, false)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .semibold))
                                    .frame(width: 16, height: 16)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.all, 4)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.Colors.separator)
                        )

                    }
                } else {
                    ForEach(Array(textAreaContents.values), id: \.self) { textAreaContent in
                        HStack {
                            textAreaContent.app.icon
                                .resizable()
                                .frame(width: 16, height: 16)

                            if let fileName = textAreaContent.fileName {
                                Text(fileName)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }

                            if let focusedLines = textAreaContent.focusedLines {
                                Text(focusedLines)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button {
                                onUpdateAXApp(textAreaContent.app, false)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .semibold))
                                    .frame(width: 16, height: 16)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.all, 4)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.Colors.separator)
                        )
                    }
                }
            }

            Spacer()
        }
    }
}
