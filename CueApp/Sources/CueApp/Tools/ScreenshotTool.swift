#if os(macOS)
import Foundation
import AppKit
import CoreGraphics
import CueOpenAI

struct ScreenshotParameters: ToolParameters, Sendable {
    let schema: [String: Property] = [
        "type": .init(
            type: "string",
            description: "Type of screenshot: 'area' (x,y,width,height) or 'screen' (full screen)"
        ),
        "x": .init(
            type: "integer",
            description: "X coordinate for area screenshot"
        ),
        "y": .init(
            type: "integer",
            description: "Y coordinate for area screenshot"
        ),
        "width": .init(
            type: "integer",
            description: "Width for area screenshot"
        ),
        "height": .init(
            type: "integer",
            description: "Height for area screenshot"
        ),
        "save_path": .init(
            type: "string",
            description: "Path to save the screenshot (optional, will use Desktop by default)"
        )
    ]

    let required: [String] = ["type"]
}

struct ScreenshotTool: LocalTool, Sendable {
    let name: String = "screenshot"
    let description: String = "Take screenshots of specific areas or full screen"
    let parameterDefinition: ToolParameters = ScreenshotParameters()

    func call(_ args: ToolArguments) async throws -> String {
        guard let type = args.getString("type")?.lowercased() else {
            throw ToolError.invalidArguments("Missing screenshot type")
        }

        return try await ScreenshotService.takeScreenshot(
            type: type,
            x: Int(args.getString("x") ?? "0") ?? 0,
            y: Int(args.getString("y") ?? "0") ?? 0,
            width: Int(args.getString("width") ?? "0") ?? 0,
            height: Int(args.getString("height") ?? "0") ?? 0,
            savePath: args.getString("save_path")
        )
    }
}

enum ScreenshotService {
    static func takeScreenshot(
        type: String,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        savePath: String?
    ) async throws -> String {
        return try await MainActor.run {
            let image: NSImage?

            let mainDisplay = CGMainDisplayID()

            guard CGDisplayIsActive(mainDisplay) > 0 else {
                throw ToolError.invalidArguments("No active display found")
            }

            switch type {
            case "area":
                guard width > 0, height > 0 else {
                    throw ToolError.invalidArguments("Invalid dimensions for area screenshot")
                }
                let rect = CGRect(x: x, y: y, width: width, height: height)
                image = captureArea(rect, display: mainDisplay)

            case "screen":
                let displayBounds = CGDisplayBounds(mainDisplay)
                image = captureArea(displayBounds, display: mainDisplay)

            default:
                throw ToolError.invalidArguments("Invalid screenshot type. Use 'area' or 'screen'")
            }

            guard let screenshot = image else {
                throw ToolError.invalidArguments("Failed to capture screenshot")
            }

            let path = try saveScreenshot(screenshot, to: savePath)
            return "Screenshot saved to: \(path)"
        }
    }

    private static func captureArea(_ rect: CGRect, display: CGDirectDisplayID) -> NSImage? {
        if let cgImage = CGDisplayCreateImage(display, rect: rect) {
            return NSImage(cgImage: cgImage, size: rect.size)
        }
        return nil
    }

    private static func saveScreenshot(_ image: NSImage, to path: String?) throws -> String {
        let fileManager = FileManager.default
        let desktopURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")

        let timestamp = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .short,
            timeStyle: .medium
        ).replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")

        let fileName = "Screenshot-\(timestamp).png"
        let saveURL: URL

        if let customPath = path {
            saveURL = URL(fileURLWithPath: customPath).appendingPathComponent(fileName)
        } else {
            saveURL = desktopURL.appendingPathComponent(fileName)
        }

        if let tiffData = image.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            try pngData.write(to: saveURL)
            return saveURL.path
        }

        throw ToolError.invalidArguments("Failed to save screenshot")
    }
}
#endif
