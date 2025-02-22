import SwiftUI

struct ModelSelectorToolbar<Model: Equatable & Hashable>: ToolbarContent {
    let currentModel: Model
    let models: [Model]
    let iconView: AnyView
    let getModelName: (Model) -> String
    let onModelSelected: (Model) -> Void

    #if os(macOS)
    @State private var isShowingPopover = false
    #endif

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
                        }
                    )
                }
            }
        }
        #endif
    }
}

// Keep existing HoverBorderlessButtonStyle and ModelPickerPopover for macOS
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

    var body: some View {
        VStack(spacing: 0) {
            ForEach(models, id: \.self) { model in
                Button {
                    onModelSelected(model)
                } label: {
                    HStack {
                        Text(getModelName(model))
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
        .padding(.vertical, 4)
        .background(.thinMaterial)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

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
#endif
