import SwiftUI

struct AppearanceSection: View {
    @ObservedObject var store: ChronaSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: ChronaTokens.Space.lg + ChronaTokens.Space.xs) {
            sectionHeader

            VStack(alignment: .leading, spacing: ChronaTokens.Space.md) {
                Text("Choose how Chrona should look across all windows.")
                    .font(ChronaTokens.Typography.caption)
                    .foregroundStyle(ChronaTokens.Colors.subtext)

                Picker("Appearance", selection: $store.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360, alignment: .leading)
            }
        }
        .padding(21)
        .background {
            RoundedRectangle(cornerRadius: ChronaTokens.Radius.lg, style: .continuous)
                .fill(ChronaTokens.Colors.bg)
        }
        .overlay {
            RoundedRectangle(cornerRadius: ChronaTokens.Radius.lg, style: .continuous)
                .strokeBorder(ChronaTokens.Colors.border.opacity(0.35), lineWidth: ChronaTokens.Surface.strokeWidth)
        }
        .shadow(
            color: ChronaTokens.Elevation.cardShadowColor,
            radius: ChronaTokens.Elevation.cardShadowRadius,
            x: 0,
            y: ChronaTokens.Elevation.cardShadowY
        )
    }

    private var sectionHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: ChronaSettingsPane.appearance.systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ChronaTokens.Colors.subtext)
            Text("Appearance")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ChronaTokens.Colors.text)
        }
    }
}
