//
//  RichTextFieldDelegate.swift
//  CueApp
//

// MARK: - Rich Text Field Delegate Protocol
@MainActor
protocol RichTextFieldDelegate: AnyObject {
    func onSend()
    func onShowTools()
    func onOpenVoiceChat()
    func onShowAXApp(_ app: AccessibleApplication)
    func onStop()
    func onPickAttachment(_ attachment: Attachment)
    func onUpdateMessage(_ message: String)
    func onReloadProviderSettings()
}

@MainActor
extension RichTextFieldDelegate {
    func onSend() {}
    func onShowTools() {}
    func onOpenVoiceChat() {}
    func onShowAXApp(_ app: AccessibleApplication) {}
    func onStop() {}
    func onPickAttachment(_ attachment: Attachment) {}
    func onUpdateMessage(_ message: String) {}
    func onReloadProviderSettings() {}
}
