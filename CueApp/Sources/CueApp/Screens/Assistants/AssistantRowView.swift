//
//  AssistantRowView.swift
//
import SwiftUI

struct AssistantRowView: View {
    let assistant: AssistantStatus
    let status: ClientStatus?

    var body: some View {
        HStack {
            Circle()
                .fill(assistant.isOnline ? Color.green : Color.gray)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(assistant.name.prefix(1))
                        .foregroundColor(.white)
                        .font(.headline)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("id:\(assistant.id)")
                    .font(.footnote).foregroundColor(.gray)
                Text(assistant.name)
                    .font(.body)
                Text("runner id: \(status?.runnerId ?? "")")
                    .font(.subheadline).foregroundColor(.gray)
            }

            Spacer()

            Circle()
                .fill(assistant.isOnline ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 8)
    }
}
