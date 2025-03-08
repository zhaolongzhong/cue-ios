//
//  RichTextFieldDelegate.swift
//  CueApp
//

import CueOpenAI

// MARK: - Rich Text Field Delegate Protocol
@MainActor
protocol RichTextFieldDelegate {
    func onSend()
    func onStop()
    func onAddAttachment(_ attachment: Attachment)
    func onRemoveAttachment(at index: Int)
    func onClearAttachments()
    func onUpdateInputMessage(_ message: String)
    func onUpdateSelectedCapabilities(_ capabilities: [Capability])
    func onOpenVoiceChat()
    func onShowAXApp(to app: AccessibleApplication)
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
    func onShowAXApp(to app: AccessibleApplication) {}
}
