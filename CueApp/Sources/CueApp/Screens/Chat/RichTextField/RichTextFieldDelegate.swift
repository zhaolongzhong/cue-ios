//
//  RichTextFieldDelegate.swift
//  CueApp
//

import CueOpenAI

// MARK: - Rich Text Field Delegate Protocol
@MainActor
protocol RichTextFieldDelegate: AnyObject {
    func onSend()
    func onStop()
    func onAddAttachment(_ attachment: Attachment)
    func onRemoveAttachment(at index: Int)
    func onClearAttachments()
    func onUpdateInputMessage(_ message: String)
    func onUpdateSelectedCapabilities(_ capabilities: [Capability])
    func onOpenVoiceChat()
    func onUpdateWorkingApp(to app: AccessibleApplication, working: Bool)
    func onStopAXApp()
}

@MainActor
extension RichTextFieldDelegate {
    func onSend() {}
    func onStop() {}
    func onAddAttachment(_ attachment: Attachment) {}
    func onRemoveAttachment(at index: Int) {}
    func onClearAttachments() {}
    func onUpdateInputMessage(_ message: String) {}
    func onUpdateSelectedCapabilities(_ capabilities: [Capability]) {}
    func onOpenVoiceChat() {}
    func onUpdateWorkingApp(to app: AccessibleApplication, working: Bool) {}
    func onStopAXApp() {}
}
