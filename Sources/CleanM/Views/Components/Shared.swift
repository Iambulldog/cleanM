import AppKit
import SwiftUI

/// Tri-state checkbox: true = checked, false = empty, nil = mixed.
struct CheckBox: View {
    var state: Bool?
    var tint: Color = Theme.mint
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: state == true ? "checkmark.square.fill" : (state == nil ? "minus.square.fill" : "square"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(state == false ? Color.white.opacity(0.55) : tint)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state == true ? "Selected" : (state == nil ? "Partially selected" : "Not selected"))
    }
}

struct FileIcon: View {
    let url: URL
    var size: CGFloat = 28

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}

struct ModuleHeader: View {
    let module: Module
    var subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: module.symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(module.accent)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(module.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct PillButtonStyle: ButtonStyle {
    var colors: [Color] = [Theme.leaf, Theme.moss]
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background {
                if prominent {
                    Capsule().fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                } else {
                    Capsule().fill(.white.opacity(0.12))
                }
            }
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.spring, value: configuration.isPressed)
    }
}

struct ResultBanner: View {
    let result: CleanResult
    @State private var showFailures = false

    var body: some View {
        GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: result.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(result.failures.isEmpty ? Theme.lime : Theme.amber)
                    Text(result.summary).font(.callout.weight(.medium))
                    Spacer()
                    if !result.failures.isEmpty {
                        Button(showFailures ? "Hide details" : "Show details") {
                            withAnimation(Theme.spring) { showFailures.toggle() }
                        }
                        .buttonStyle(.link)
                    }
                }
                if showFailures {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(result.failures) { failure in
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(failure.url.lastPathComponent).font(.caption.weight(.semibold))
                                    Text(failure.message).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                }
            }
        }
    }
}

struct Sparkline: View {
    var values: [Double]
    var color: Color
    var maxValue: Double? = nil

    var body: some View {
        GeometryReader { geo in
            let top = max(maxValue ?? (values.max() ?? 1), 0.0001)
            let step = values.count > 1 ? geo.size.width / CGFloat(values.count - 1) : 0
            let points = values.enumerated().map { i, v in
                CGPoint(x: CGFloat(i) * step, y: geo.size.height * (1 - CGFloat(min(v / top, 1))))
            }
            ZStack {
                Path { p in
                    guard let first = points.first else { return }
                    p.move(to: CGPoint(x: first.x, y: geo.size.height))
                    points.forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: points.last?.x ?? 0, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                Path { p in
                    guard let first = points.first else { return }
                    p.move(to: first)
                    points.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

struct EmptyStateView: View {
    var symbol: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 42)).foregroundStyle(.secondary)
            Text(title).font(.title3.weight(.semibold))
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
