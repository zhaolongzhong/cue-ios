public struct Tool: Codable, Equatable, Sendable {
    public let type: String
    public let function: FunctionDefinition
    
    public init(type: String = "function", function: FunctionDefinition) {
        self.type = type
        self.function = function
    }
    
    public var name: String {
        function.name
    }
    
    public var description: String {
        function.description
    }
}

public typealias OpenAITool = Tool

public struct RealtimeTool: Codable, Equatable, Sendable {
    public let type: String
    public let name: String
    public let description: String
    public let parameters: Parameters
}

extension Tool {
    public func asDefinition() -> FunctionDefinition {
        .init(type: type, name: name, description: description, parameters: function.parameters)
    }
}

public struct FunctionDefinition: Codable, Equatable, Sendable {
    public let type: String?
    public let name: String
    public let description: String
    public let parameters: Parameters
    
    public init(type: String? = nil, name: String, description: String, parameters: Parameters) {
        self.type = type
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

public struct Parameters: Codable, Equatable, Sendable {
    public let type: String
    public let properties: [String: Property]
    public let required: [String]
    
    public init(type: String = "object", properties: [String: Property], required: [String]) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

public typealias OpenAIParametersProperty = Property

public struct Property: Codable, Equatable, Sendable {
    public let type: String
    public let description: String?
    public let items: PropertyItems?
    
    public struct PropertyItems: Codable, Equatable, Sendable {
        public let type: String
        
        public init(type: String) {
            self.type = type
        }
    }
    
    public init(type: String, description: String? = nil, items: PropertyItems? = nil) {
        self.type = type
        self.description = description
        self.items = items
    }
}

extension Property {
    public static func array(description: String? = nil, itemType: String = "string") -> Property {
        return Property(
            type: "array",
            description: description,
            items: PropertyItems(type: itemType)
        )
    }
}
