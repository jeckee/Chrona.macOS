import SwiftUI

struct ChronaDetailTopBar: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: ChronaTokens.Space.lg) {
            Spacer(minLength: 0)

            Button {
                openWindow(id: ChronaWindowID.settings)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ChronaTokens.Colors.text)
            }
            .buttonStyle(.chronaToolbarGlyphCircle)
        }
        .padding(.horizontal, 32)
        .frame(height: 64)
        .background(ChronaTokens.Colors.canvas.opacity(0.8))
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ChronaTokens.Colors.borderHairline)
                .frame(height: ChronaTokens.Surface.strokeWidth)
        }
    }
}
