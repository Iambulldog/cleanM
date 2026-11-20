import SwiftUI

struct ConfettiView: View {
    private struct Particle {
        let x: Double
        let delay: Double
        let speed: Double
        let drift: Double
        let spin: Double
        let size: Double
        let color: Color
    }

    private let particles: [Particle]
    private let start = Date()
    private let duration: Double = 3.2

    init(count: Int = 140) {
        let palette = [Theme.mint, Theme.leaf, Theme.moss, Theme.lime, Theme.amber, .yellow, .white]
        particles = (0..<count).map { _ in
            Particle(x: .random(in: 0...1),
                     delay: .random(in: 0...0.6),
                     speed: .random(in: 0.35...0.8),
                     drift: .random(in: -0.15...0.15),
                     spin: .random(in: -8...8),
                     size: .random(in: 5...10),
                     color: palette.randomElement() ?? .white)
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                for p in particles {
                    let t = elapsed - p.delay
                    guard t > 0 else { continue }
                    let progress = t * p.speed
                    guard progress < 1.3 else { continue }
                    let y = -20 + progress * (size.height + 40)
                    let x = (p.x + p.drift * sin(t * 3)) * size.width
                    let opacity = max(0, 1 - max(0, elapsed - duration + 0.8) / 0.8)
                    var ctx = context
                    ctx.opacity = opacity
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(t * p.spin))
                    let rect = CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(p.color))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
