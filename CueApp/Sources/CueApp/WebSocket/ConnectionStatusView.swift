import SwiftUI

struct ConnectionStatusView: View {
    let connectionState: ConnectionState

    private var statusColor: Color {
        switch connectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .red
        case .error:
            return .red
        }
    }

    private var statusText: String {
        switch connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .error(let error):
            switch error {
            case .invalidURL:
                return "Error: Invalid URL"
            case .connectionFailed(let message):
                return "Error: Connection Failed (\(message))"
            case .receiveFailed(let message):
                return "Error: Receive Failed (\(message))"
            }
        }
    }

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.footnote)
                .foregroundColor(statusColor)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(.bar)
    }
}
