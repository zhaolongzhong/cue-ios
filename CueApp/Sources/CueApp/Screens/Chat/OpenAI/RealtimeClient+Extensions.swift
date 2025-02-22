import Foundation
import Dependencies
import CueOpenAI
import os.log

extension RealtimeClient: @retroactive DependencyKey {
    public static let liveValue = RealtimeClient(transport: .webSocket)
}

extension DependencyValues {
    var realtimeClient: RealtimeClient {
        get { self[RealtimeClient.self] }
        set { self[RealtimeClient.self] = newValue }
    }
}
