import SwiftUI

#if os(macOS)

public struct CompanionWindows: Scene {
    let windowId: WindowId
    let dependencies: AppDependencies
    let configStore: WindowConfigurationStore
    @ObservedObject var windowManager: CompanionWindowManager

    public init(
        windowId: WindowId = .compainionChatWindow,
        dependencies: AppDependencies,
        configStore: WindowConfigurationStore,
        windowManager: CompanionWindowManager
    ) {
        self.windowId = windowId
        self.dependencies = dependencies
        self.configStore = configStore
        self.windowManager = windowManager
    }

    public var body: some Scene {
        WindowGroup(id: windowId.rawValue, for: String.self) { windowID in
            WindowRouter(
                windowID: windowID,
                dependencies: dependencies,
                configStore: configStore,
                windowManager: windowManager
            )
        }
        .defaultSize(width: WindowSize.Companion.width, height: WindowSize.Companion.height)
        .defaultPosition(.bottomTrailing)
        .windowResizability(.contentSize)
    }
}

struct WindowRouter: View {
    let windowID: Binding<String?>
    let dependencies: AppDependencies
    let configStore: WindowConfigurationStore
    @ObservedObject var windowManager: CompanionWindowManager

    var body: some View {
        Group {
            if let id = windowID.wrappedValue {
                CompanionWindowContent(
                    id: id,
                    dependencies: dependencies,
                    windowConfig: configStore.getConfig(for: id)
                )
                .environmentObject(windowManager)
            } else {
                EmptyView()
            }
        }
    }
}

struct CompanionWindowContent: View {
    let id: String
    let dependencies: AppDependencies
    let windowConfig: CompanionWindowConfig?
    @StateObject private var appCoordinator: AppCoordinator

    init(
        id: String,
        dependencies: AppDependencies,
        windowConfig: CompanionWindowConfig?
    ) {
        self.id = id
        self.dependencies = dependencies
        self.windowConfig = windowConfig
        _appCoordinator = StateObject(wrappedValue: .init())

    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            Group {
                let windowId = WindowId.fromRawValue(id)
                switch windowId {
                case .compainionChatWindow:
                    if let windowConfig = windowConfig {
                        if let provider = windowConfig.provider {
                            switch provider {
                            case .openai:
                                OpenAIChatView(dependencies.viewModelFactory.makeOpenAIChatViewModel, isCompanion: true)
                            case .anthropic:
                                AnthropicChatView(dependencies.viewModelFactory.makeAnthropicChatViewModel, isCompanion: true)
                            case .gemini:
                                GeminiChatView(dependencies.viewModelFactory.makeGeminiChatViewModel, isCompanion: true)
                            case .cue:
                                CueChatView(dependencies.viewModelFactory.makeCueChatViewModel, isCompanion: true)
                            }
                        } else if let assistantId = windowConfig.assistantId, let chatViewModel = dependencies.viewModelFactory.makeAssistantChatViewModelBy(id: assistantId) {
                            AssistantChatView(assistantChatViewModel: chatViewModel, assistantsViewModel: dependencies.viewModelFactory.makeAssistantsViewModel(), isCompanion: true)
                        }
                    } else {
                        EmptyView()
                    }
                case .openaiLiveChatWindow:
                    OpenAILiveChatView(
                        viewModelFactory: dependencies.viewModelFactory.makeOpenAILiveChatViewModel
                    )
                    .id(id)
                case .geminiLiveChatWindow:
                    GeminiLiveChatView(viewModelFactory: dependencies.viewModelFactory.makeGeminiChatViewModel)
                        .id(id)
                default:
                    EmptyView()
                }
            }
            .environmentObject(dependencies)
            .environmentObject(appCoordinator)

            .frame(minWidth: WindowSize.Companion.minWidth, maxWidth: .infinity, minHeight: WindowSize.Companion.minHeight, maxHeight: .infinity)
        }
        .background(
            ZStack {
                CompainionWindowAccessor(id: id, maxWidth: .infinity, cornerRadius: 14)
            }
        )
    }
}

class CustomWindow: NSWindow {
    override var canBecomeKey: Bool { true } // receive keyboard events and become the key window
    override var canBecomeMain: Bool { true } // can become the main window of the application
}

struct CompainionWindowAccessor: NSViewRepresentable {
    let id: String
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    let cornerRadius: CGFloat
    private let windowFrameDelegate: WindowFrameDelegate

    init(id: String, maxWidth: CGFloat = .infinity, maxHeight: CGFloat = .infinity, cornerRadius: CGFloat = 8) {
        self.id = id
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.cornerRadius = cornerRadius
        self.windowFrameDelegate = WindowFrameDelegate(id: id, maxWidth: maxWidth)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let existingWindow = view.window ?? NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == id }) {

                let customWindow = CustomWindow(
                    contentRect: existingWindow.frame,
                    styleMask: [.borderless, .fullSizeContentView, .closable, .resizable],
                    backing: .buffered,
                    defer: false
                )

                // Copy over the content view
                customWindow.contentView = existingWindow.contentView
                existingWindow.contentView = nil

                // Configure the custom window
                if let frameDict = UserDefaults.standard.dictionary(forKey: "windowFrame_\(id)") as? [String: CGFloat] {
                    let x = frameDict["x"] ?? customWindow.frame.origin.x
                    let y = frameDict["y"] ?? customWindow.frame.origin.y
                    let width = frameDict["width"] ?? customWindow.frame.size.width
                    let height = frameDict["height"] ?? customWindow.frame.size.height
                    let storedFrame = NSRect(x: x, y: y, width: width, height: height)
                    customWindow.setFrame(storedFrame, display: true)
                }

                customWindow.delegate = windowFrameDelegate
                customWindow.identifier = existingWindow.identifier
                customWindow.level = .init(Int(CGWindowLevelForKey(.mainMenuWindow)))
                customWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                customWindow.backgroundColor = .clear
                customWindow.isOpaque = false
                customWindow.titlebarAppearsTransparent = true
                customWindow.titleVisibility = .hidden
                customWindow.isMovableByWindowBackground = true
                customWindow.contentMaxSize = NSSize(width: maxWidth, height: maxHeight)
                customWindow.ignoresMouseEvents = false
                customWindow.acceptsMouseMovedEvents = true

                if let contentView = customWindow.contentView {
                    contentView.wantsLayer = true
                    contentView.layer?.cornerRadius = cornerRadius
                    contentView.layer?.masksToBounds = true
                }

                // Replace the original window
                customWindow.orderFront(nil)
                existingWindow.close()
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

#endif
