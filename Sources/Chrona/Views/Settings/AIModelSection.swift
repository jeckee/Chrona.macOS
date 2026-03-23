import SwiftUI

struct AIModelSection: View {
    @ObservedObject var store: ChronaSettingsStore

    private let labelGray = Color(red: 136 / 255, green: 136 / 255, blue: 136 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: ChronaTokens.Space.lg + ChronaTokens.Space.xs) {
            sectionHeader

            VStack(alignment: .leading, spacing: ChronaTokens.Space.lg + ChronaTokens.Space.xs) {
                HStack(alignment: .top, spacing: ChronaTokens.Space.md) {
                    providerField
                    modelField
                }

                apiKeyBlock
                connectionStatusRow
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
            ZStack {
                RoundedRectangle(cornerRadius: ChronaTokens.Radius.md, style: .continuous)
                    .fill(ChronaTokens.Colors.primarySoft)
                    .frame(width: 32, height: 32)
                Image(systemName: ChronaSettingsPane.aiModel.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ChronaTokens.Colors.primary)
            }
            Text("AI Model")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ChronaTokens.Colors.text)
        }
    }

    private var providerField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Provider")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(labelGray)
            Menu {
                ForEach(AIProvider.allCases) { p in
                    Button(p.displayName) {
                        store.provider = p
                    }
                }
            } label: {
                settingsMenuLabel(title: store.provider.displayName)
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Provider")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modelField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Model")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(labelGray)
            Menu {
                ForEach(store.modelPickerOptions, id: \.self) { m in
                    Button(m) {
                        store.model = m
                    }
                }
            } label: {
                settingsMenuLabel(title: store.model)
            }
            .menuStyle(.borderlessButton)
            .id(store.provider)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Model")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsMenuLabel(title: String) -> some View {
        HStack(spacing: ChronaTokens.Space.sm) {
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ChronaTokens.Colors.subtext)
        }
        .settingsFormControlChrome()
    }

    private var apiKeyBlock: some View {
        VStack(alignment: .leading, spacing: ChronaTokens.Space.sm) {
            Text("API Key")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(labelGray)

            HStack(spacing: ChronaTokens.Space.sm) {
                Group {
                    if store.apiKeyVisible {
                        TextField("API Key", text: $store.apiKey)
                            .textFieldStyle(.plain)
                    } else {
                        SecureField("API Key", text: $store.apiKey)
                            .textFieldStyle(.plain)
                    }
                }
                .settingsFormControlChrome()

                Button {
                    store.apiKeyVisible.toggle()
                } label: {
                    Image(systemName: store.apiKeyVisible ? "eye.slash" : "eye")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ChronaTokens.Colors.subtext)
                        .frame(width: ChronaTokens.Button.minHeight, height: ChronaTokens.Button.minHeight)
                }
                .buttonStyle(.chronaIconBorder)

                Button("Test") {
                    store.runConnectionTest()
                }
                .buttonStyle(.chronaPrimary)
                .disabled(store.connectionState == .testing)
            }
        }
    }

    @ViewBuilder
    private var connectionStatusRow: some View {
        switch store.connectionState {
        case .idle:
            EmptyView()
        case .testing:
            HStack(spacing: ChronaTokens.Space.sm) {
                ProgressView()
                    .controlSize(.small)
                Text("Testing…")
                    .font(ChronaTokens.Typography.captionMedium)
                    .foregroundStyle(labelGray)
            }
        case .success(let message):
            HStack(spacing: ChronaTokens.Space.sm) {
                Circle()
                    .fill(ChronaTokens.Colors.success)
                    .frame(width: 8, height: 8)
                Text("Success")
                    .font(ChronaTokens.Typography.captionMedium)
                    .foregroundStyle(ChronaTokens.Colors.success)
                Text(String(message.prefix(40)))
                    .font(ChronaTokens.Typography.captionMedium)
                    .foregroundStyle(ChronaTokens.Colors.subtext)
            }
        case .failure(let message):
            HStack(spacing: ChronaTokens.Space.sm) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ChronaTokens.Colors.warning)
                Text(String(message.prefix(80)))
                    .font(ChronaTokens.Typography.captionMedium)
                    .foregroundStyle(ChronaTokens.Colors.warning)
            }
        }
    }
}

private extension View {
    func settingsFormControlChrome(rowHeight: CGFloat = 32) -> some View {
        let shape = RoundedRectangle(cornerRadius: ChronaTokens.Button.cornerRadius, style: .continuous)
        return self
            .font(.system(size: 14))
            .foregroundStyle(ChronaTokens.Colors.text)
            .padding(.horizontal, ChronaTokens.Space.md)
            .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
            .background(ChronaTokens.Colors.bgSoft, in: shape)
            .overlay {
                shape.strokeBorder(ChronaTokens.Colors.border, lineWidth: ChronaTokens.Surface.strokeWidth)
            }
            .clipShape(shape)
    }
}
