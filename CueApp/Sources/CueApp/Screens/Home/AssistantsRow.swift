//
//  AssistantsRow.swift
//  CueApp
//

import SwiftUI

struct AssistantsRow: View {
    var onTap: () -> Void

    var body: some View {
        SidebarRowButton(
            title: "Assistants",
            icon: .system("bubbles.and.sparkles"),
            action: {
                onTap()
            }
        )
    }
}
