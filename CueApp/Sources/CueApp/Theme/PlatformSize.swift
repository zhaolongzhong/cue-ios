import Foundation

var platformButtonSize: CGFloat {
    #if os(iOS)
    44
    #else
    36
    #endif
}

var platformButtonFontSize: CGFloat {
    #if os(iOS)
    16
    #else
    14
    #endif
}
