import Foundation

public enum ClientMessage: Encodable {
    case setup(BidiGenerateContentSetup)
    case clientContent(BidiGenerateContentClientContent)
    case realtimeInput(BidiGenerateContentRealtimeInput)
    case toolResponse(BidiGenerateContentToolResponse)
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .setup(let setup):
            try container.encode(setup, forKey: .setup)
        case .clientContent(let content):
            try container.encode(content, forKey: .clientContent)
        case .realtimeInput(let input):
            try container.encode(input, forKey: .realtimeInput)
        case .toolResponse(let response):
            try container.encode(response, forKey: .toolResponse)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case setup = "setup"
        case clientContent = "clientContent"
        case realtimeInput = "realtimeInput"
        case toolResponse = "toolResponse"
    }
}

extension ClientMessage {
    static func makeSetupMessage(model: String, config: GenerationConfig? = nil) -> ClientMessage {
        let setupDetails = BidiGenerateContentSetup.SetupDetails(
            model: model,
            generationConfig: config,
            systemInstruction: nil,
            tools: nil
        )
        return .setup(BidiGenerateContentSetup(setup: setupDetails))
    }
    
//    static func makeClientContentMessage(text: String, turnComplete: Bool = true) -> ClientMessage {
//        let part = ModelContent.Part(text: text)
//        let turn = BidiGenerateContentClientContent.ClientContent.Turn(role: "user", parts: [part])
//        let content = BidiGenerateContentClientContent.ClientContent(turnComplete: turnComplete, turns: [turn])
//        return .clientContent(BidiGenerateContentClientContent(clientContent: content))
//    }
    
    public static func makeRealtimeInputMessage(mimeType: BidiGenerateContentRealtimeInput.RealtimeInput.MimeType, data: String) -> BidiGenerateContentRealtimeInput {
        let chunk = BidiGenerateContentRealtimeInput.RealtimeInput.MediaChunk(mimeType: mimeType, data: data)
        let input = BidiGenerateContentRealtimeInput.RealtimeInput(mediaChunks: [chunk])
        return BidiGenerateContentRealtimeInput(realtimeInput: input)
    }
    
    public static func makeToolResponseMessage(functionResponses: [FunctionResponse]) -> ClientMessage {
        let toolResponse = BidiGenerateContentToolResponse.BidiGenerateContentToolResponse(functionResponses: functionResponses)
        return .toolResponse(BidiGenerateContentToolResponse(toolResponse: toolResponse))
    }
}

public struct BidiGenerateContentSetup: Encodable, Sendable {
    let setup: SetupDetails

    public struct SetupDetails: Encodable, Sendable {
        let model: String
        let generationConfig: GenerationConfig?
        let systemInstruction: ModelContent?
        let tools: [Tool]?

        public init(model: String, generationConfig: GenerationConfig?, systemInstruction: ModelContent?, tools: [Tool]?) {
            self.model = model
            self.generationConfig = generationConfig
            self.systemInstruction = systemInstruction
            self.tools = tools
        }

        enum CodingKeys: String, CodingKey {
            case model = "model"
            case generationConfig = "generation_config"
            case systemInstruction = "system_instruction"
            case tools = "tools"
        }
    }
}

public struct BidiGenerateContentClientContent: Encodable {
    public let clientContent: ClientContent

    public init(clientContent: ClientContent) {
        self.clientContent = clientContent
    }

    enum CodingKeys: String, CodingKey {
        case clientContent = "clientContent"
    }

    public struct ClientContent: Encodable {
        let turnComplete: Bool
        let turns: [Turn]

        public init(turnComplete: Bool, turns: [Turn]) {
            self.turnComplete = turnComplete
            self.turns = turns
        }

        public struct Turn: Encodable {
            public let role: String
            public let parts: [ModelContent.Part]

            public init(role: String, parts: [ModelContent.Part]) {
                self.role = role
                self.parts = parts
            }

//            public struct Part: Encodable {
//                let text: String?
//
//                public init(text: String?) {
//                    self.text = text
//                }
//            }
        }
    }
}

public struct BidiGenerateContentRealtimeInput: Encodable, Sendable {
    let realtimeInput: RealtimeInput

    enum CodingKeys: String, CodingKey {
        case realtimeInput
    }

    public init(realtimeInput: RealtimeInput) {
        self.realtimeInput = realtimeInput
    }

    public struct RealtimeInput: Encodable, Sendable {
        let mediaChunks: [MediaChunk]

        public init(mediaChunks: [MediaChunk]) {
            self.mediaChunks = mediaChunks
        }

        public struct MediaChunk: Encodable, Sendable {
            let mimeType: String
            let data: String

            enum CodingKeys: String, CodingKey, Codable {
                // https://github.com/google-gemini/cookbook/blob/main/gemini-2/websockets/live_api_streaming_in_colab.ipynb
                // https://github.com/google-gemini/cookbook/blob/main/gemini-2/websockets/live_api_starter.py
                case mimeType
                case data
            }

            public init(mimeType: String, data: String) {
                self.mimeType = mimeType
                self.data = data
            }

            public init(mimeType: MimeType, data: String) {
                self.mimeType = mimeType.rawValue
                self.data = data
            }
        }

        enum CodingKeys: String, CodingKey {
            case mediaChunks
        }

        public enum MimeType: String {
            case imageJpeg = "image/jpeg"
            case audioPcm = "audio/pcm"
        }
    }
}

public struct BidiGenerateContentToolResponse: Encodable, Sendable {
    public let toolResponse: BidiGenerateContentToolResponse

    public init(toolResponse: BidiGenerateContentToolResponse) {
        self.toolResponse = toolResponse
    }

    public struct BidiGenerateContentToolResponse: Codable, Sendable {
        public let functionResponses: [FunctionResponse]?

        public init(functionResponses: [FunctionResponse]?) {
            self.functionResponses = functionResponses
        }

        enum CodingKeys: String, CodingKey {
            // https://github.com/google-gemini/cookbook/blob/main/gemini-2/websockets/live_api_tool_use.ipynb
            // https://ai.google.dev/gemini-api/docs/multimodal-live#bidigeneratecontenttoolresponse
            case functionResponses = "function_responses"
        }
    }
}
