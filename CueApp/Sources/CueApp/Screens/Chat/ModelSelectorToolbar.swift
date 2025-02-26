import SwiftUI

struct ModelSelectorToolbar<Model: Equatable & Hashable>: ToolbarContent {
    let currentModel: Model
    let models: [Model]
    let iconView: AnyView
    let getModelName: (Model) -> String
    let onModelSelected: (Model) -> Void
    let isStreamingEnabled: Binding<Bool>?
    let isToolEnabled: Binding<Bool>?

    #if os(macOS)
    @State private var isShowingPopover = false
    #endif

    init(
        currentModel: Model,
        models: [Model],
        iconView: AnyView,
        getModelName: @escaping (Model) -> String,
        onModelSelected: @escaping (Model) -> Void,
        isStreamingEnabled: Binding<Bool>? = nil,
        isToolEnabled: Binding<Bool>? = nil
    ) {
        self.currentModel = currentModel
        self.models = models
        self.iconView = iconView
        self.getModelName = getModelName
        self.onModelSelected = onModelSelected
        self.isStreamingEnabled = isStreamingEnabled
        self.isToolEnabled = isToolEnabled
    }

    var body: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .principal) {
            Menu {
                ForEach(models, id: \.self) { model in
                    Button {
                        onModelSelected(model)
                    } label: {
                        HStack {
                            Text(getModelName(model))
                            if currentModel == model {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    iconView
                    Text(getModelName(currentModel))
                        .font(.body)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(.primary)
            }
        }
        #else
        ToolbarItem(placement: .navigation) {
            HStack {
                Button {
                    isShowingPopover.toggle()
                } label: {
                    HStack(spacing: 4) {
                        iconView
                        Text(getModelName(currentModel))
                            .font(.headline)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 10, height: 10)
                    }
                }
                .buttonStyle(HoverBorderlessButtonStyle(isActive: isShowingPopover))
                .popover(isPresented: $isShowingPopover, arrowEdge: .top) {
                    ModelPickerPopover(
                        models: models,
                        currentModel: currentModel,
                        getModelName: getModelName,
                        onModelSelected: { model in
                            onModelSelected(model)
                            isShowingPopover = false
                        },
                        isStreamingEnabled: isStreamingEnabled,
                        isToolEnabled: isToolEnabled
                    )
                }
            }
        }
        #endif
    }
}

#if os(macOS)
struct HoverBorderlessButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        HoverEffect(configuration: configuration, isActive: isActive)
    }

    struct HoverEffect: View {
        let configuration: ButtonStyleConfiguration
        let isActive: Bool
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(configuration.isPressed || isHovered || isActive
                            ? Color.gray.opacity(0.2)
                            : Color.clear)
                )
                .cornerRadius(4)
                .onHover { hovering in
                    isHovered = hovering
                }
        }
    }
}

struct ModelPickerPopover<Model: Equatable & Hashable>: View {
    let models: [Model]
    let currentModel: Model
    let getModelName: (Model) -> String
    let onModelSelected: (Model) -> Void
    let isStreamingEnabled: Binding<Bool>?
    let isToolEnabled: Binding<Bool>?

    @State private var isStreamingRowHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Model list
            ForEach(models, id: \.self) { model in
                ModelSelectionRow(
                    model: model,
                    currentModel: currentModel,
                    modelName: getModelName(model),
                    onSelect: onModelSelected
                )
            }

            if let streamingBinding = isStreamingEnabled {
                Divider()
                    .padding(.vertical, 4)

                PopoverToggleRow(title: "Enable streaming", binding: streamingBinding)
                    .padding(.bottom, 4)
            }

            if let isToolEnabled = isToolEnabled {
                Divider()
                    .padding(.vertical, 4)

                PopoverToggleRow(title: "Enable tools", binding: isToolEnabled)
                    .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 4)
        .background(.thinMaterial)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

#endif

struct ModelPickerButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        HoverEffectButton(configuration: configuration, isSelected: isSelected)
    }

    struct HoverEffectButton: View {
        let configuration: ButtonStyleConfiguration
        let isSelected: Bool
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(
                        configuration.isPressed || isHovered
                            ? Color.gray.opacity(0.15)
                            : Color.clear
                    )
                )
                .padding(.horizontal, 8)
                .cornerRadius(8)
                .onHover { hovering in
                    isHovered = hovering
                }
        }
    }
}

struct ModelSelectionRow<Model: Equatable>: View {
    let model: Model
    let currentModel: Model
    let modelName: String
    let onSelect: (Model) -> Void

    var body: some View {
        Button {
            onSelect(model)
        } label: {
            HStack {
                Text(modelName)
                    .font(.body)
                Spacer()
                if currentModel == model {
                    Image(systemName: "checkmark")
                        .foregroundColor(.primary)
                }
            }
            .frame(minWidth: 200)
            .contentShape(Rectangle())
        }
        .buttonStyle(ModelPickerButtonStyle(isSelected: currentModel == model))
    }
}

struct PopoverToggleRow: View {
    let title: String
    let binding: Binding<Bool>
    @State private var isHovered = false

    var body: some View {
        Button {
            binding.wrappedValue.toggle()
        } label: {
            HStack {
                Text(title)
                    .font(.body)
                    .padding(.leading, 12)
                Spacer()
                Toggle(title, isOn: binding)
                    .scaleEffect(0.8)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .frame(height: 36)
            .frame(minWidth: 200)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isHovered
                        ? Color.gray.opacity(0.15)
                        : Color.clear
                )
                .padding(.horizontal, 8)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
