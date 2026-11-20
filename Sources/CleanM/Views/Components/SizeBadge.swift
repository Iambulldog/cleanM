import SwiftUI

struct SizeBadge: View {
    var bytes: Int64
    var tint: Color = .white

    var body: some View {
        Text(ByteFormat.string(bytes))
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.18), in: Capsule())
            .foregroundStyle(tint)
    }
}
