//
//  RichTextFieldDelegate.swift
//  CueApp
//

import CueOpenAI

// MARK: - Rich Text Field Delegate Protocol
@MainActor
protocol RichTextFieldDelegate: AnyObject {
    func onSend()
    func onOpenVoiceChat()
    func onShowAXApp(_ app: AccessibleApplication)
    func onStop()
    func onPickAttachment(_ attachment: Attachment)
    func onReloadProviderSettings()
    func onUpdateSelectedCapabilities(_ capabilities: [Capability])
}

@MainActor
extension RichTextFieldDelegate {
    func onSend() {}
    func onOpenVoiceChat() {}
    func onShowAXApp(_ app: AccessibleApplication) {}
    func onStop() {}
    func onPickAttachment(_ attachment: Attachment) {}
    func onReloadProviderSettings() {}
    func onUpdateSelectedCapabilities(_ capabilities: [Capability]) {}
}
