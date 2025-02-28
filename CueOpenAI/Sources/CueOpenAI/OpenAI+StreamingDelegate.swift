import Foundation

extension OpenAI {
    public protocol StreamingDelegate: AnyObject {
        func didReceiveStart(id: String, model: String) async
        func didReceiveContent(id: String, delta: String, index: Int) async
        func didReceiveToolCallDelta(id: String, delta: [ToolCallDelta], index: Int) async
        func didReceiveStop(id: String, finishReason: String?, index: Int) async
        func didReceiveError(_ error: Error) async
        func didCompleteWithError(_ error: Error) async
    }
}
