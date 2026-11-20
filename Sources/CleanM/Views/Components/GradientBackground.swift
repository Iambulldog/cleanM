import SwiftUI

struct GradientBackground: View {
    var colors: [Color]
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill((colors.last ?? .purple).opacity(0.55))
                .frame(width: 520, height: 520)
                .blur(radius: 140)
                .offset(x: animate ? 220 : 160, y: animate ? -180 : -120)
            Circle()
                .fill((colors.first ?? .blue).opacity(0.6))
                .frame(width: 460, height: 460)
                .blur(radius: 130)
                .offset(x: animate ? -240 : -180, y: animate ? 200 : 150)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { animate = true }
        }
    }
}
