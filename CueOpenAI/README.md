# OpenAI Swift API library

A Swift SDK for OpenAI's [chat completion](https://platform.openai.com/docs/guides/text-generation) and [Realtime API](https://platform.openai.com/docs/guides/realtime) service. It's highly inspired by [openai-python](https://github.com/openai/openai-python).

## Installation

Simply copy the package to your project and add it as dependencies,

```swift
import PackageDescription

let package = Package(
    name: "CueApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CueApp",
            targets: ["CueApp"])
    ],
    dependencies: [
        .package(path: "../CueOpenAI"), // assume it's same directory level as the main app or adjust the path accordinly.
    ],
    targets: [
        .target(
            name: "CueApp",
            dependencies: [
                // existing dependencies
                .product(name: "CueOpenAI", package: "CueOpenAI"),
            ]
        )
    ]
)
```

## Usage

```swift
let client = OpenAI(apiKey: apiKey)
let messages = [
    OpenAI.ChatMessage.userMessage(
        OpenAI.MessageParam(role: "user", content: newMessage)
    )
]
let response = try await client.chat.completions.create(
    model: self.model,
    messages: messages,
    tools: tools,
    toolChoice: "auto"
)
```

## Features

- Models: it contains the foundation models for chat completion and realtime API service.
- Client:
  - OpenAI: chat completion client
  - ReatlimeClient: with option to configure WebSocket or WebRTC

## Other similiar libraries

- [A modern Swift SDK for OpenAI's Realtime API](https://github.com/m1guelpf/swift-realtime-openai). Note: current project is inspired by this library.
