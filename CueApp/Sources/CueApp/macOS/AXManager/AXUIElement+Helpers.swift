#if os(macOS)
import Cocoa

struct LineRange {
    let startLine: Int
    let endLine: Int
}

extension AXUIElement {

    func findElements(ofRole role: CFString, depth: Int = 0) -> [AXUIElement] {
        var foundElements: [AXUIElement] = []

        var childrenRef: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(self, kAXChildrenAttribute as CFString, &childrenRef)
        guard error == .success, let children = childrenRef as? [AXUIElement] else {
            return foundElements
        }

        for child in children {
            var childRole: CFString?
            var childRoleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &childRoleRef) == .success,
               let roleRef = childRoleRef,
               CFGetTypeID(roleRef) == CFStringGetTypeID() {
                childRole = unsafeDowncast(roleRef, to: CFString.self)
            }

            if let childRole = childRole, childRole == role {
                foundElements.append(child)
            }

            // Recursively search this child's descendants
            let descendants = child.findElements(ofRole: role, depth: depth + 1)
            foundElements.append(contentsOf: descendants)
        }

        return foundElements
    }

    // Returns the accessibility description
    func axDescription() throws -> String {
        var descRef: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(self, kAXDescriptionAttribute as CFString, &descRef)
        guard error == .success, let description = descRef as? String else {
            throw NSError(domain: "AXErrorDomain", code: Int(error.rawValue), userInfo: nil)
        }
        return description
    }

    // Checks if the element's size is reasonable for a text field
    var isTextFieldOfReasonableSize: Bool {
        if let size = try? self.axSize() {
            return size.width > 100 && size.height > 20
        }
        return false
    }

    func axValue() throws -> String {
        var valueRef: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(self, kAXValueAttribute as CFString, &valueRef)
        guard error == .success, let value = valueRef as? String else {
            throw NSError(domain: "AXErrorDomain", code: Int(error.rawValue), userInfo: nil)
        }
        return value
    }

    func axSize() throws -> CGSize {
        var sizeRef: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(self, kAXSizeAttribute as CFString, &sizeRef)
        guard error == .success, let sizeValue = sizeRef else {
            throw NSError(domain: "AXErrorDomain", code: Int(error.rawValue), userInfo: nil)
        }

        var size = CGSize.zero
        if CFGetTypeID(sizeValue) == AXValueGetTypeID() {
            let axValue = unsafeDowncast(sizeValue, to: AXValue.self)
            if AXValueGetType(axValue) == .cgSize {
                AXValueGetValue(axValue, .cgSize, &size)
            }
        }
        return size
    }

    /// Compute the slection range (startIndex, length)
    func axSelectionRange() throws -> NSRange? {
        var rangeRef: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(self, kAXSelectedTextRangeAttribute as CFString, &rangeRef)
        guard error == .success,
              let validRangeRef = rangeRef,
              CFGetTypeID(validRangeRef) == AXValueGetTypeID() else {
            return nil
        }

        let rangeValue = unsafeDowncast(validRangeRef, to: AXValue.self)
        guard AXValueGetType(rangeValue) == .cfRange else { return nil }

        var cfRange = CFRange()
        if AXValueGetValue(rangeValue, .cfRange, &cfRange) {
            return NSRange(location: cfRange.location, length: cfRange.length)
        }
        return nil
    }

    /// Computes the line range (string-based) spanned by the current selection.
    func axSelectionLines() -> [String] {
        guard let fullText = try? self.axValue(),
              let selection = try? self.axSelectionRange() else {
            return []
        }

        let nsText = fullText as NSString

        // Validate the selection range and check for zero-length selection
        if selection.location == NSNotFound || selection.length == 0 || NSMaxRange(selection) > nsText.length {
            return []
        }

        let selectedText = nsText.substring(with: selection)
        return selectedText.components(separatedBy: .newlines)
    }

    /// Computes the line range (1-based) spanned by the current selection.
    func axSelectionLineRange() -> LineRange? {
        guard let fullText = try? self.axValue(),
              let selection = try? self.axSelectionRange(),
              selection.location != NSNotFound, selection.length > 0 else {
            return nil
        }

        let nsText = fullText as NSString
        let prefix = nsText.substring(to: selection.location)
        let startLine = prefix.components(separatedBy: .newlines).count

        let selectionText = nsText.substring(with: selection)
        let linesInSelection = selectionText.components(separatedBy: .newlines).count
        let endLine = startLine + linesInSelection - 1

        return LineRange(startLine: startLine, endLine: endLine)
    }
}
#endif
