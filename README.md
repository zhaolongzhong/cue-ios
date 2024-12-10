# Cue

An AI-powered, customizable personal assistant for iOS and macOS that allows you to create and interact with personalized AI agents across devices or servers, both locally and remotely.

## Features

- **Authentication Management**: Seamlessly sign up and log in.
- **Multi-Agent Support**: Create multiple agents and run them simultaneously to handle different tasks.
- **Live Communication**: Maintain real-time interaction with your agents through WebSocket, enabling collaborative project work and task delegation.
- **Flexible Configuration**: Customize agent runtime settings and tools to fit your personal use cases.
  - **Note**: Local agent configuration currently requires manual setup. Follow [this guide](https://plusonelabs.ai/get-started) for instructions.
- **Integrated Chat**: Simple chat functionality with providers like OpenAI and Anthropic.
- **Configurable Tools**: Leverage [Model Context Protocol](https://github.com/modelcontextprotocol) to support both OpenAI and Anthropic models.
- **Realtime Voice Chat**: Utilize OpenAI's [Realtime API](https://platform.openai.com/docs/guides/realtime) for voice-enabled interactions with agent tools.
- **API Key Management**: Easily manage and configure API keys for different services.

### Mac App

1. Download the assets zip file containing the DMG file from the [release page](https://github.com/zhaolongzhong/cue-ios/releases).
2. Unzip and open the DMG file, then drag the app into the Applications folder.

<p float="left">
  <img src="Assets/install.png" width="400" alt="install" />
</p>

For chats with OpenAI or Anthropic, configure the corresponding API keys in the settings page to enable related features.

### iOS

Currently available on TestFlight. Request an invite [here](https://plusonelabs.ai/request-demo).

## Screenshots

### iOS

**Authentication**

<p float="left">
  <img src="Assets/ios/login.png" width="200"/>
  <img src="Assets/ios/signup.png" width="200"/>
</p>

**Assistants List & Chat**

<p float="left">
  <img src="Assets/ios/assistant-list.png" width="200"/>
  <img src="Assets/ios/assistant-detail.png" width="200"/>
   <img src="Assets/ios/dev-ios.png" width="200"/>
  <img src="Assets/ios/dev-web.png" width="200"/>
</p>

**Realtime Voice Chat**

<p float="left">
  <img src="Assets/ios/realtime-1.png" width="200"/>
  <img src="Assets/ios/realtime-2.png" width="200"/>
</p>

**Settings**

<p float="left">
  <img src="Assets/ios/settings.png" width="200"/>
  <img src="Assets/ios/api-keys.png" width="200"/>
</p>

### Mac

**Authentication**

<p float="left">
  <img src="Assets/mac/login.png" width="200"/>
  <img src="Assets/mac/signup.png" width="200"/>
</p>

**Assistants List & Chat**

<p float="left">
  <img src="Assets/mac/chat-1.png" width="400"/>
  <img src="Assets/mac/chat-2.png" width="400"/>
</p>

**Realtime Voice Chat**

<p float="left">
  <img src="Assets/mac/realtime.png" width="400"/>
</p>

**Model Set Context (MCP)**

<p float="left">
  <img src="Assets/mac/mcp.png" width="400"/>
</p>

**Settings**

<p float="left">
  <img src="Assets/mac/api-keys.png" width="400"/>
</p>

## Technical Features

- **User Authentication**: Supports sign-up and login.
- **WebSocket Communication**: Enables live message updates and assistant status monitoring.
- **Voice Tool Support**: Seamlessly integrates voice-enabled tools.
- **Realtime Voice Chat**: Uses WebSocket and WebRTC technologies for interactive communication.
- **MVVM Architecture**: Employs the repository pattern as the data handling source of truth.
- **Modular Design**: Built with multiple packages (e.g., CueApp, CueOpenAI) for scalability.
- **Reusable Components**: Includes shared elements like themes and reusable views.
- **Minimal External Dependencies**:
  - Dependency injection via [Dependencies](https://github.com/pointfreeco/swift-dependencies).
  - Local data persistence using [GRDB](https://github.com/groue/GRDB.swift).
- **Modern Design**: Adopts visual effects and supports both light and dark themes.

## Architecture

```mermaid
graph TB
    subgraph "Remote Multi-agent System"
        RemoteAgent[Agent Manager]
        subgraph "Agents"
            Agent1[Agent 1]
            Agent2[Agent 2]
            AgentN[Agent N]
        end
        RemoteTools[Normal Tools]
        RemoteMCP[Model Context Protocol]

        RemoteAgent --> AgentN
        RemoteAgent --> Agent2
        RemoteAgent --> Agent1
        Agent1 & Agent2 & AgentN --> RemoteTools
        Agent1 & Agent2 & AgentN --> RemoteMCP
    end

    subgraph "Backend Services"
        iOSAgentWebSocket[WebSocket Server]
        AssistantServices[Assistant Service]
        StorageServices[Storage Service]
        ServerSideAgent[Agent Service]
    end

    subgraph "iOS/Mac App"
    iOSOpenAIChat[OpenAI Chat]
        iOSAssistantList[Assistant List]
        iOSAssistantDetail[Assistant Detail]
        iOSAnthropicChat[Anthropic Chat]
        iOSChatViewScreen[ChatViewScreen]
        iOSTools[Normal Tools]
        iOSToolManager[Tool Manager]
    end

    subgraph "MacOS App"
        MCP[Model Context Protocol]
        MCPTools[MCP Server Tools]
    end

    subgraph "CueOpenAI Package"
        RealTimeAPI[Realtime API]
        AudioManager[Audio Manager]
        WebRTCManager[Realtime WebRTC]
        RealtimeWebSocket[Realtime WebSocket]
    end

    %% iOS Connections
    iOSAssistantList --> iOSChatViewScreen
    iOSAssistantList --> iOSAssistantDetail
    iOSAnthropicChat --> iOSChatViewScreen
    iOSOpenAIChat --> iOSChatViewScreen
    iOSChatViewScreen --> iOSAgentWebSocket
    iOSAgentWebSocket --> RemoteAgent
    iOSChatViewScreen --> iOSToolManager
    iOSToolManager --> iOSTools
    iOSToolManager --> MCP

    %% macOS Connections
    MCP --> MCPTools

    %% Real-time Connections for both platforms
    iOSOpenAIChat --> RealTimeAPI
    RealTimeAPI --> WebRTCManager
    RealTimeAPI --> AudioManager
    RealTimeAPI --> RealtimeWebSocket

    %% Styling
    classDef ios fill:#e4f2ff,stroke:#333,stroke-width:2px;
    classDef macos fill:#ffeedd,stroke:#333,stroke-width:2px;
    classDef shared fill:#e8e8ff,stroke:#333,stroke-width:2px;
    classDef remote fill:#ffecec,stroke:#333,stroke-width:2px;
    classDef agent fill:#f0ffe0,stroke:#333,stroke-width:2px;

    class iOSAssistantList,iOSAssistantDetail,iOSAnthropicChat,iOSOpenAIChat,iOSChatViewScreen,iOSAgentWebSocket,iOSTools,iOSToolManager ios;
    class macOSTools,macOSToolManager,MCP,MCPTools macos;
    class RealTimeAPI,WebRTCManager,AudioManager,RealtimeWebSocket shared;
    class RemoteAgent,RemoteTools,RemoteMCP remote;
    class Agent1,Agent2,AgentN agent;
```

## CueOpenAI

This package is essentially a Swift SDK for OpenAI chat and realtime API service. For integrating those services, it probably can save few days work by use the package and or simply reeferencing it.

You can check its [README](CueOpenAI/README.md)

## Development Roadmap

- Gemini live service support

## Contributing

We welcome contributions! Please feel free to submit pull requests or open issues for any bugs or feature requests.
