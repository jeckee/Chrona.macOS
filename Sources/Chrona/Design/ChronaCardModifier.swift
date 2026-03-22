import SwiftUI

/// 统一表面：内边距、填充、描边、轻阴影、裁剪（圆角 `Surface.cornerRadius`）。
struct ChronaCardModifier: ViewModifier {
    enum Fill {
        case color(Color)
        case gradient(LinearGradient)
    }

    var fill: Fill
    var padding: CGFloat = ChronaTokens.Card.padding
    var cornerRadius: CGFloat = ChronaTokens.Surface.cornerRadius

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background { fillShape }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(ChronaTokens.Colors.border, lineWidth: ChronaTokens.Surface.strokeWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: ChronaTokens.Elevation.cardShadowColor,
                radius: ChronaTokens.Elevation.cardShadowRadius,
                x: 0,
                y: ChronaTokens.Elevation.cardShadowY
            )
    }

    @ViewBuilder
    private var fillShape: some View {
        switch fill {
        case .color(let color):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(color)
        case .gradient(let gradient):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(gradient)
        }
    }
}

extension View {
    func chronaCard(
        fill: Color,
        padding: CGFloat = ChronaTokens.Card.padding,
        cornerRadius: CGFloat = ChronaTokens.Surface.cornerRadius
    ) -> some View {
        modifier(ChronaCardModifier(fill: .color(fill), padding: padding, cornerRadius: cornerRadius))
    }

    func chronaCard(
        gradient: LinearGradient,
        padding: CGFloat = ChronaTokens.Card.padding,
        cornerRadius: CGFloat = ChronaTokens.Surface.cornerRadius
    ) -> some View {
        modifier(ChronaCardModifier(fill: .gradient(gradient), padding: padding, cornerRadius: cornerRadius))
    }
}
