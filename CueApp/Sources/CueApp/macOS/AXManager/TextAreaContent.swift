import Foundation

#if os(macOS)
struct TextAreaContent {
    let id: Int
    let content: String
    let size: CGSize
    let selectionRange: NSRange?
    let selectionLines: [String]
    let selectionLinesRange: LineRange?
}
#endif
