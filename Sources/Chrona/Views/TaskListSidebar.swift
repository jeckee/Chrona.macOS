import SwiftUI

struct TaskListSidebar: View {
    @EnvironmentObject private var chronaStore: ChronaStore
    @State private var quickAddText: String = ""

    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "MMM d"
        return f
    }()

    private var displayDate: Date { chronaStore.selectedDate }

    private var headerPrimaryDateText: String {
        let cal = Calendar.current
        let now = Date()

        if cal.isDate(displayDate, inSameDayAs: now) { return "Today" }

        let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
        if cal.isDate(displayDate, inSameDayAs: yesterday) { return "Yesterday" }

        let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
        if cal.isDate(displayDate, inSameDayAs: tomorrow) { return "Tomorrow" }

        return Self.monthDayFormatter.string(from: displayDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, ChronaTokens.Page.sidebarGutter)
                .padding(.top, 20)
                .padding(.bottom, 21)
                .background(sidebarHeaderBackground)
                .overlay(alignment: .bottom) {
                    Divider()
                        .background(ChronaTokens.Colors.border)
                }

            List(selection: listSelectionBinding) {
                    Section {
                    ForEach(chronaStore.tasks(in: .scheduled)) { task in
                        TaskListRow(
                            task: task,
                            scheduleBlock: chronaStore.scheduleBlock(forTaskId: task.id)
                        )
                            .tag(Optional(task.id))
                            .listRowInsets(rowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(ChronaTokens.Colors.bg)
                    }
                    Color.clear
                        .frame(height: ChronaTokens.List.sectionBottomSpacerHeight)
                        .listRowInsets(ChronaTokens.List.zeroInsets)
                        .listRowSeparator(.hidden)
                    } header: {
                        ChronaSectionHeader(title: "Scheduled", count: chronaStore.tasks(in: .scheduled).count)
                        .textCase(nil)
                        .padding(.leading, ChronaTokens.List.sidebarScheduledSectionHeaderLeadingInset)
                        .padding(.top, ChronaTokens.Space.sm)
                        .padding(.bottom, ChronaTokens.List.sidebarSectionHeaderBottomPadding)
                    }

                    Section {
                        ForEach(chronaStore.tasks(in: .unscheduled)) { task in
                        TaskListRow(
                            task: task,
                            scheduleBlock: chronaStore.scheduleBlock(forTaskId: task.id)
                        )
                            .tag(Optional(task.id))
                            .listRowInsets(rowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(ChronaTokens.Colors.bg)
                        }
                        Color.clear
                            .frame(height: ChronaTokens.List.sectionBottomSpacerHeight)
                            .listRowInsets(ChronaTokens.List.zeroInsets)
                            .listRowSeparator(.hidden)
                    } header: {
                        ChronaSectionHeader(title: "Unscheduled", count: chronaStore.tasks(in: .unscheduled).count)
                            .textCase(nil)
                            .listSectionSeparator(.hidden, edges: .top)
                            .padding(.top, ChronaTokens.Space.md)
                            .padding(.bottom, ChronaTokens.List.sidebarSectionHeaderBottomPadding)
                    }

                    Section {
                        ForEach(chronaStore.tasks(in: .completed)) { task in
                        TaskListRow(
                            task: task,
                            scheduleBlock: chronaStore.scheduleBlock(forTaskId: task.id)
                        )
                            .tag(Optional(task.id))
                            .listRowInsets(rowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(ChronaTokens.Colors.bg)
                        }
                        Color.clear
                            .frame(height: ChronaTokens.List.sectionBottomSpacerHeight)
                            .listRowInsets(ChronaTokens.List.zeroInsets)
                            .listRowSeparator(.hidden)
                    } header: {
                        ChronaSectionHeader(
                            title: "Completed",
                            count: chronaStore.tasks(in: .completed).count,
                            countTint: ChronaTokens.Colors.success
                        )
                        .textCase(nil)
                    }
                }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.leading, ChronaTokens.Space.xs, for: .scrollContent)
            .environment(\.defaultMinListRowHeight, ChronaTokens.Layout.listMinimumRowHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 底部输入条用 safeAreaInset 参与布局；勿仅用 ZStack 叠在 List 上，否则列表仍占满整列，contentMargins(.bottom) 往往无法把最后一屏让出来。
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if chronaStore.canAddTask {
                    FloatingTaskInputView(text: $quickAddText, onSubmit: submitQuickAdd)
                        .padding(.horizontal, ChronaTokens.Space.lg)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity)
                        .background(ChronaTokens.Colors.bg)
                }
            }
        }
        .background(ChronaTokens.Colors.bg)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(ChronaTokens.Colors.border)
                .frame(width: ChronaTokens.Surface.strokeWidth)
        }
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(
            top: ChronaTokens.Space.sm,
            leading: ChronaTokens.List.sidebarTaskRowLeadingInset,
            bottom: ChronaTokens.Space.sm,
            trailing: ChronaTokens.Space.sm
        )
    }

    private var sidebarHeaderBackground: some View {
        ChronaTokens.Colors.bg.opacity(0.85)
            .background(.ultraThinMaterial)
    }

    private var header: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(alignment: .center, spacing: ChronaTokens.Space.md) {
                Button {
                    chronaStore.shiftSelectedDate(byDays: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ChronaTokens.Colors.text)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // 居中：避免 minWidth 内 leading 导致「Today」贴左、相对右箭头更近
                VStack(alignment: .center, spacing: 4) {
                    Text(headerPrimaryDateText)
                        .font(ChronaTokens.Typography.title)
                        .foregroundStyle(ChronaTokens.Colors.text)
                        .tracking(-0.6)
                    Text(ChronaFormatters.weekdayMonthDay.string(from: displayDate))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ChronaTokens.Colors.subtext)
                        .multilineTextAlignment(.center)
                }
                .frame(minWidth: ChronaTokens.Layout.sidebarHeaderDateBlockMinWidth)

                Button {
                    chronaStore.shiftSelectedDate(byDays: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ChronaTokens.Colors.text)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: ChronaTokens.Space.xs)

                Button {
                    Task {
                        await chronaStore.scheduleCurrentDay()
                    }
                } label: {
                    HStack(spacing: ChronaTokens.Space.sm) {
                        if chronaStore.isScheduling {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .medium))
                                .rotationEffect(.degrees(chronaStore.isScheduling ? 360 : 0))
                                .animation(
                                    .linear(duration: 0.9).repeatForever(autoreverses: false),
                                    value: chronaStore.isScheduling
                                )
                        } else {
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .medium))
                        }
                        Text("Schedule")
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.chronaHeaderPairedSecondary)
                .disabled(chronaStore.isScheduling)
                .help("Use one AI call to complete and schedule today's tasks")

                Button {
                    chronaStore.showTodaySummary()
                } label: {
                    HStack(spacing: ChronaTokens.Space.sm) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ChronaTokens.Colors.primary)
                        Text("Summary")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(ChronaTokens.Colors.primary)
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.chronaSummaryHeader)
            }

            if let text = scheduleFeedbackText {
                Text(text)
                    .font(ChronaTokens.Typography.caption)
                    .foregroundStyle(scheduleFeedbackColor)
                    .lineLimit(1)
            }

            if let text = chronaStore.carryOverToast {
                Text(text)
                    .font(ChronaTokens.Typography.caption)
                    .foregroundStyle(ChronaTokens.Colors.success)
                    .lineLimit(1)
            }
        }
    }

    private var scheduleFeedbackText: String? {
        switch chronaStore.scheduleExecutionState {
        case .idle:
            return nil
        case .scheduling:
            return "Scheduling..."
        case .success:
            return "Schedule updated."
        case .failure(let message):
            return message
        }
    }

    private var scheduleFeedbackColor: Color {
        switch chronaStore.scheduleExecutionState {
        case .failure:
            return ChronaTokens.Colors.warning
        case .success:
            return ChronaTokens.Colors.success
        case .idle, .scheduling:
            return ChronaTokens.Colors.subtext
        }
    }

    private var listSelectionBinding: Binding<UUID?> {
        Binding(
            get: { chronaStore.selection },
            set: { chronaStore.setSelection($0) }
        )
    }

    private func submitQuickAdd() {
        let trimmed = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        quickAddText = ""
        chronaStore.addTask(title: trimmed, note: nil)
    }
}
