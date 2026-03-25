import SwiftUI

struct TodaySummaryView: View {
    @EnvironmentObject private var chronaStore: ChronaStore

    private static let subtitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.timeZone = TimeZone.current
        f.dateFormat = "EEE, MMM d, yyyy"
        return f
    }()

    private var subtitleText: String {
        Self.subtitleFormatter.string(from: chronaStore.selectedDate)
    }

    private var refreshDisabled: Bool {
        switch chronaStore.todaySummaryState {
        case .generating, .streaming, .loadingSavedSummary:
            return true
        default:
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            contentHeader
                .padding(.horizontal, ChronaTokens.Page.gutter)
                .padding(.top, ChronaTokens.Space.md)
                .padding(.bottom, ChronaTokens.Space.sm)

            Divider()
                .background(ChronaTokens.Colors.borderHairline)

            ScrollView {
                VStack(alignment: .leading, spacing: ChronaTokens.Space.sm) {
                    if chronaStore.todaySummaryContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(placeholderText)
                            .font(ChronaTokens.Typography.body)
                            .foregroundStyle(ChronaTokens.Colors.subtext)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(chronaStore.todaySummaryContent)
                            .font(ChronaTokens.Typography.body)
                            .foregroundStyle(ChronaTokens.Colors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(ChronaTokens.Page.gutter)
            }

            statusArea
                .padding(.horizontal, ChronaTokens.Page.gutter)
                .padding(.bottom, ChronaTokens.Space.md)
        }
        .background(ChronaTokens.Colors.canvas)
    }

    private var contentHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: ChronaTokens.Space.xs) {
                Text("Today Summary")
                    .font(ChronaTokens.Typography.cardTitle)
                    .foregroundStyle(ChronaTokens.Colors.text)

                Text(subtitleText)
                    .font(ChronaTokens.Typography.caption)
                    .foregroundStyle(ChronaTokens.Colors.subtext)
            }

            Spacer(minLength: 0)

            Button {
                chronaStore.refreshTodaySummary()
            } label: {
                Text("Refresh")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(refreshDisabled ? ChronaTokens.Colors.subtext : ChronaTokens.Colors.text)
            }
            .buttonStyle(.plain)
            .disabled(refreshDisabled)
        }
    }

    private var placeholderText: String {
        switch chronaStore.todaySummaryState {
        case .idle:
            return "Click Summary to generate today summary."
        case .loadingSavedSummary:
            return "Loading saved summary…"
        case .generating:
            return "AI thinking…"
        case .streaming:
            return "Streaming…"
        case .success:
            return "Summary is ready."
        case .failure(let message):
            return message
        }
    }

    private var statusArea: some View {
        Group {
            switch chronaStore.todaySummaryState {
            case .idle:
                EmptyView()
            case .loadingSavedSummary:
                HStack(spacing: ChronaTokens.Space.sm) {
                    ProgressView()
                        .scaleEffect(0.7, anchor: .center)
                    Text("Loading saved summary…")
                        .font(ChronaTokens.Typography.caption)
                        .foregroundStyle(ChronaTokens.Colors.subtext)
                }
            case .generating:
                HStack(spacing: ChronaTokens.Space.sm) {
                    ProgressView()
                        .scaleEffect(0.7, anchor: .center)
                    Text("AI thinking…")
                        .font(ChronaTokens.Typography.caption)
                        .foregroundStyle(ChronaTokens.Colors.subtext)
                }
            case .streaming:
                HStack(spacing: ChronaTokens.Space.sm) {
                    ProgressView()
                        .scaleEffect(0.7, anchor: .center)
                    Text("Streaming…")
                        .font(ChronaTokens.Typography.caption)
                        .foregroundStyle(ChronaTokens.Colors.primary)
                }
            case .success:
                HStack(spacing: ChronaTokens.Space.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ChronaTokens.Colors.success)
                    Text("Saved.")
                        .font(ChronaTokens.Typography.caption)
                        .foregroundStyle(ChronaTokens.Colors.success)
                }
            case .failure(let message):
                HStack(spacing: ChronaTokens.Space.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ChronaTokens.Colors.warning)
                    Text(message)
                        .font(ChronaTokens.Typography.caption)
                        .foregroundStyle(ChronaTokens.Colors.warning)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

