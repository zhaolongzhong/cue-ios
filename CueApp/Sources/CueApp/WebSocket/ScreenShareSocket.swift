// import Foundation
//
// class ScreenShareSocket {
//    private var webSocketTask: URLSessionWebSocketTask?
//    private let urlSession = URLSession(configuration: .default)
//    private let url: URL
//
//    init(url: URL) {
//        self.url = url
//    }
//
//    func connect() {
//        webSocketTask = urlSession.webSocketTask(with: url)
//        webSocketTask?.resume()
//        listen()
//    }
//
//    private func listen() {
//        webSocketTask?.receive { [weak self] result in
//            switch result {
//            case .failure(let error):
//                print("WebSocket error: \(error)")
//            case .success(let message):
//                switch message {
//                case .data(let data):
//                    // Handle received data
//                    print("Received data: \(data)")
//                case .string(let text):
//                    // Handle received text
//                    print("Received text: \(text)")
//                @unknown default:
//                    break
//                }
//            }
//            self?.listen()
//        }
//    }
//
//    func sendFrameData(_ data: Data) {
//        let message = URLSessionWebSocketTask.Message.data(data)
//        print("inx ScreenShareSocket Send frame data")
////        webSocketTask?.send(message) { error in
////            if let error = error {
////                print("WebSocket send error: \(error)")
////            }
////        }
//    }
//
//    func sendAudioData(_ data: Data) {
//        let message = URLSessionWebSocketTask.Message.data(data)
////        webSocketTask?.send(message) { error in
////            if let error = error {
////                print("WebSocket send error: \(error)")
////            }
////        }
//    }
//
//    func sendPauseNotification() {
//        let message = URLSessionWebSocketTask.Message.string("pause")
//        webSocketTask?.send(message) { error in
//            if let error = error {
//                print("WebSocket send error: \(error)")
//            }
//        }
//    }
//
//    func sendResumeNotification() {
//        let message = URLSessionWebSocketTask.Message.string("resume")
//        webSocketTask?.send(message) { error in
//            if let error = error {
//                print("WebSocket send error: \(error)")
//            }
//        }
//    }
//
//    func disconnect() {
//        webSocketTask?.cancel(with: .goingAway, reason: nil)
//    }
// }
