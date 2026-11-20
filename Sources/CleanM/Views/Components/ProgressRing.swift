import SwiftUI

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 14
    var gradient: AngularGradient = Theme.scanAngular
    var trackOpacity: Double = 0.12

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.leaf.opacity(0.6), radius: 8)
        }
        .animation(Theme.spring, value: progress)
    }
}

/// Small gauge used by the monitor cards.
struct GaugeRing: View {
    var value: Double
    var colors: [Color]
    var lineWidth: CGFloat = 10

    var body: some View {
        ProgressRing(progress: value, lineWidth: lineWidth,
                     gradient: AngularGradient(colors: colors + [colors.first ?? .white], center: .center))
    }
}
