import SwiftUI

/// 设置窗口内布局：侧栏 + 内容区，铺满窗口（由系统窗口提供标题栏与阴影）。
struct ChronaSettingsWindowView: View {
    @ObservedObject var store: ChronaSettingsStore
    @EnvironmentObject private var chronaStore: ChronaStore

    private let contentMaxWidth: CGFloat = 576

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            SidebarView(selection: $store.selectedPane)

            ScrollView {
                VStack(alignment: .leading, spacing: ChronaTokens.Space.lg + ChronaTokens.Space.sm) {
                    switch store.selectedPane {
                    case .appearance:
                        AppearanceSection(store: store)
                    case .aiModel:
                        AIModelSection(store: store)
                    case .workingHours:
                        WorkingHoursSection(store: store)
                    case .reminders:
                        RemindersSection(store: store)
                    }
                }
                .frame(maxWidth: contentMaxWidth, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChronaTokens.Colors.canvas)
        .chronaSettingsWindowChrome()
        .onAppear {
            store.bind(chronaStore: chronaStore)
            store.reloadFromChronaStore()
        }
        .onDisappear {
            store.persistNowIfBound()
        }
    }
}
