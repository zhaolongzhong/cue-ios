//
//  AppTheme+ColorPalette.swift
//  CueApp
//

import SwiftUI

extension AppTheme {
    public enum ColorPalette: Equatable, Sendable {
        case black
        case tomato
        case orange
        case olive
        case darkGoldenrod
        case limeGreen
        case green
        case teal
        case deepSkyBlue
        case cornflowerBlue
        case blue
        case royalBlue
        case blueViolet
        case mediumPurple
        case hotPink
        case orchid
        case custom(Color)

        public static let allColors: [Self] = [
            .black, .tomato, .orange, .olive, .darkGoldenrod,
            .limeGreen, .green, .teal, .deepSkyBlue, .cornflowerBlue,
            .blue, .royalBlue, .blueViolet, .mediumPurple, .hotPink, .orchid
        ]

        public var color: Color {
            switch self {
            case .custom(let color):
                return color
            default:
                return Color(hex: hexString)
            }
        }

        public var name: String {
            switch self {
            case .black:
                return "Black"
            case .tomato:
                return "Tomato"
            case .orange:
                return "Orange"
            case .olive:
                return "Olive"
            case .darkGoldenrod:
                return "Dark Goldenrod"
            case .limeGreen:
                return "Lime Green"
            case .green:
                return "Green"
            case .teal:
                return "Teal"
            case .deepSkyBlue:
                return "Deep Sky Blue"
            case .cornflowerBlue:
                return "Cornflower Blue"
            case .blue:
                return "Blue"
            case .royalBlue:
                return "Royal Blue"
            case .blueViolet:
                return "Blue Violet"
            case .mediumPurple:
                return "Medium Purple"
            case .hotPink:
                return "Hot Pink"
            case .orchid:
                return "Orchid"
            case .custom:
                return "Custom"
            }
        }
    }
}

extension AppTheme.ColorPalette {
    public var hexString: String {
        switch self {
        case .black:
            return "#000000"
        case .tomato:
            return "#F44336"
        case .orange:
            return "#E67C26"
        case .olive:
            return "#94730B"
        case .darkGoldenrod:
            return "#F09300"
        case .limeGreen:
            return "#4CAF50"
        case .green:
            return "#43A047"
        case .teal:
            return "#26A69A"
        case .deepSkyBlue:
            return "#00BCD4"
        case .cornflowerBlue:
            return "#7986CB"
        case .blue:
            return "#03A9F4"
        case .royalBlue:
            return "#303F9F"
        case .blueViolet:
            return "#673AB7"
        case .mediumPurple:
            return "#9575CD"
        case .hotPink:
            return "#E91E63"
        case .orchid:
            return "#E91E63"
        case .custom(let color):
            return color.toHex() ?? "#000000"
        }
    }
}

extension Color {
    // Convert SwiftUI Color to hex string
    func toHex() -> String? {
        // Convert the SwiftUI Color to UIColor/NSColor
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #else
        let nsColor = NSColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #endif

        // Convert the components to hex
        let hexString = String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )

        return hexString
    }
}
