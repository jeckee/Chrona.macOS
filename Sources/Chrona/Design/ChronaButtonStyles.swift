import SwiftUI

struct ChronaPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        ChronaPrimaryButtonBody(configuration: configuration, isEnabled: isEnabled)
    }
}

private struct ChronaPrimaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isEnabled: Bool
    @State private var isHovered = false

    private var fill: Color {
        guard isEnabled else { return ChronaTokens.Colors.bgSoft }
        if isHovered { return ChronaTokens.Colors.primaryHover }
        return ChronaTokens.Colors.primary
    }

    var body: some View {
        configuration.label
            .foregroundStyle(isEnabled ? ChronaTokens.Colors.onFill : ChronaTokens.Colors.subtext)
            .padding(.horizontal, ChronaTokens.Button.paddingHorizontal)
            .padding(.vertical, ChronaTokens.Button.paddingVertical)
            .frame(minHeight: ChronaTokens.Button.minHeight)
            .background(
                RoundedRectangle(cornerRadius: ChronaTokens.Surface.cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ChronaTokens.Surface.cornerRadius, style: .continuous)
                    .strokeBorder(ChronaTokens.Colors.border, lineWidth: ChronaTokens.Surface.strokeWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: ChronaTokens.Surface.cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ChronaTokens.Motion.standard, value: isHovered)
            .animation(ChronaTokens.Motion.standard, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

struct ChronaSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        ChronaSecondaryButtonBody(configuration: configuration, isEnabled: isEnabled)
    }
}

private struct ChronaSecondaryButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isEnabled: Bool
    @State private var isHovered = false

    private var fill: Color {
        guard isEnabled else { return ChronaTokens.Colors.bgSoft }
        if isHovered { return ChronaTokens.Colors.bgSoftHover }
        return ChronaTokens.Colors.bgSoft
    }

    var body: some View {
        configuration.label
            .foregroundStyle(isEnabled ? ChronaTokens.Colors.text : ChronaTokens.Colors.subtext)
            .padding(.horizontal, ChronaTokens.Button.paddingHorizontal)
            .padding(.vertical, ChronaTokens.Button.paddingVertical)
            .frame(minHeight: ChronaTokens.Button.minHeight)
            .background(
                RoundedRectangle(cornerRadius: ChronaTokens.Surface.cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ChronaTokens.Surface.cornerRadius, style: .continuous)
                    .strokeBorder(ChronaTokens.Colors.border, lineWidth: ChronaTokens.Surface.strokeWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: ChronaTokens.Surface.cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ChronaTokens.Motion.standard, value: isHovered)
            .animation(ChronaTokens.Motion.standard, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

struct ChronaWarningFilledButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        ChronaWarningFilledButtonBody(configuration: configuration, isEnabled: isEnabled)
    }
}

private struct ChronaWarningFilledButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isEnabled: Bool
    @State private var isHovered = false

    private var fill: Color {
        guard isEnabled else { return ChronaTokens.Colors.bgSoft }
        if isHovered { return ChronaTokens.Colors.warningHover }
        return ChronaTokens.Colors.warning
    }

    var body: some View {
        configuration.label
            .foregroundStyle(isEnabled ? ChronaTokens.Colors.onFill : ChronaTokens.Colors.subtext)
            .padding(.horizontal, ChronaTokens.Button.paddingHorizontal)
            .padding(.vertical, ChronaTokens.Button.paddingVertical)
            .frame(minHeight: ChronaTokens.Button.minHeight)
            .background(
                RoundedRectangle(cornerRadius: ChronaTokens.Surface.cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ChronaTokens.Surface.cornerRadius, style: .continuous)
                    .strokeBorder(ChronaTokens.Colors.border, lineWidth: ChronaTokens.Surface.strokeWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: ChronaTokens.Surface.cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ChronaTokens.Motion.standard, value: isHovered)
            .animation(ChronaTokens.Motion.standard, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

struct ChronaPlainTextButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ChronaTokens.Colors.warning.opacity(isHovered ? 1 : 0.92))
            .padding(.horizontal, ChronaTokens.Button.paddingHorizontal)
            .padding(.vertical, ChronaTokens.Button.paddingVertical)
            .frame(minHeight: ChronaTokens.Button.minHeight)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(ChronaTokens.Motion.standard, value: isHovered)
            .animation(ChronaTokens.Motion.standard, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

struct ChronaPrimaryIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        ChronaPrimaryIconButtonBody(configuration: configuration, isEnabled: isEnabled)
    }
}

private struct ChronaPrimaryIconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isEnabled: Bool
    @State private var isHovered = false

    private var fill: Color {
        guard isEnabled else { return ChronaTokens.Colors.bgSoft }
        if isHovered { return ChronaTokens.Colors.primaryHover }
        return ChronaTokens.Colors.primary
    }

    var body: some View {
        configuration.label
            .foregroundStyle(isEnabled ? ChronaTokens.Colors.onFill : ChronaTokens.Colors.subtext)
            .frame(width: ChronaTokens.Button.minHeight, height: ChronaTokens.Button.minHeight)
            .background(
                RoundedRectangle(cornerRadius: ChronaTokens.Surface.cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ChronaTokens.Surface.cornerRadius, style: .continuous)
                    .strokeBorder(ChronaTokens.Colors.border, lineWidth: ChronaTokens.Surface.strokeWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: ChronaTokens.Surface.cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ChronaTokens.Motion.standard, value: isHovered)
            .animation(ChronaTokens.Motion.standard, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

extension ButtonStyle where Self == ChronaPrimaryButtonStyle {
    static var chronaPrimary: ChronaPrimaryButtonStyle { ChronaPrimaryButtonStyle() }
}

extension ButtonStyle where Self == ChronaSecondaryButtonStyle {
    static var chronaSecondary: ChronaSecondaryButtonStyle { ChronaSecondaryButtonStyle() }
}

extension ButtonStyle where Self == ChronaWarningFilledButtonStyle {
    static var chronaWarningFilled: ChronaWarningFilledButtonStyle { ChronaWarningFilledButtonStyle() }
}

extension ButtonStyle where Self == ChronaPlainTextButtonStyle {
    static var chronaPlain: ChronaPlainTextButtonStyle { ChronaPlainTextButtonStyle() }
}

extension ButtonStyle where Self == ChronaPrimaryIconButtonStyle {
    static var chronaPrimaryIcon: ChronaPrimaryIconButtonStyle { ChronaPrimaryIconButtonStyle() }
}

// MARK: - Figma 侧栏行内：描边主/警告色、摘要、仅图标

struct ChronaOutlineAccentRowButtonStyle: ButtonStyle {
    enum Accent {
        case primary
        case warning
    }

    var accent: Accent
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var foreground: Color {
        switch accent {
        case .primary: return ChronaTokens.Colors.primary
        case .warning: return ChronaTokens.Colors.warning
        }
    }

    private var border: Color {
        switch accent {
        case .primary: return ChronaTokens.Colors.primaryOutline
        case .warning: return ChronaTokens.Colors.warningOutline
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: ChronaTokens.Typography.Size.caption, weight: .semibold))
            .foregroundStyle(isEnabled ? foreground : ChronaTokens.Colors.subtext)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: ChronaTokens.Radius.sm, style: .continuous)
                    .fill(ChronaTokens.Colors.bg)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ChronaTokens.Radius.sm, style: .continuous)
                    .strokeBorder(border, lineWidth: ChronaTokens.Surface.strokeWidth)
            }
            .shadow(color: ChronaTokens.Elevation.cardShadowColor, radius: 1, x: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isHovered && isEnabled ? 1 : (isEnabled ? 0.98 : 1))
            .animation(ChronaTokens.Motion.standard, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

struct ChronaFilledRowActionButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case warning
    }

    var kind: Kind
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var fill: Color {
        guard isEnabled else { return ChronaTokens.Colors.bgSoft }
        switch kind {
        case .primary:
            return isHovered ? ChronaTokens.Colors.primaryHover : ChronaTokens.Colors.primary
        case .warning:
            return isHovered ? ChronaTokens.Colors.warningHover : ChronaTokens.Colors.warning
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: ChronaTokens.Typography.Size.caption, weight: .semibold))
            .foregroundStyle(isEnabled ? ChronaTokens.Colors.onFill : ChronaTokens.Colors.subtext)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: ChronaTokens.Radius.sm, style: .continuous)
                    .fill(fill)
            )
            .shadow(color: ChronaTokens.Elevation.cardShadowColor, radius: 1, x: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ChronaTokens.Motion.standard, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

struct ChronaIconBorderButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? ChronaTokens.Colors.text : ChronaTokens.Colors.subtext)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: ChronaTokens.Radius.sm, style: .continuous)
                    .fill(ChronaTokens.Colors.bg)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ChronaTokens.Radius.sm, style: .continuous)
                    .strokeBorder(ChronaTokens.Colors.border, lineWidth: ChronaTokens.Surface.strokeWidth)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ChronaTokens.Motion.standard, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

struct ChronaSummaryHeaderButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, ChronaTokens.Space.lg)
            .padding(.vertical, ChronaTokens.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: ChronaTokens.Radius.md, style: .continuous)
                    .fill(
                        isHovered
                            ? ChronaTokens.Colors.primarySummaryTint.opacity(1.08)
                            : ChronaTokens.Colors.primarySummaryTint
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(ChronaTokens.Motion.standard, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

/// 与 `ChronaSummaryHeaderButtonStyle` 同内边距与圆角，用于顶栏 Summary 旁的次要操作（高度对齐）。
struct ChronaHeaderPairedSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var fill: Color {
        guard isEnabled else { return ChronaTokens.Colors.bgSoft }
        return isHovered ? ChronaTokens.Colors.bgSoftHover : ChronaTokens.Colors.bgSoft
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? ChronaTokens.Colors.text : ChronaTokens.Colors.subtext)
            .padding(.horizontal, ChronaTokens.Space.lg)
            .padding(.vertical, ChronaTokens.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: ChronaTokens.Radius.md, style: .continuous)
                    .fill(fill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: ChronaTokens.Radius.md, style: .continuous)
                    .strokeBorder(ChronaTokens.Colors.border, lineWidth: ChronaTokens.Surface.strokeWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: ChronaTokens.Radius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(ChronaTokens.Motion.standard, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

struct ChronaAutoSchedulePillButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: ChronaTokens.Typography.Size.caption, weight: .medium))
            .foregroundStyle(ChronaTokens.Colors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: ChronaTokens.Radius.sm, style: .continuous)
                    .fill(isHovered ? ChronaTokens.Colors.primaryWash.opacity(1.2) : ChronaTokens.Colors.primaryWash)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(ChronaTokens.Motion.standard, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

struct ChronaSendSquareButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var fill: Color {
        guard isEnabled else { return ChronaTokens.Colors.bgSoft }
        return isHovered ? ChronaTokens.Colors.primaryHover : ChronaTokens.Colors.primary
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? ChronaTokens.Colors.onFill : ChronaTokens.Colors.subtext)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: ChronaTokens.Radius.md, style: .continuous)
                    .fill(fill)
            )
            .shadow(color: ChronaTokens.Elevation.cardShadowColor, radius: 1, x: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ChronaTokens.Motion.standard, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

extension ButtonStyle where Self == ChronaOutlineAccentRowButtonStyle {
    static func chronaOutlineRow(accent: ChronaOutlineAccentRowButtonStyle.Accent) -> ChronaOutlineAccentRowButtonStyle {
        ChronaOutlineAccentRowButtonStyle(accent: accent)
    }
}

extension ButtonStyle where Self == ChronaFilledRowActionButtonStyle {
    static func chronaFilledRow(_ kind: ChronaFilledRowActionButtonStyle.Kind) -> ChronaFilledRowActionButtonStyle {
        ChronaFilledRowActionButtonStyle(kind: kind)
    }
}

extension ButtonStyle where Self == ChronaIconBorderButtonStyle {
    static var chronaIconBorder: ChronaIconBorderButtonStyle { ChronaIconBorderButtonStyle() }
}

extension ButtonStyle where Self == ChronaSummaryHeaderButtonStyle {
    static var chronaSummaryHeader: ChronaSummaryHeaderButtonStyle { ChronaSummaryHeaderButtonStyle() }
}

extension ButtonStyle where Self == ChronaHeaderPairedSecondaryButtonStyle {
    static var chronaHeaderPairedSecondary: ChronaHeaderPairedSecondaryButtonStyle {
        ChronaHeaderPairedSecondaryButtonStyle()
    }
}

extension ButtonStyle where Self == ChronaAutoSchedulePillButtonStyle {
    static var chronaAutoSchedulePill: ChronaAutoSchedulePillButtonStyle { ChronaAutoSchedulePillButtonStyle() }
}

extension ButtonStyle where Self == ChronaSendSquareButtonStyle {
    static var chronaSendSquare: ChronaSendSquareButtonStyle { ChronaSendSquareButtonStyle() }
}

struct ChronaToolbarGlyphCircleButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(ChronaTokens.Colors.bg)
            )
            .overlay {
                Circle()
                    .strokeBorder(ChronaTokens.Colors.border, lineWidth: ChronaTokens.Surface.strokeWidth)
            }
            .shadow(color: ChronaTokens.Elevation.cardShadowColor, radius: 1, x: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(ChronaTokens.Motion.standard, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

extension ButtonStyle where Self == ChronaToolbarGlyphCircleButtonStyle {
    static var chronaToolbarGlyphCircle: ChronaToolbarGlyphCircleButtonStyle {
        ChronaToolbarGlyphCircleButtonStyle()
    }
}
