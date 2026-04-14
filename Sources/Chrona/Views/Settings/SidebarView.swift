import SwiftUI

/// Figma「Aside - Left Tab Navigation」：侧栏固定宽度，选中项白底卡片。
struct SidebarView: View {
    @Binding var selection: ChronaSettingsPane

    private let sidebarWidth: CGFloat = 208

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ChronaTokens.Colors.subtext)
                .padding(.horizontal, ChronaTokens.Space.lg)
                .padding(.bottom, ChronaTokens.Space.md)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(ChronaSettingsPane.allCases) { pane in
                    sidebarRow(pane)
                }
            }
            .padding(.horizontal, ChronaTokens.Space.sm + ChronaTokens.Space.xs)

            Spacer(minLength: 0)
        }
        .frame(width: sidebarWidth, alignment: .leading)
        .padding(.vertical, ChronaTokens.Space.lg + ChronaTokens.Space.sm)
        .background(
            ChronaTokens.Colors.canvas.opacity(0.55)
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(ChronaTokens.Colors.border.opacity(0.35))
                .frame(width: ChronaTokens.Surface.strokeWidth)
        }
    }

    @ViewBuilder
    private func sidebarRow(_ pane: ChronaSettingsPane) -> some View {
        let isSelected = selection == pane
        Button {
            selection = pane
        } label: {
            HStack(spacing: 10) {
                Image(systemName: pane.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(rowIconColor(isSelected: isSelected))
                    .frame(width: 14, height: 14, alignment: .center)

                Text(pane.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(rowTitleColor(isSelected: isSelected))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: ChronaTokens.Radius.md, style: .continuous)
                        .fill(ChronaTokens.Colors.bg)
                        .shadow(
                            color: ChronaTokens.Elevation.cardShadowColor,
                            radius: ChronaTokens.Elevation.cardShadowRadius,
                            x: 0,
                            y: ChronaTokens.Elevation.cardShadowY
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: ChronaTokens.Radius.md, style: .continuous)
                                .strokeBorder(ChronaTokens.Colors.border.opacity(0.5), lineWidth: ChronaTokens.Surface.strokeWidth)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowIconColor(isSelected: Bool) -> Color {
        isSelected ? ChronaTokens.Colors.primary : ChronaTokens.Colors.subtext
    }

    private func rowTitleColor(isSelected: Bool) -> Color {
        isSelected ? ChronaTokens.Colors.primary : ChronaTokens.Colors.text
    }
}
