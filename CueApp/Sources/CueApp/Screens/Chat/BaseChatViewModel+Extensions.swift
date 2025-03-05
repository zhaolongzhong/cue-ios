//
//  BaseChatView+Extensions.swift
//  CueApp
//

import Foundation
import CueCommon
import CueOpenAI
import CueAnthropic
import CueGemini
#if os(iOS)
import UIKit
#endif

// Extension to add common content handling functionality
extension BaseChatViewModel {

    /// Collects all content from text input, text area, and attachments
    /// - Returns: OpenAI ContentBlocks that can be converted to provider-specific formats
    @MainActor
    func collectContentBlocks() async -> [OpenAI.ContentBlock] {
        var contentBlocks: [OpenAI.ContentBlock] = []

        // Add user's input message if not empty
        if !richTextFieldState.inputMessage.isEmpty {
            contentBlocks.append(OpenAI.ContentBlock.text(richTextFieldState.inputMessage))
        }

        // Add attachment content
        let attachmentBlocks = await convertToContents(attachments: attachments)
        if !attachmentBlocks.isEmpty {
            contentBlocks.append(contentsOf: attachmentBlocks)
        }

        return contentBlocks
    }

    @MainActor
    func cleanupAttachments() {
        attachments.removeAll()
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

    @MainActor
    func getImageParts() -> [ModelContent.Part] {
        return self.attachments.compactMap { attachment in
            if let imageData = attachment.imageData {
                let mimeType = attachment.mimeType

                if let processed = ImageProcessorUtil.processImageData(imageData: imageData, mimeType: mimeType) {
                    return ModelContent.Part.data(mimetype: processed.mimeType, processed.data)
                }

                return ModelContent.Part.data(mimetype: mimeType, imageData)
            } else if attachment.type == .image {
                do {
                    let url = attachment.url
                    let data = try Data(contentsOf: url)
                    let mimeType = attachment.mimeType

                    // Process the image data with our utility
                    if let processed = ImageProcessorUtil.processImageData(imageData: data, mimeType: mimeType) {
                        return ModelContent.Part.data(mimetype: processed.mimeType, processed.data)
                    }

                    // Fallback to original data
                    return ModelContent.Part.data(mimetype: mimeType, data)
                } catch {
                    print("Failed to read image from URL: \(error.localizedDescription)")
                }
            }
            return nil
        }
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

        return (userMessage, richTextFieldState.inputMessage)
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

        // Process images from attachments
        let imageParts = getImageParts()
        parts.append(contentsOf: imageParts)

        // Now we can safely remove attachments
        cleanupAttachments()

        let newContent = ModelContent(role: "user", parts: parts)
        let userMessage = Gemini.ChatMessageParam.userMessage(newContent)
        return (userMessage, richTextFieldState.inputMessage)
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

        return (userMessage, richTextFieldState.inputMessage)
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

        return (simpleUserMessage, richTextFieldState.inputMessage)
    }
}
