import Foundation

// MARK: - Control Commands
extension ChatViewModel {
    func sendControlCommand(_ action: ControlCommand.Action) {
        guard let userId = authRepository.currentUser?.id else {
            handleError(AuthError.userNotFound, context: "Failed to send control command")
            return
        }
        
        let command = ControlCommand(
            action: action,
            targetId: assistantRecipientId
        )
        
        let uuid = UUID().uuidString
        let controlEvent = EventMessage(
            type: .userControl,
            payload: .control(command),
            clientId: EnvironmentConfig.shared.clientId,
            metadata: nil,
            websocketRequestId: uuid
        )
        
        do {
            try webSocketService.send(event: controlEvent)
        } catch {
            handleError(error, context: "Failed to send control command")
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Stop the current task/generation
    func stopAssistant() {
        sendControlCommand(.stop)
    }
    
    /// Reset the assistant's state
    func resetAssistant() {
        sendControlCommand(.reset)
    }
    
    /// Retry the last operation
    func retryLastMessage() {
        sendControlCommand(.retry)
    }
}