# Cue iOS/Mac App Architecture

## Overview

Cue is a real-time chat application that supports interactions with various AI models through WebSocket connections. The application is built using Swift and SwiftUI, following MVVM repository architecture.

## Project Structure

### CueApp

Main application module containing UI and business logic.

```
CueApp/
├── AppCoordinator         # Navigation and flow control
├── AppDependencies       # Dependency injection container
├── Screens/             # Main UI screens
│   ├── Assistants      # AI assistant management
│   ├── Auth           # Authentication flows
│   ├── Chat          # Chat interface
│   ├── Home         # Main dashboard
│   ├── Realtime    # Real-time features
│   └── Settings    # App configuration
├── Models/         # Data models
├── Networking/    # API communication
├── Storage/      # Data persistence
├── WebSocket/   # Real-time communication
└── Tools/      # Agent tools
```

### CueOpenAI

OpenAI API client module for handling chat completion and Realtime API communication.

```
CueOpenAI/
├── RealtimeAPI    # WebSocket and WebRTC client
├── Models/       # API data models
```
