//
//  MCPServerUtils.swift
//  CueApp
//

/// Utility functions for parsing and formatting arguments and environment variables
struct MCPServerUtils {
    // Parse arguments from text supporting both newline and comma separation
    static func parseArguments(_ text: String) -> [String] {
        // If there are commas but no newlines, treat as comma-separated
        if text.contains(",") && !text.contains("\n") {
            return text.split(separator: ",")
                .map { processArgument(String($0)) }
                .filter { !$0.isEmpty }
        }

        // Otherwise, split by newlines first
        let lines = text.split(separator: "\n")

        // Process each line, handling comma-separated values within lines
        return lines.flatMap { line -> [String] in
            let lineStr = String(line)

            // If this particular line contains commas, split it further
            if lineStr.contains(",") {
                return lineStr.split(separator: ",")
                    .map { processArgument(String($0)) }
                    .filter { !$0.isEmpty }
            } else {
                // Otherwise process as a single argument
                let processed = processArgument(lineStr)
                return processed.isEmpty ? [] : [processed]
            }
        }
    }

    // Helper to process a single argument
    static func processArgument(_ arg: String) -> String {
        var result = arg.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove leading and trailing quotes if they exist
        if (result.hasPrefix("\"") && result.hasSuffix("\"")) ||
           (result.hasPrefix("'") && result.hasSuffix("'")) {
            result = String(result.dropFirst().dropLast())
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Convert environment variables array to dictionary
    static func envVariablesToDict(_ variables: [EnvVariable]) -> [String: String] {
        variables
            .filter { $0.isValid }
            .reduce(into: [String: String]()) { dict, envVar in
                let key = envVar.key.trimmingCharacters(in: .whitespacesAndNewlines)
                let value = envVar.value.trimmingCharacters(in: .whitespacesAndNewlines)
                dict[key] = value
            }
    }

    // Convert environment variables dictionary to text
    static func envDictToText(_ env: [String: String]) -> String {
        env.map { key, value in "\(key)=\(value)" }.joined(separator: "\n")
    }

    // Parse environment variables from text
    static func parseEnvVariables(_ text: String) -> [String: String] {
        var envDict = [String: String]()

        text.split(separator: "\n")
            .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.isEmpty }
            .forEach { line in
                let components = line.split(separator: "=", maxSplits: 1)
                if components.count == 2 {
                    var key = String(components[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                    var value = String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines)

                    // Clean up key - remove quotes if present
                    if (key.hasPrefix("\"") && key.hasSuffix("\"")) ||
                       (key.hasPrefix("'") && key.hasSuffix("'")) {
                        key = String(key.dropFirst().dropLast())
                    }

                    // Clean up value - remove quotes if present
                    if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                       (value.hasPrefix("'") && value.hasSuffix("'")) {
                        value = String(value.dropFirst().dropLast())
                    }

                    envDict[key] = value
                }
            }

        return envDict
    }

    // Convert dictionary to array of EnvVariable
    static func dictToEnvVariables(_ dict: [String: String]) -> [EnvVariable] {
        dict.map { key, value in
            EnvVariable(key: key, value: value)
        }
    }
}
