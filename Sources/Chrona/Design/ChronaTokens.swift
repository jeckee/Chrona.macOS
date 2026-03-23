import SwiftUI

/// 设计令牌：间距仅用 xs / sm / md / lg / xl。
enum ChronaTokens {
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }

    /// 全局圆角：与 Figma 组件一致（卡片 8、输入 12 等）；主窗口内容为直角铺满。
    enum Surface {
        static let cornerRadius = Radius.md
        static let strokeWidth = Stroke.hairline
    }

    enum Colors {
        /// Figma 主色 `#0A7AFF`。
        static let primary = Color(red: 10 / 255, green: 122 / 255, blue: 255 / 255)
        static let primarySoft = Color(red: 10 / 255, green: 122 / 255, blue: 255 / 255, opacity: 0.12)
        static let primaryHover = Color(red: 0 / 255, green: 102 / 255, blue: 223 / 255)
        /// 进行中卡片底色 `#E6F2FF`。
        static let primaryCardTint = Color(red: 230 / 255, green: 242 / 255, blue: 255 / 255)
        static let primaryMuted = Color(red: 10 / 255, green: 122 / 255, blue: 255 / 255, opacity: 0.8)
        static let primaryOutline = Color(red: 10 / 255, green: 122 / 255, blue: 255 / 255, opacity: 0.2)
        static let primaryWash = Color(red: 10 / 255, green: 122 / 255, blue: 255 / 255, opacity: 0.05)
        static let primarySummaryTint = Color(red: 10 / 255, green: 122 / 255, blue: 255 / 255, opacity: 0.1)
        /// Figma 冲突/强调橙 `#FF9500`。
        static let warning = Color(red: 255 / 255, green: 149 / 255, blue: 0 / 255)
        static let warningSoft = Color(red: 255 / 255, green: 244 / 255, blue: 229 / 255)
        static let warningHover = Color(red: 230 / 255, green: 126 / 255, blue: 0 / 255)
        static let warningMuted = Color(red: 255 / 255, green: 149 / 255, blue: 0 / 255, opacity: 0.8)
        static let warningOutline = Color(red: 255 / 255, green: 149 / 255, blue: 0 / 255, opacity: 0.2)
        static let text = Color(red: 29 / 255, green: 29 / 255, blue: 31 / 255)
        static let subtext = Color(red: 134 / 255, green: 134 / 255, blue: 139 / 255)
        static let border = Color(red: 229 / 255, green: 229 / 255, blue: 234 / 255)
        static let borderHairline = Color(red: 229 / 255, green: 229 / 255, blue: 234 / 255, opacity: 0.5)
        static let bg = Color(red: 1, green: 1, blue: 1)
        static let bgSoft = Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
        static let bgSoftHover = Color(red: 235 / 255, green: 235 / 255, blue: 240 / 255)
        /// 主画布 `#F5F5F7`。
        static let canvas = Color(red: 245 / 255, green: 245 / 255, blue: 247 / 255)
        static let onFill = bg
        static let selectionStroke = Color(red: 10 / 255, green: 122 / 255, blue: 255 / 255, opacity: 0.22)
        static let success = Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)
        static let aiCardBorder = Color(red: 10 / 255, green: 122 / 255, blue: 255 / 255, opacity: 0.1)
    }

    enum Elevation {
        static let cardShadowColor = Color(red: 0, green: 0, blue: 0, opacity: 0.05)
        static let cardShadowRadius: CGFloat = 2
        static let cardShadowY: CGFloat = 1
    }

    enum Gradients {
        static let primarySoftCard = LinearGradient(
            colors: [
                Color(red: 10 / 255, green: 122 / 255, blue: 255 / 255, opacity: 0.12),
                Color(red: 10 / 255, green: 122 / 255, blue: 255 / 255, opacity: 0.08),
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        /// Figma「AI Suggestions Card」渐变。
        static let aiSuggestionPanel = LinearGradient(
            colors: [
                ChronaTokens.Colors.bg,
                Color(red: 230 / 255, green: 242 / 255, blue: 255 / 255, opacity: 0.3),
            ],
            startPoint: UnitPoint(x: 0.08, y: 0),
            endPoint: UnitPoint(x: 0.92, y: 1)
        )
    }

    enum Motion {
        /// 120–180ms 之间，ease-in-out。
        static let standard = Animation.easeInOut(duration: 0.15)
    }

    enum Stroke {
        static let hairline: CGFloat = 1
    }

    enum Card {
        static let padding = Space.md
        static var radius: CGFloat { Surface.cornerRadius }
        static let contentSpacing = Space.xs
        /// 标题行 → 元信息
        static let titleToMetaSpacing = Space.xs
        /// 元信息区 → 操作按钮行
        static let metaToActionsSpacing = Space.sm
        /// 主列中相邻卡片块（强压缩）
        static let stackSpacing = Space.xs
    }

    enum Button {
        static let minHeight = Space.xl
        static let paddingHorizontal = Space.sm
        static let paddingVertical = Space.xs
        static var cornerRadius: CGFloat { Surface.cornerRadius }
        static let rowSpacing = Space.xs
    }

    enum Chip {
        static let paddingHorizontal = Space.sm
        static let paddingVertical = Space.xs
        static let cornerRadius: CGFloat = Radius.sm
    }

    enum Page {
        static let gutter = Space.sm
        static let sidebarGutter = Space.lg
        static let detailHorizontalPadding: CGFloat = 78
        static let detailVerticalPadding: CGFloat = 48
        static let detailContentMaxWidth: CGFloat = 672
    }

    enum List {
        static var rowInsets: EdgeInsets {
            EdgeInsets(
                top: Space.xs,
                leading: Space.xs,
                bottom: Space.xs,
                trailing: Space.xs
            )
        }

        static let sectionBottomSpacerHeight = Space.xs

        /// 仅侧栏 **Scheduled** 区块标题相对默认位置的水平偏移（**负值向左**，正值向右）。
        static let sidebarScheduledSectionHeaderLeadingInset: CGFloat = 0

        /// 「SCHEDULED / Unscheduled」等 **header 底边** 到 **该 Section 首张卡片**：在 macOS 上 `List.listSectionSpacing` **不可用**，靠本项底部 padding 微调（**负值收紧**，如 `-Space.sm`；正值加大）。
        static let sidebarSectionHeaderBottomPadding: CGFloat = 4

        /// 侧栏任务卡片 `listRowInsets` 左侧（小于 `Space.sm` 可使整卡略向左移）。
        static let sidebarTaskRowLeadingInset: CGFloat = 0

        static var zeroInsets: EdgeInsets {
            let z = Space.xs - Space.xs
            return EdgeInsets(top: z, leading: z, bottom: z, trailing: z)
        }
    }

    enum Layout {
        /// 侧栏顶栏日期块最小宽度（内容水平居中，与两侧箭头间距对称）。
        static let sidebarHeaderDateBlockMinWidth: CGFloat = 110

        // MARK: - 主窗口 HSplitView 分割条（左：任务列表 | 右：详情）
        /// 分割条拖到**最右**（侧栏最窄）时，左列宽度不低于此值。
        static let sidebarMinWidth: CGFloat = 500
        /// 新开窗口时左列首选宽度（`HSplitView` 的 ideal）。
        static let sidebarIdealWidth: CGFloat = 500
        /// 分割条拖到**最左**（侧栏最宽）时，左列宽度不超过此值；实际还会受窗口总宽度与 `detailMinWidth` 限制（侧栏最大 ≈ 窗口宽 − 右侧最小宽）。
        static let sidebarMaxWidth: CGFloat = 500
        /// 右侧详情列最小宽度；越大，分割条越不能往左拖（侧栏可到达的最大宽度越小）。
        static let detailMinWidth = Space.lg * Space.xl + Space.lg * Space.md + Space.sm
        static let popoverWidth = Space.lg * Space.lg + Space.xs
        static let notesMinHeight = Space.sm * Space.lg
        static let listMinimumRowHeight = Stroke.hairline
        static let windowWidth =
            Space.xl * Space.xl
                + Space.lg * Space.xl
                + Space.lg * Space.md
                + Space.lg * Space.sm
                + Space.md + Space.sm + Space.xs
                + Space.xs + Space.xs + Space.xs + Space.xs
                + Space.xl
        static let windowHeight = Space.xl * (Space.lg + Space.sm + Space.md)
    }

    /// 三级排版：标题 / 正文 / 说明（元信息一律说明档 + subtext）。
    enum Typography {
        enum Size {
            static let accessory: CGFloat = 10
            static let caption: CGFloat = 12
            static let body: CGFloat = 15
            static let title: CGFloat = 24
            static let cardTitle: CGFloat = 15
            static let inlineIcon: CGFloat = 14
            static let detailHero: CGFloat = 36
            static let sectionCaps: CGFloat = 12
        }

        static let title = Font.system(size: Size.title, weight: .semibold)
        static let cardTitle = Font.system(size: Size.cardTitle, weight: .semibold)
        static let sectionCaps = Font.system(size: Size.sectionCaps, weight: .semibold)
        static let sectionOverline = Font.system(size: Size.caption, weight: .semibold)
        static let sectionOverlineBold = Font.system(size: Size.caption, weight: .bold)
        static let label = Font.system(size: Size.caption, weight: .semibold)
        static let body = Font.system(size: Size.body, weight: .regular)
        static let bodyMedium = Font.system(size: Size.body, weight: .semibold)
        static let bodyEmphasis = Font.system(size: Size.body, weight: .semibold)
        static let caption = Font.system(size: Size.caption, weight: .regular)
        static let captionMedium = Font.system(size: Size.caption, weight: .medium)
        static let metaEmphasis = Font.system(size: 14, weight: .medium)
        static let metaSecondary = Font.system(size: Size.caption, weight: .regular)
        static let detailHero = Font.system(size: Size.detailHero, weight: .bold)
        static let micro = Font.system(size: Size.accessory, weight: .semibold)
        static let accessory = Font.system(size: Size.accessory, weight: .semibold)
        static let toolbarIcon = Font.system(size: Size.inlineIcon, weight: .medium)
        static let inlineIcon = Font.system(size: Size.inlineIcon, weight: .medium)
        static let emptyStateSymbol = Font.system(size: Space.xl + Space.sm, weight: .regular)

        static var editorPointSize: CGFloat { Size.body }
    }
}
