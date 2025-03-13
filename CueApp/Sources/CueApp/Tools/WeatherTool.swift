import Foundation
import CueOpenAI

enum WeatherUnit: String, Sendable {
    case celsius = "C"
    case fahrenheit = "F"
}

struct WeatherParameters: ToolParameters, Sendable {
    let schema: [String: Property] = [
        "location": .init(
            type: "string",
            description: "The city and state, e.g. San Francisco, CA"
        ),
        "unit": .init(
            type: "string",
            description: "Temperature unit (C or F)"
        )
    ]

    let required: [String] = ["location"]
}

struct WeatherTool: LocalTool, Sendable {
    static func == (lhs: WeatherTool, rhs: WeatherTool) -> Bool {
        return lhs.name == rhs.name
    }

    let name: String = "get_current_weather"
    let description: String = "Get the current weather in a given location"
    let parameterDefinition: any ToolParameters = WeatherParameters()

    func call(_ args: ToolArguments) async throws -> String {
        guard let location = args.getString("location") else {
            throw ToolError.invalidArguments("Missing location")
        }
        let unit = args.getString("unit") ?? "F"
        return await WeatherService.getWeather(location: location, unit: unit)
    }
}

// Mock weather service
enum WeatherService {
    static func getWeather(location: String, unit: String) async -> String {
        return "61\(unit) in \(location)"
    }
}
