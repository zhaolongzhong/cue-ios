//
//  ColorCircleView.swift
//  CueApp
//

import SwiftUI

struct ColorPickerSheetV2: View {
    @Environment(\.dismiss) private var dismiss
    @State var colorPalette: AppTheme.ColorPalette
    var onColorSelected: (AppTheme.ColorPalette) -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible()),
                           GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        #if os(macOS)
        macOSContent
        #else
        iOSContent
        #endif
    }

    var macOSContent: some View {
        VStack {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                Spacer()
                Text("Choose Color")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AppTheme.ColorPalette.allColors, id: \.name) { colorOption in
                        ColorCircleView(
                            color: colorOption.color,
                            isSelected: colorPalette.name == colorOption.name
                        )
                        .onTapGesture {
                            if colorPalette.name != colorOption.name {
                                withAnimation(.spring(response: 0.3)) {
                                    colorPalette = colorOption
                                    onColorSelected(colorOption)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 400)
    }

    var iOSContent: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(AppTheme.ColorPalette.allColors, id: \.name) { colorOption in
                            ColorCircleView(
                                color: colorOption.color,
                                isSelected: colorPalette.name == colorOption.name
                            )
                            .onTapGesture {
                                if colorPalette.name != colorOption.name {
                                    #if os(iOS)
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.prepare()
                                    generator.impactOccurred()
                                    #endif
                                    withAnimation(.spring(response: 0.3)) {
                                        colorPalette = colorOption
                                        onColorSelected(colorOption)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ColorCircleView: View {
    let color: Color
    let isSelected: Bool

    @State private var scale: CGFloat = 1.0

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 50, height: 50)
                    .scaleEffect(scale)
                    .shadow(color: isSelected ? color.opacity(0.7) : .clear, radius: isSelected ? 5 : 0)

                if isSelected {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 3)
                        .frame(width: 50, height: 50)

                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                        .shadow(color: .black.opacity(0.3), radius: 1)
                }
            }
            .animation(.spring(response: 0.3), value: isSelected)
            .onAppear {
                if isSelected {
                    withAnimation(.spring(response: 0.2)) {
                        scale = 1.1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring(response: 0.2)) {
                            scale = 1.0
                        }
                    }
                }
            }
            .onChange(of: isSelected) { _, newValue in
                if newValue {
                    withAnimation(.spring(response: 0.2)) {
                        scale = 1.1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring(response: 0.2)) {
                            scale = 1.0
                        }
                    }
                }
            }
        }
        .frame(height: 80)
    }
}
