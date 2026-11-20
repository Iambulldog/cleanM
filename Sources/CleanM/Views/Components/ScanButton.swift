import SwiftUI

struct ScanButton: View {
    var title: String
    var subtitle: String? = nil
    var size: CGFloat = 190
    var action: () -> Void

    @State private var pulse = false
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.scanGradient)
                    .opacity(0.35)
                    .scaleEffect(pulse ? 1.18 : 1.0)
                    .blur(radius: 18)
                Circle()
                    .fill(Theme.scanGradient)
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 2))
                    .shadow(color: Theme.moss.opacity(0.55), radius: hovering ? 30 : 18)
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: size * 0.13, weight: .bold, design: .rounded))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: size * 0.065, weight: .medium, design: .rounded))
                            .opacity(0.85)
                    }
                }
                .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .scaleEffect(hovering ? 1.04 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(Theme.spring) { hovering = h } }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
