//
//  ObservedAppView.swift
//  CueApp
//

import SwiftUI

struct ObservedAppView: View {
    let observedApp: AccessibleApplication
    let textAreaContents: [TextAreaContent]
    let onStopTapped: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                ForEach(textAreaContents, id: \.self) { textAreaContent in
                    HStack {
                        observedApp.icon
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

                        Button(action: onStopTapped) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .semibold))
                                .frame(width: 16, height: 16)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.all, 4)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.Colors.separator))
                }
            }
            Spacer()
        }
    }
}
