import SwiftUI

struct TaskListSidebar: View {
    @EnvironmentObject private var store: TaskStore
    @State private var quickAddText: String = ""
    @State private var completedExpanded: Bool = false
    @State private var summaryPresented: Bool = false
    @State private var dayOffset: Int = 0

    private var displayDate: Date {
        Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
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

            List(selection: $store.selection) {
                    Section {
                    ForEach(store.tasks(in: .scheduled)) { task in
                        TaskListRow(task: task)
                            .tag(Optional(task.id))
                            .listRowInsets(rowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(ChronaTokens.Colors.bg)
                            .chronaReorderable(in: .scheduled, task: task)
                    }
                    Color.clear
                        .frame(height: ChronaTokens.List.sectionBottomSpacerHeight)
                        .listRowInsets(ChronaTokens.List.zeroInsets)
                        .listRowSeparator(.hidden)
                        .dropDestination(for: String.self) { items, _ in
                            guard let s = items.first, let id = UUID(uuidString: s) else { return false }
                            store.reorderWithinBucket(.scheduled, draggingId: id, before: nil)
                            return true
                        } isTargeted: { _ in }
                    } header: {
                        ChronaSectionHeader(title: "Scheduled", count: store.tasks(in: .scheduled).count)
                        .textCase(nil)
                        .padding(.leading, ChronaTokens.List.sidebarScheduledSectionHeaderLeadingInset)
                        .padding(.top, ChronaTokens.Space.sm)
                        .padding(.bottom, ChronaTokens.List.sidebarSectionHeaderBottomPadding)
                    }

                    Section {
                        ForEach(store.tasks(in: .unscheduled)) { task in
                        TaskListRow(task: task)
                            .tag(Optional(task.id))
                            .listRowInsets(rowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(ChronaTokens.Colors.bg)
                            .chronaReorderable(in: .unscheduled, task: task)
                        }
                        Color.clear
                            .frame(height: ChronaTokens.List.sectionBottomSpacerHeight)
                            .listRowInsets(ChronaTokens.List.zeroInsets)
                            .listRowSeparator(.hidden)
                            .dropDestination(for: String.self) { items, _ in
                                guard let s = items.first, let id = UUID(uuidString: s) else { return false }
                                store.reorderWithinBucket(.unscheduled, draggingId: id, before: nil)
                                return true
                            } isTargeted: { _ in }
                    } header: {
                        ChronaSectionHeader(title: "Unscheduled", count: store.tasks(in: .unscheduled).count)
                            .textCase(nil)
                            .listSectionSeparator(.hidden, edges: .top)
                            .padding(.top, ChronaTokens.Space.md)
                            .padding(.bottom, ChronaTokens.List.sidebarSectionHeaderBottomPadding)
                    }

                    Section {
                        DisclosureGroup(isExpanded: $completedExpanded) {
                            ForEach(store.tasks(in: .completed)) { task in
                            TaskListRow(task: task)
                                .tag(Optional(task.id))
                                .listRowInsets(rowInsets)
                                .listRowSeparator(.hidden)
                                .listRowBackground(ChronaTokens.Colors.bg)
                                .chronaReorderable(in: .completed, task: task)
                            }
                            Color.clear
                                .frame(height: ChronaTokens.List.sectionBottomSpacerHeight)
                                .listRowInsets(ChronaTokens.List.zeroInsets)
                                .listRowSeparator(.hidden)
                                .dropDestination(for: String.self) { items, _ in
                                    guard let s = items.first, let id = UUID(uuidString: s) else { return false }
                                    store.reorderWithinBucket(.completed, draggingId: id, before: nil)
                                    return true
                                } isTargeted: { _ in }
                        } label: {
                            ChronaSectionHeader(
                                title: "Completed",
                                count: store.tasks(in: .completed).count,
                                countTint: ChronaTokens.Colors.success
                            )
                            .textCase(nil)
                        }
                        .tint(ChronaTokens.Colors.primary)
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
                FloatingTaskInputView(text: $quickAddText, onSubmit: submitQuickAdd)
                    .padding(.horizontal, ChronaTokens.Space.lg)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                    .background(ChronaTokens.Colors.bg)
            }
        }
        .background(ChronaTokens.Colors.bg)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(ChronaTokens.Colors.border)
                .frame(width: ChronaTokens.Surface.strokeWidth)
        }
        .popover(isPresented: $summaryPresented, arrowEdge: .top) {
            Text("Summary (demo): focus on scheduled work first, resolve conflicts early.")
                .font(ChronaTokens.Typography.caption)
                .foregroundStyle(ChronaTokens.Colors.text)
                .chronaCard(fill: ChronaTokens.Colors.bg)
                .frame(width: ChronaTokens.Layout.popoverWidth)
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
        HStack(alignment: .center, spacing: ChronaTokens.Space.md) {
            Button {
                dayOffset -= 1
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
                Text("Today")
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
                dayOffset += 1
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
                store.repackScheduledTimes()
            } label: {
                HStack(spacing: ChronaTokens.Space.sm) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .medium))
                    Text("Schedule")
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.chronaHeaderPairedSecondary)
            .disabled(store.tasks(in: .scheduled).isEmpty)
            .help("Repack scheduled tasks along today's timeline")

            Button {
                summaryPresented.toggle()
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
    }

    private func submitQuickAdd() {
        let raw = quickAddText
        quickAddText = ""
        store.addTaskFromQuickInput(raw)
    }
}
