import Foundation

struct EditorLine: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var number: Int
    var isSelected: Bool
    
    static func == (lhs: EditorLine, rhs: EditorLine) -> Bool {
        lhs.id == rhs.id
    }
}