import Foundation
import SwiftUI

@MainActor
struct GlassmorphismParticleBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var particles: [GlassParticle] = []
    @State private var timer: Timer?
    @State private var currentSize: CGSize
    @State private var interactionPoint: CGPoint?
    @GestureState private var isDragging = false
    @State private var gradientRotation: Double = 0

    let baseSpeed: CGFloat = 0.15
    let forceFieldRadius: CGFloat = 200
    let forceFieldStrength: CGFloat = 1.0

    struct GlassParticle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGPoint
        var size: CGFloat
        var opacity: Double
        var originalVelocity: CGPoint
        var hue: Double
        var blur: CGFloat
    }

    init(screenSize: CGSize) {
        self._currentSize = State(initialValue: screenSize)
        self._particles = State(initialValue: Self.createInitialParticles(for: screenSize))
    }

    static private func createInitialParticles(for size: CGSize) -> [GlassParticle] {
        var initialParticles: [GlassParticle] = []
        for _ in 0...25 {
            let velocity = CGPoint(
                x: CGFloat.random(in: -0.2...0.2),
                y: CGFloat.random(in: -0.2...0.2)
            )
            initialParticles.append(GlassParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                velocity: velocity,
                size: CGFloat.random(in: 80...200),
                opacity: Double.random(in: 0.3...0.5),
                originalVelocity: velocity,
                hue: 0.6,
                blur: CGFloat.random(in: 20...40)
            ))
        }
        return initialParticles
    }

    private func themeColors(for hue: Double) -> [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.7, green: 0.85, blue: 1.0).opacity(0.4),
                Color(red: 0.7, green: 0.85, blue: 1.0).opacity(0.0)
            ]
        } else {
            return [
                Color(red: 0.4, green: 0.6, blue: 0.9).opacity(0.4),
                Color(red: 0.4, green: 0.6, blue: 0.9).opacity(0.0)
            ]
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                #if os(macOS)
                VisualEffectView(
                    material: colorScheme == .dark ? .dark : .light,
                    blendingMode: .withinWindow
                )
                #else
                Color.clear
                    .background(.ultraThinMaterial)
                #endif

                Canvas { context, _ in
                    for particle in particles {
                        let themeOpacity = colorScheme == .light ?
                            particle.opacity * 1.4 : particle.opacity
                        context.opacity = themeOpacity

                        context.drawLayer { ctx in
                            ctx.addFilter(.blur(radius: particle.blur))

                            let rect = CGRect(
                                x: particle.position.x - particle.size/2,
                                y: particle.position.y - particle.size/2,
                                width: particle.size,
                                height: particle.size
                            )

                            let colors = themeColors(for: particle.hue)
                            let gradient = Gradient(colors: colors)

                            ctx.fill(
                                Circle().path(in: rect),
                                with: .linearGradient(
                                    gradient,
                                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                                )
                            )
                        }
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { value, state, _ in
                        state = true
                        interactionPoint = value.location
                    }
            )
            #if os(macOS)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    interactionPoint = location
                case .ended:
                    interactionPoint = nil
                }
            }
            #endif
            .onChange(of: geometry.size) { _, newSize in
                currentSize = newSize
                particles = Self.createInitialParticles(for: newSize)
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            Task { @MainActor in
                updateParticles()
            }
        }
    }

    private func updateParticles() {
        particles = particles.map { particle in
            var newParticle = particle

            // Add subtle floating motion
            let time = CFAbsoluteTimeGetCurrent()
            let uniqueOffset = Double(particle.id.hashValue) * 0.1
            let floatEffect = CGPoint(
                x: CGFloat(Darwin.sin(time * 0.5 + uniqueOffset)) * 0.2,
                y: CGFloat(Darwin.cos(time * 0.5 + uniqueOffset)) * 0.2
            )

            // Force field interaction
            if let point = interactionPoint {
                let distance = hypot(
                    particle.position.x - point.x,
                    particle.position.y - point.y
                )

                if distance < forceFieldRadius {
                    let angle = Darwin.atan2(
                        particle.position.y - point.y,
                        particle.position.x - point.x
                    )
                    let force = (forceFieldRadius - distance) / forceFieldRadius * forceFieldStrength

                    newParticle.velocity.x += Darwin.cos(angle) * force * 0.3
                    newParticle.velocity.y += Darwin.sin(angle) * force * 0.3
                }
            }

            // Update position with smooth dampening
            newParticle.velocity.x = (newParticle.velocity.x + floatEffect.x) * 0.98
            newParticle.velocity.y = (newParticle.velocity.y + floatEffect.y) * 0.98
            newParticle.position.x += newParticle.velocity.x * baseSpeed
            newParticle.position.y += newParticle.velocity.y * baseSpeed

            // Wrap around edges softly
            if newParticle.position.x < -particle.size {
                newParticle.position.x = currentSize.width + particle.size
            } else if newParticle.position.x > currentSize.width + particle.size {
                newParticle.position.x = -particle.size
            }

            if newParticle.position.y < -particle.size {
                newParticle.position.y = currentSize.height + particle.size
            } else if newParticle.position.y > currentSize.height + particle.size {
                newParticle.position.y = -particle.size
            }

            return newParticle
        }
    }
}
