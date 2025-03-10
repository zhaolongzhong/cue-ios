//
//  ServerDetailsSection.swift
//  CueApp
//

import SwiftUI

struct ServerDetailsSection: View {
    @Binding var serverName: String
    @Binding var command: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Server Name Field
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .primaryLabel()
                TextField("Server name", text: $serverName)
                    .styledTextField()
            }

            // Command Field
            VStack(alignment: .leading, spacing: 4) {
                Text("Command")
                    .primaryLabel()
                TextField("Command to run, e.g. uv, npx", text: $command)
                    .styledTextField()
            }
        }
    }
}
