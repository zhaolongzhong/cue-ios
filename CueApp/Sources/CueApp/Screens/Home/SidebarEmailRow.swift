//
//  SidebarEmailRow.swift
//  CueApp
//

import SwiftUI

struct SidebarEmailRow: View {
    var onTap: () -> Void

    var body: some View {
        SidebarRowButton(
            title: "Email",
            icon: .system("envelope"),
            action: {
                onTap()
            }
        )
    }
}
