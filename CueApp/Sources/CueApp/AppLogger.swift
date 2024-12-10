import os

public enum AppLog {
    public static let log = Logger(subsystem: "App", category: "app")
    public static let audio = Logger(subsystem: "AudioStream", category: "AudioStream")
    public static let recorder = Logger(subsystem: "AudioRecorder", category: "AudioRecorder")
    public static let websocket = Logger(subsystem: "WebSocketManager", category: "WebSocket")
    public static let mcp = Logger(subsystem: "MCP", category: "mcp")
}
