//
//  BaseChatView+Extensions.swift
//  CueApp
//

import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic
import CueGemini

// Extension to add common content handling functionality
extension BaseChatViewModel {

    /// Collects all content from text input, text area, and attachments
    /// - Returns: OpenAI ContentBlocks that can be converted to provider-specific formats
    @MainActor
    func collectContentBlocks() async -> [OpenAI.ContentBlock] {
        var contentBlocks: [OpenAI.ContentBlock] = []

        // Add user's input message if not empty
        if !newMessage.isEmpty {
            contentBlocks.append(OpenAI.ContentBlock.text(newMessage))
        }

        // Add attachment content
        let attachmentBlocks = await convertToContents(attachments: attachments)
        if !attachmentBlocks.isEmpty {
            contentBlocks.append(contentsOf: attachmentBlocks)
        }

        attachments.removeAll()

        return contentBlocks
    }

    /// Gets text area content if available
    /// - Returns: Text area context as a string if available, nil otherwise
    @MainActor
    func getTextAreaContext() -> String? {
        #if os(macOS)
        if let textAreaContent = self.axManager.textAreaContentList.first {
            return textAreaContent.getTextAreaContext()
        }
        #endif
        return nil
    }
}

// Specific extension for Anthropic
extension BaseChatViewModel {
    /// Converts OpenAI ContentBlocks to Anthropic ContentBlocks
    /// - Parameter contentBlocks: OpenAI ContentBlocks to convert
    /// - Returns: Array of Anthropic ContentBlocks
    func toAnthropicContentBlocks(_ contentBlocks: [OpenAI.ContentBlock]) -> [Anthropic.ContentBlock] {
        return contentBlocks.compactMap { block -> Anthropic.ContentBlock? in
            switch block {
            case .text(let textContent):
                return Anthropic.ContentBlock.text(Anthropic.TextBlock(text: textContent, type: "text"))
            case .imageUrl:
                return nil
            }
        }
    }

    /// Prepares an Anthropic user message with all content sources
    /// - Returns: Anthropic ChatMessageParam and user message text
    @MainActor
    func prepareAnthropicMessage() async -> (Anthropic.ChatMessageParam, String) {
        // Collect content blocks
        let contentBlocks = await collectContentBlocks()

        // Convert to Anthropic format
        var anthropicBlocks = toAnthropicContentBlocks(contentBlocks)

        // Add text area content if available
        if let textAreaContext = getTextAreaContext() {
            let textAreaBlock = Anthropic.ContentBlock.text(Anthropic.TextBlock(text: textAreaContext, type: "text"))
            anthropicBlocks.append(textAreaBlock)
        }

        // Create user message
        let userMessage = Anthropic.ChatMessageParam.userMessage(
            Anthropic.MessageParam(role: "user", content: anthropicBlocks)
        )

        return (userMessage, newMessage)
    }
}

// Specific extension for Gemini
extension BaseChatViewModel {
    /// Converts OpenAI ContentBlocks to Gemini Parts
    /// - Parameter contentBlocks: OpenAI ContentBlocks to convert
    /// - Returns: Array of Gemini ModelContent.Part objects
    func toGeminiParts(_ contentBlocks: [OpenAI.ContentBlock]) -> [ModelContent.Part] {
        return contentBlocks.compactMap { block -> ModelContent.Part? in
            switch block {
            case .text(let textContent):
                return ModelContent.Part.text(textContent)
            case .imageUrl:
                return nil
            }
        }
    }

    /// Prepares a Gemini user message with all content sources
    /// - Returns: Gemini ChatMessageParam and user message text
    @MainActor
    func prepareGeminiMessage() async -> (Gemini.ChatMessageParam, String) {
        // Collect content blocks
        let contentBlocks = await collectContentBlocks()

        // Convert to Gemini format
        var parts = toGeminiParts(contentBlocks)

        // Add text area content if available
        if let textAreaContext = getTextAreaContext() {
            let textAreaPart = ModelContent.Part.text(textAreaContext)
            parts.append(textAreaPart)
        }

        // Create user message
        let newContent = ModelContent(role: "user", parts: parts)
        let userMessage = Gemini.ChatMessageParam.userMessage(newContent)

        return (userMessage, newMessage)
    }
}

// Specific extension for OpenAI
extension BaseChatViewModel {
    /// Prepares an OpenAI user message with all content sources
    /// - Returns: OpenAI ChatMessageParam, text area context (if any), and user message text
    @MainActor
    func prepareOpenAIMessage() async -> (OpenAI.ChatMessageParam, String) {
        // Collect content blocks
        var contentBlocks = await collectContentBlocks()

        // Get text area context
        if let textAreaContext = getTextAreaContext() {
            contentBlocks.append(OpenAI.ContentBlock.text(textAreaContext))
        }

        // Create user message
        let userMessage: OpenAI.ChatMessageParam = .userMessage(
            OpenAI.MessageParam(
                role: "user",
                contentBlocks: contentBlocks
            )
        )

        return (userMessage, newMessage)
    }
}

// Extension for Local content handling
extension BaseChatViewModel {
    /// Prepares an OpenAI-format message for local processing
    /// - Returns: OpenAI ChatMessageParam, text area context (if any), and user message text
    @MainActor
    func prepareLocalMessage() async -> (OpenAI.ChatMessageParam, String) {
        // Collect content blocks
        var contentBlocks = await collectContentBlocks()

        // Get text area context
        if let textAreaContext = getTextAreaContext() {
            contentBlocks.append(OpenAI.ContentBlock.text(textAreaContext))
        }

        // Create user message with contentBlocks
        let userMessageWithBlocks: OpenAI.ChatMessageParam = .userMessage(
            OpenAI.MessageParam(
                role: "user",
                contentBlocks: contentBlocks
            )
        )

        // Create a simpler user message with string content for request
        let userMessageString = userMessageWithBlocks.content.contentAsString
        let simpleUserMessage: OpenAI.ChatMessageParam = .userMessage(
            OpenAI.MessageParam(role: "user", content: .string(userMessageString))
        )

        return (simpleUserMessage, newMessage)
    }
}
