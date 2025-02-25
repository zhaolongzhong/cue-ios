//
//  Stream+Types.swift
//  CueApp
//

struct StreamingState {
    var currentIndex: Int?
    var accumulatedText = ""
}

public enum StreamEvent {
    case text(String)
    case toolCall(String, [String: Any])
    case toolResult(String)
    case thinking(String)
    case completed
}
