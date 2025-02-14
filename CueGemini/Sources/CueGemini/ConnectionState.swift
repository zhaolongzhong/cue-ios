public enum WebsocketConnectionState: Sendable {
    case connecting
    case connected
    case disconnected
    case error (String)
}
