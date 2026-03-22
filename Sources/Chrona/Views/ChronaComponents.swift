import SwiftUI

// MARK: - 按钮标签（图标 14pt + 说明体，避免 ButtonStyle 压扁符号）

struct ChronaButtonCaptionLabel: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        if let systemImage {
            HStack(alignment: .firstTextBaseline, spacing: ChronaTokens.Space.xs) {
                Image(systemName: systemImage)
                    .font(ChronaTokens.Typography.inlineIcon)
                Text(title)
                    .font(ChronaTokens.Typography.label)
            }
        } else {
            Text(title)
                .font(ChronaTokens.Typography.label)
        }
    }
}

// MARK: - 列表区块标题（标题 + 可选计数，全应用一致）

struct ChronaSectionHeader: View {
    let title: String
    var count: Int?
    var uppercaseTitle: Bool = true
    var countTint: Color = ChronaTokens.Colors.subtext

    var body: some View {
        HStack(spacing: ChronaTokens.Space.sm) {
            Text(uppercaseTitle ? title.uppercased() : title)
                .font(ChronaTokens.Typography.sectionCaps)
                .tracking(0.6)
                .foregroundStyle(ChronaTokens.Colors.subtext)
            Spacer(minLength: ChronaTokens.Space.xs)
            if let count {
                Text("\(count)")
                    .font(.system(size: ChronaTokens.Typography.Size.accessory, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(countTint)
                    .padding(.horizontal, ChronaTokens.Space.sm)
                    .padding(.vertical, 2)
                    .background(ChronaTokens.Colors.bgSoft)
                    .clipShape(Capsule(style: .continuous))
            }
        }
        .padding(.horizontal, ChronaTokens.Space.sm)
    }
}

// MARK: - 卡片上方小标题（如「AI suggested actions」）

struct ChronaSectionLabel: View {
    let title: String
    var systemImage: String? = nil
    var iconTint: Color = ChronaTokens.Colors.subtext
    var uppercase: Bool = false
    var textColor: Color = ChronaTokens.Colors.subtext

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: ChronaTokens.Space.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconTint)
            }
            Text(uppercase ? title.uppercased() : title)
                .font(ChronaTokens.Typography.sectionOverline)
                .tracking(uppercase ? 0.35 : 0)
                .foregroundStyle(textColor)
        }
    }
}

// MARK: - 徽标 / 行内状态（圆角与按钮、卡片同源）

struct ChronaChip: View {
    enum Style {
        case neutral
        case primarySoft
        case warningSoft
        case primaryFilled
        case warningFilled
        case neutralPill
    }

    let text: String
    var systemImage: String? = nil
    var style: Style = .neutral

    private var background: Color {
        switch style {
        case .neutral, .neutralPill: return ChronaTokens.Colors.bgSoft
        case .primarySoft: return ChronaTokens.Colors.primarySoft
        case .warningSoft: return ChronaTokens.Colors.warningSoft
        case .primaryFilled: return ChronaTokens.Colors.primary
        case .warningFilled: return ChronaTokens.Colors.warning
        }
    }

    private var foreground: Color {
        switch style {
        case .neutral, .neutralPill: return ChronaTokens.Colors.subtext
        case .primarySoft: return ChronaTokens.Colors.text
        case .warningSoft: return ChronaTokens.Colors.warning
        case .primaryFilled, .warningFilled: return ChronaTokens.Colors.onFill
        }
    }

    private var chipFont: Font {
        switch style {
        case .primaryFilled, .warningFilled, .neutralPill:
            return .system(size: ChronaTokens.Typography.Size.accessory, weight: .bold)
        default:
            return ChronaTokens.Typography.micro
        }
    }

    private var showsBorder: Bool {
        switch style {
        case .primaryFilled, .warningFilled, .neutralPill: return false
        default: return true
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: ChronaTokens.Space.xs) {
            if style == .primaryFilled {
                Circle()
                    .fill(ChronaTokens.Colors.onFill)
                    .frame(width: 6, height: 6)
            }
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(text.uppercased())
                .font(chipFont)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, ChronaTokens.Chip.paddingHorizontal)
        .padding(.vertical, ChronaTokens.Chip.paddingVertical)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: ChronaTokens.Chip.cornerRadius, style: .continuous))
        .shadow(color: ChronaTokens.Elevation.cardShadowColor, radius: 1, x: 0, y: 1)
        .overlay {
            if showsBorder {
                RoundedRectangle(cornerRadius: ChronaTokens.Chip.cornerRadius, style: .continuous)
                    .strokeBorder(ChronaTokens.Colors.border, lineWidth: ChronaTokens.Surface.strokeWidth)
            }
        }
    }
}

// MARK: - 工具栏/菜单：与 Secondary 按钮同形

struct ChronaSecondaryChrome: View {
    var body: some View {
        RoundedRectangle(cornerRadius: ChronaTokens.Surface.cornerRadius, style: .continuous)
            .fill(ChronaTokens.Colors.bgSoft)
            .overlay {
                RoundedRectangle(cornerRadius: ChronaTokens.Surface.cornerRadius, style: .continuous)
                    .strokeBorder(ChronaTokens.Colors.border, lineWidth: ChronaTokens.Surface.strokeWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: ChronaTokens.Surface.cornerRadius, style: .continuous))
            .shadow(
                color: ChronaTokens.Elevation.cardShadowColor,
                radius: ChronaTokens.Elevation.cardShadowRadius,
                x: 0,
                y: ChronaTokens.Elevation.cardShadowY
            )
    }
}
