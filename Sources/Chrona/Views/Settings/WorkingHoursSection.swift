import SwiftUI

struct WorkingHoursSection: View {
    @ObservedObject var store: ChronaSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: ChronaTokens.Space.lg + ChronaTokens.Space.xs) {
            sectionHeader

            VStack(alignment: .leading, spacing: ChronaTokens.Space.md) {
                ForEach(Array(store.timeRanges.enumerated()), id: \.element.id) { _, range in
                    timeRangeRow(range)
                }

                Button {
                    store.addTimeRange()
                } label: {
                    Text("+ Add time range")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(ChronaTokens.Colors.primary)
                .padding(.top, ChronaTokens.Space.xs)
            }
        }
        .padding(21)
        .background {
            RoundedRectangle(cornerRadius: ChronaTokens.Radius.lg, style: .continuous)
                .fill(ChronaTokens.Colors.bg)
        }
        .overlay {
            RoundedRectangle(cornerRadius: ChronaTokens.Radius.lg, style: .continuous)
                .strokeBorder(ChronaTokens.Colors.border.opacity(0.35), lineWidth: ChronaTokens.Surface.strokeWidth)
        }
        .shadow(
            color: ChronaTokens.Elevation.cardShadowColor,
            radius: ChronaTokens.Elevation.cardShadowRadius,
            x: 0,
            y: ChronaTokens.Elevation.cardShadowY
        )
    }

    private var sectionHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: ChronaSettingsPane.workingHours.systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ChronaTokens.Colors.subtext)
            Text("Working Hours")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ChronaTokens.Colors.text)
        }
    }

    private func timeRangeRow(_ range: ChronaWorkingTimeRange) -> some View {
        HStack(spacing: ChronaTokens.Space.sm) {
            DatePicker(
                "",
                selection: startBinding(for: range.id),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .fixedSize()

            Text("–")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ChronaTokens.Colors.subtext)

            DatePicker(
                "",
                selection: endBinding(for: range.id),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .fixedSize()

            Spacer(minLength: 0)

            Button {
                store.removeTimeRange(id: range.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ChronaTokens.Colors.subtext)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.chronaIconBorder)
            .help("Remove time range")
        }
    }

    private func startBinding(for id: ChronaWorkingTimeRange.ID) -> Binding<Date> {
        Binding(
            get: {
                store.timeRanges.first(where: { $0.id == id })?.start ?? Date()
            },
            set: { store.replaceTimeRange(id: id, start: $0) }
        )
    }

    private func endBinding(for id: ChronaWorkingTimeRange.ID) -> Binding<Date> {
        Binding(
            get: {
                store.timeRanges.first(where: { $0.id == id })?.end ?? Date()
            },
            set: { store.replaceTimeRange(id: id, end: $0) }
        )
    }
}
