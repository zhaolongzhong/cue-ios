// import Foundation

// // MARK: - Request Types
// struct LiveAPISetup: Codable {
//     let setup: SetupConfig

//     struct SetupConfig: Codable {
//         let model: String
//     }
// }

// struct LiveAPIClientContent: Codable {
//     let clientContent: ClientContent

//     struct ClientContent: Codable {
//         let turnComplete: Bool
//         let turns: [Turn]

//         struct Turn: Codable {
//             let role: String
//             let parts: [Part]

//             struct Part: Codable {
//                 let text: String?
//             }
//         }
//     }
// }

// struct LiveAPIRealtimeInput: Codable {
//     let realtimeInput: RealtimeInput

//     struct RealtimeInput: Codable {
//         let mediaChunks: [MediaChunk]

//         struct MediaChunk: Codable {
//             let mimeType: String
//             let data: String // base64 encoded data

//             enum CodingKeys: String, CodingKey {
//                 case mimeType = "mime_type"
//                 case data
//             }
//         }
//     }
// }

// // MARK: - Response Types
// struct LiveAPIResponse: Codable {
//     let serverContent: ServerContent?

//     struct ServerContent: Codable {
//         let modelTurn: ModelTurn?
//         let turnComplete: Bool?

//         struct ModelTurn: Codable {
//             let parts: [Part]?

//             struct Part: Codable {
//                 let inlineData: InlineData?

//                 struct InlineData: Codable {
//                     let data: String // base64 encoded data
//                 }
//             }
//         }
//     }
// }

