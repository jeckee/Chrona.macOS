import SwiftUI

struct TaskListRow: View {
    @EnvironmentObject private var store: TaskStore
    let task: ChronaTask

    private var isSelected: Bool {
        store.selection == task.id
    }

    private var hasMetaLines: Bool {
        task.bucket == .scheduled
            || (task.bucket == .unscheduled && task.estimatedMinutes != nil)
            || task.isConflict
    }

    private var showsActionRow: Bool {
        true
    }

    private var cardRadius: CGFloat {
        task.bucket == .unscheduled ? ChronaTokens.Radius.lg : ChronaTokens.Surface.cornerRadius
    }

    private var titleColor: Color {
        if task.bucket == .scheduled {
            if task.isConflict { return ChronaTokens.Colors.warning }
            if task.status == .inProgress { return ChronaTokens.Colors.primary }
            if task.status == .paused { return ChronaTokens.Colors.warning }
        }
        return ChronaTokens.Colors.text
    }

    private var rowBackground: Color {
        if task.bucket == .unscheduled {
            if task.status == .paused { return ChronaTokens.Colors.warningSoft }
            return ChronaTokens.Colors.bg
        }
        if task.isConflict { return ChronaTokens.Colors.warningSoft }
        if task.status == .inProgress { return ChronaTokens.Colors.primaryCardTint }
        if task.status == .paused { return ChronaTokens.Colors.warningSoft }
        return ChronaTokens.Colors.bg
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if task.bucket == .scheduled {
                Rectangle()
                    .fill(leftAccent)
                    .frame(width: 4)
            }

            HStack(alignment: .top, spacing: ChronaTokens.Space.md) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(metaTint.opacity(0.55))
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: ChronaTokens.Space.sm) {
                        Text(task.title)
                            .font(ChronaTokens.Typography.cardTitle)
                            .foregroundStyle(titleColor)
                            .lineLimit(2)
                        Spacer(minLength: ChronaTokens.Space.xs)
                        statusTag
                    }

                    metaLines
                        .padding(.top, hasMetaLines ? 7.5 : 0)

                    if showsActionRow {
                        actionRow
                            .padding(.top, ChronaTokens.Card.metaToActionsSpacing + 2)
                    }
                }
            }
            .padding(.leading, task.bucket == .scheduled ? 12 : 4)
            .padding(.trailing, ChronaTokens.Space.lg)
            .padding(.vertical, ChronaTokens.Space.lg)
        }
        .background {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(rowBackground)
        }
        .overlay {
            if task.bucket == .unscheduled {
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .strokeBorder(
                        ChronaTokens.Colors.border,
                        style: StrokeStyle(lineWidth: ChronaTokens.Surface.strokeWidth, dash: [6, 4])
                    )
            } else {
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? ChronaTokens.Colors.selectionStroke : ChronaTokens.Colors.border.opacity(0.35),
                        lineWidth: ChronaTokens.Surface.strokeWidth
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .shadow(
            color: ChronaTokens.Elevation.cardShadowColor,
            radius: ChronaTokens.Elevation.cardShadowRadius,
            x: 0,
            y: ChronaTokens.Elevation.cardShadowY
        )
    }

    private var metaTint: Color {
        if task.isConflict { return ChronaTokens.Colors.warning }
        if task.status == .inProgress { return ChronaTokens.Colors.primary }
        if task.status == .paused { return ChronaTokens.Colors.warning }
        return ChronaTokens.Colors.subtext
    }

    @ViewBuilder
    private var metaLines: some View {
        if task.bucket == .scheduled {
            HStack(spacing: ChronaTokens.Space.lg) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(metaTint.opacity(0.85))
                    Text(ChronaFormatters.timeRange(start: task.scheduledStart, end: task.scheduledEnd))
                        .font(.system(size: ChronaTokens.Typography.Size.caption, weight: .medium))
                        .foregroundStyle(metaTint.opacity(0.85))
                }
                if task.isConflict {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(metaTint.opacity(0.85))
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(ChronaTokens.Colors.warning)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(metaTint.opacity(0.85))
                        Text(ChronaFormatters.durationString(minutes: task.durationMinutes))
                            .font(.system(size: ChronaTokens.Typography.Size.caption, weight: .regular))
                            .foregroundStyle(metaTint.opacity(0.85))
                    }
                }
            }
        } else if task.bucket == .unscheduled, let est = task.estimatedMinutes {
            HStack(spacing: 6) {
                Image(systemName: "hourglass")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(ChronaTokens.Colors.subtext)
                Text("Est. \(ChronaFormatters.durationString(minutes: est))")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(ChronaTokens.Colors.subtext)
            }
        }
    }

    private var leftAccent: Color {
        if task.isConflict { return ChronaTokens.Colors.warning }
        if task.status == .inProgress { return ChronaTokens.Colors.primary }
        if task.status == .paused { return ChronaTokens.Colors.warning }
        return ChronaTokens.Colors.border
    }

    @ViewBuilder
    private var statusTag: some View {
        switch task.status {
        case .inProgress:
            ChronaChip(text: TaskStatus.inProgress.rawValue, style: .primaryFilled)
        case .paused:
            ChronaChip(text: TaskStatus.paused.rawValue, style: .warningFilled)
        case .notStarted:
            if task.isConflict {
                ChronaChip(
                    text: "Conflict",
                    systemImage: "exclamationmark.triangle.fill",
                    style: .warningFilled
                )
            } else {
                ChronaChip(text: TaskStatus.notStarted.rawValue, style: .neutralPill)
            }
        case .completed:
            ChronaChip(text: TaskStatus.completed.rawValue, style: .neutralPill)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: ChronaTokens.Space.sm) {
            if task.bucket == .completed {
                deleteButton
            } else if task.bucket == .unscheduled {
                Button {
                    store.autoSchedule(taskID: task.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .medium))
                        Text("Auto Schedule")
                    }
                }
                .buttonStyle(.chronaAutoSchedulePill)

                deleteButton
            } else if task.isConflict {
                Button {
                    store.resume(taskID: task.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Resume")
                    }
                }
                .buttonStyle(.chronaOutlineRow(accent: .warning))

                Button {
                    store.autoFixConflict(taskID: task.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Auto-Fix")
                    }
                }
                .buttonStyle(.chronaFilledRow(.warning))

                scheduleButton
                deleteButton
            } else {
                switch task.status {
                case .notStarted:
                    Button {
                        store.start(taskID: task.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Start")
                        }
                    }
                    .buttonStyle(.chronaFilledRow(.primary))

                    scheduleButton
                    deleteButton
                case .inProgress:
                    Button {
                        store.pause(taskID: task.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Pause")
                        }
                    }
                    .buttonStyle(.chronaOutlineRow(accent: .primary))

                    Button {
                        store.complete(taskID: task.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Complete")
                        }
                    }
                    .buttonStyle(.chronaFilledRow(.primary))

                    scheduleButton
                    deleteButton
                case .paused:
                    Button {
                        store.resume(taskID: task.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Resume")
                        }
                    }
                    .buttonStyle(.chronaOutlineRow(accent: .warning))

                    Button {
                        store.complete(taskID: task.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Complete")
                        }
                    }
                    .buttonStyle(.chronaFilledRow(.warning))

                    scheduleButton
                    deleteButton
                case .completed:
                    deleteButton
                }
            }
        }
    }

    private var scheduleButton: some View {
        Button {
            // 设计稿占位：日历/排期入口（图标语义对齐 Figma「带时钟的日历」）
        } label: {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 12, weight: .medium))
        }
        .buttonStyle(.chronaIconBorder)
        .accessibilityLabel("Schedule")
        .help("Schedule")
    }

    private var deleteButton: some View {
        Button {
            store.cancel(taskID: task.id)
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .medium))
        }
        .buttonStyle(.chronaIconBorder)
        .accessibilityLabel("Delete")
        .help("Delete this task")
    }
}
