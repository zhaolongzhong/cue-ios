//
//  ObservedAppView.swift
//  CueApp
//
//  Created by z on 3/8/25.
//

import SwiftUI

struct ObservedAppView: View {
    let observedApp: ObservedApp
    let focusedLines: String?
    let onStopTapped: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Observed app: \(observedApp.name)")
                if let focusedLines = focusedLines {
                    Text(focusedLines)
                }
            }
            Spacer()
            Button("Stop") {
                onStopTapped()
            }
        }
        .padding(.all, 12)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(AppTheme.Colors.separator))
    }
}

// Example model
struct ObservedApp {
    let id: String
    let name: String
    // Add other properties as needed
}
