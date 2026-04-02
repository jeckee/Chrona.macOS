import SwiftUI

struct TaskListRow: View {
    @EnvironmentObject private var chronaStore: ChronaStore
    let task: ChronaTask
    var scheduleBlock: ScheduleBlock?

    private var bucket: TaskBucket {
        chronaStore.sidebarBucket(for: task)
    }

    private var canSchedule: Bool { chronaStore.canScheduleTask }
    private var canDelete: Bool { chronaStore.canDeleteTask }
    private var canChangeStatus: Bool { chronaStore.canChangeTaskStatus }


    private var scheduledStart: Date? { scheduleBlock?.startAt }
    private var scheduledEnd: Date? { scheduleBlock?.endAt }

    private var rowDurationMinutes: Int {
        if let b = scheduleBlock {
            max(1, b.durationMinutes)
        } else if let est = task.estimatedMinutes {
            est
        } else {
            30
        }
    }

    private var isConflict: Bool { false }

    private var isSelected: Bool {
        chronaStore.selection == task.id
    }

    private var hasMetaLines: Bool {
        bucket == .scheduled
            || (bucket == .unscheduled && task.estimatedMinutes != nil)
            || isConflict
    }

    private var showsActionRow: Bool {
        true
    }

    private var cardRadius: CGFloat {
        bucket == .unscheduled ? ChronaTokens.Radius.lg : ChronaTokens.Surface.cornerRadius
    }

    private var titleColor: Color {
        if bucket == .scheduled {
            if isConflict { return ChronaTokens.Colors.warning }
            if task.status == .inProgress { return ChronaTokens.Colors.primary }
            if task.status == .paused { return ChronaTokens.Colors.warning }
        }
        if bucket == .unscheduled {
            if task.status == .inProgress { return ChronaTokens.Colors.primary }
            if task.status == .paused { return ChronaTokens.Colors.warning }
        }
        if bucket == .completed {
            return ChronaTokens.Colors.subtext
        }
        return ChronaTokens.Colors.text
    }

    private var rowBackground: Color {
        if bucket == .unscheduled {
            if task.status == .inProgress { return ChronaTokens.Colors.primaryCardTint }
            if task.status == .paused { return ChronaTokens.Colors.warningSoft }
            return ChronaTokens.Colors.bg
        }
        if isConflict { return ChronaTokens.Colors.warningSoft }
        if task.status == .inProgress { return ChronaTokens.Colors.primaryCardTint }
        if task.status == .paused { return ChronaTokens.Colors.warningSoft }
        return ChronaTokens.Colors.bg
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if bucket == .scheduled {
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
            .padding(.leading, bucket == .scheduled ? 12 : 4)
            .padding(.trailing, ChronaTokens.Space.lg)
            .padding(.vertical, ChronaTokens.Space.lg)
        }
        .background {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(rowBackground)
        }
        // 描边仅作装饰；参与命中会盖住行内按钮，导致 List 中「开始」等无法点击（尤其 Unscheduled 虚线框）。
        .overlay {
            Group {
                if bucket == .unscheduled {
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .strokeBorder(
                            isSelected ? ChronaTokens.Colors.selectionStroke : ChronaTokens.Colors.border,
                            style: StrokeStyle(
                                lineWidth: isSelected
                                    ? ChronaTokens.Surface.selectionRingWidth
                                    : ChronaTokens.Surface.strokeWidth,
                                dash: [6, 4]
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .strokeBorder(
                            isSelected ? ChronaTokens.Colors.selectionStroke : ChronaTokens.Colors.border.opacity(0.35),
                            lineWidth: isSelected
                                ? ChronaTokens.Surface.selectionRingWidth
                                : ChronaTokens.Surface.strokeWidth
                        )
                }
            }
            .allowsHitTesting(false)
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
        if isConflict { return ChronaTokens.Colors.warning }
        if task.status == .inProgress { return ChronaTokens.Colors.primary }
        if task.status == .paused { return ChronaTokens.Colors.warning }
        return ChronaTokens.Colors.subtext
    }

    @ViewBuilder
    private var metaLines: some View {
        if bucket == .scheduled {
            HStack(spacing: ChronaTokens.Space.lg) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(metaTint.opacity(0.85))
                    Text(ChronaFormatters.timeRange(start: scheduledStart, end: scheduledEnd))
                        .font(.system(size: ChronaTokens.Typography.Size.caption, weight: .medium))
                        .foregroundStyle(metaTint.opacity(0.85))
                }
                if isConflict {
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
                        Text(ChronaFormatters.durationString(minutes: rowDurationMinutes))
                            .font(.system(size: ChronaTokens.Typography.Size.caption, weight: .regular))
                            .foregroundStyle(metaTint.opacity(0.85))
                    }
                }
            }
        } else if bucket == .unscheduled, let est = task.estimatedMinutes {
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
        if isConflict { return ChronaTokens.Colors.warning }
        if task.status == .inProgress { return ChronaTokens.Colors.primary }
        if task.status == .paused { return ChronaTokens.Colors.warning }
        return ChronaTokens.Colors.border
    }

    @ViewBuilder
    private var statusTag: some View {
        switch task.status {
        case .inProgress:
            ChronaChip(text: ChronaTaskStatus.inProgress.displayName, style: .primaryFilled)
        case .paused:
            ChronaChip(text: ChronaTaskStatus.paused.displayName, style: .warningFilled)
        case .todo:
            if isConflict {
                ChronaChip(
                    text: "Conflict",
                    systemImage: "exclamationmark.triangle.fill",
                    style: .warningFilled
                )
            } else {
                ChronaChip(text: ChronaTaskStatus.todo.displayName, style: .neutralPill)
            }
        case .done:
            ChronaChip(
                text: ChronaTaskStatus.done.displayName,
                systemImage: "checkmark.seal.fill",
                style: .primaryFilled
            )
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: ChronaTokens.Space.sm) {
            if bucket == .completed {
                if canChangeStatus { reopenAsTodoButton }
                if canDelete { deleteButton }
            } else if bucket == .unscheduled {
                if canSchedule { scheduleButton }
                if canDelete { deleteButton }
            } else if isConflict {
                if canChangeStatus {
                    Button {
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Resume")
                        }
                    }
                    .buttonStyle(.chronaOutlineRow(accent: .warning))

                    Button {
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Auto-Fix")
                        }
                    }
                    .buttonStyle(.chronaFilledRow(.warning))
                }

                if canSchedule { scheduleButton }
                if canDelete { deleteButton }
            } else {
                if canChangeStatus { primaryStatusActions }
                if canSchedule { scheduleButton }
                if canDelete { deleteButton }
            }
        }
    }

    @ViewBuilder
    private var primaryStatusActions: some View {
        switch task.status {
        case .todo:
            Button {
                chronaStore.startTask(id: task.id)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Start")
                }
            }
            .buttonStyle(.chronaFilledRow(.primary))
        case .inProgress:
            Button {
                chronaStore.pauseTask(id: task.id)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Pause")
                }
            }
            .buttonStyle(.chronaOutlineRow(accent: .primary))

            Button {
                chronaStore.completeTask(id: task.id)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Complete")
                }
            }
            .buttonStyle(.chronaFilledRow(.primary))
        case .paused:
            Button {
                chronaStore.startTask(id: task.id)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Resume")
                }
            }
            .buttonStyle(.chronaOutlineRow(accent: .warning))

            Button {
                chronaStore.completeTask(id: task.id)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Complete")
                }
            }
            .buttonStyle(.chronaFilledRow(.warning))
        case .done:
            EmptyView()
        }
    }

    private var reopenAsTodoButton: some View {
        Button {
            chronaStore.resetTaskToTodo(id: task.id)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11, weight: .semibold))
                Text("Back to To-Do")
            }
        }
        .buttonStyle(.chronaOutlineRow(accent: .primary))
    }

    private var scheduleButton: some View {
        Button {
            guard canSchedule else { return }
            switch bucket {
            case .unscheduled:
                chronaStore.scheduleTaskWithDefaultSlot(id: task.id)
            case .scheduled:
                chronaStore.unscheduleTask(id: task.id)
            case .completed:
                break
            }
        } label: {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 12, weight: .medium))
        }
        .buttonStyle(.chronaIconBorder)
        .accessibilityLabel(bucket == .unscheduled ? "Add to schedule" : "Remove from schedule")
        .help(bucket == .unscheduled ? "Add to schedule" : "Remove from schedule")
    }

    private var deleteButton: some View {
        Button {
            guard canDelete else { return }
            chronaStore.deleteTask(id: task.id)
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .medium))
        }
        .buttonStyle(.chronaIconBorder)
        .accessibilityLabel("Delete")
        .help("Delete this task")
    }
}
