import Darwin
import SwiftUI

@MainActor
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var size: CGFloat
    var opacity: Double
    var originalVelocity: CGPoint = CGPoint(x: 0, y: 0)  // Store original velocity for reverting after force field effect
}

@MainActor
struct ParticleBackgroundView: View {
    @State private var particles: [Particle] = []
    @State private var timer: Timer?
    @State private var currentSize: CGSize
    @State private var interactionPoint: CGPoint?
    @GestureState private var isDragging = false

    // Adjust these values for different movement styles
    let forceFieldRadius: CGFloat = 50 // Increased radius for gentler effect
    let forceFieldStrength: CGFloat = 2.0 // Reduced strength for slower movement
    let baseSpeed: CGFloat = 0.3 // Reduced base speed for particles

    static private func createInitialParticles(for size: CGSize) -> [Particle] {
        var initialParticles: [Particle] = []
        for _ in 0...50 {
            let velocity = CGPoint(
                x: CGFloat.random(in: -0.3...0.3), // Reduced velocity range
                y: CGFloat.random(in: -0.3...0.3)  // Reduced velocity range
            )
            initialParticles.append(Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                velocity: velocity,
                size: CGFloat.random(in: 3...8),
                opacity: Double.random(in: 0.3...0.7),
                originalVelocity: velocity
            ))
        }
        return initialParticles
    }

    init(screenSize: CGSize) {
        self._currentSize = State(initialValue: screenSize)
        self._particles = State(initialValue: Self.createInitialParticles(for: screenSize))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base layer with system material
                #if os(macOS)
                VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                #else
                Color.clear
                    .background(.ultraThinMaterial)
                #endif
                Canvas { context, _ in
                    // Draw particles
                    for particle in particles {
                        context.opacity = particle.opacity
                        context.fill(
                            Circle().path(in: CGRect(
                                x: particle.position.x,
                                y: particle.position.y,
                                width: particle.size,
                                height: particle.size
                            )),
                            with: .color(.white)
                        )
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
                    let wobble = Darwin.sin(CFAbsoluteTimeGetCurrent() * 2 + Double(particle.id.hashValue)) * 0.2
                    let force = (forceFieldRadius - distance) / forceFieldRadius * (forceFieldStrength + wobble)

                    newParticle.velocity.x += Darwin.cos(angle) * force * 0.5
                    newParticle.velocity.y += Darwin.sin(angle) * force * 0.5
                } else {
                    newParticle.velocity.x = newParticle.velocity.x * 0.98 + newParticle.originalVelocity.x * 0.02
                    newParticle.velocity.y = newParticle.velocity.y * 0.98 + newParticle.originalVelocity.y * 0.02
                }
            } else {
                newParticle.velocity.x = newParticle.velocity.x * 0.98 + newParticle.originalVelocity.x * 0.02
                newParticle.velocity.y = newParticle.velocity.y * 0.98 + newParticle.originalVelocity.y * 0.02
            }

            let time = CFAbsoluteTimeGetCurrent()
            let uniqueOffset = Double(particle.id.hashValue) * 0.1
            let sineWave = Darwin.sin(time + uniqueOffset) * 0.1

            newParticle.position.x += newParticle.velocity.x * baseSpeed + CGFloat(sineWave)
            newParticle.position.y += newParticle.velocity.y * baseSpeed + CGFloat(Darwin.cos(time + uniqueOffset) * 0.1)

            // Wrap around screen logic remains the same...
            if newParticle.position.x < 0 {
                newParticle.position.x = currentSize.width
            }
            if newParticle.position.x > currentSize.width {
                newParticle.position.x = 0
            }
            if newParticle.position.y < 0 {
                newParticle.position.y = currentSize.height
            }
            if newParticle.position.y > currentSize.height {
                newParticle.position.y = 0
            }

            return newParticle
        }
    }
}
