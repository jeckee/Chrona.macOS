import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var chronaStore: ChronaStore

    var body: some View {
        // 分割条左右行程：`sidebarMinWidth`…`sidebarMaxWidth` 与 `detailMinWidth` 共同约束（见 ChronaTokens.Layout）。
        HSplitView {
            TaskListSidebar()
                .frame(
                    minWidth: ChronaTokens.Layout.sidebarMinWidth,
                    idealWidth: ChronaTokens.Layout.sidebarIdealWidth,
                    maxWidth: ChronaTokens.Layout.sidebarMaxWidth
                )

            detailColumn
                .frame(minWidth: ChronaTokens.Layout.detailMinWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var detailColumn: some View {
        VStack(spacing: 0) {
            ChronaDetailTopBar()
            detailPane
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if chronaStore.isShowingTodaySummary {
            TodaySummaryView()
        } else if let id = chronaStore.selection, chronaStore.tasks.contains(where: { $0.id == id }) {
            TaskDetailView(task: chronaStore.binding(for: id))
                .id(id)
        } else {
            VStack(spacing: ChronaTokens.Space.xs) {
                Image(systemName: "checklist")
                    .font(ChronaTokens.Typography.emptyStateSymbol)
                    .foregroundStyle(ChronaTokens.Colors.subtext)
                Text("No task selected")
                    .font(ChronaTokens.Typography.title)
                    .foregroundStyle(ChronaTokens.Colors.text)
                Text("Pick a task in the list to see details.")
                    .font(ChronaTokens.Typography.caption)
                    .foregroundStyle(ChronaTokens.Colors.subtext)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(ChronaTokens.Page.gutter)
        }
    }
}
