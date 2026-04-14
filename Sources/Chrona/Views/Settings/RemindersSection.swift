import SwiftUI

struct RemindersSection: View {
    @ObservedObject var store: ChronaSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: ChronaTokens.Space.lg + ChronaTokens.Space.xs) {
            sectionHeader

            VStack(alignment: .leading, spacing: ChronaTokens.Space.lg) {
                reminderRow(
                    isOn: $store.taskReminderEnabled,
                    title: "Task reminder",
                    subtitle: "Notify before next task",
                    leadSelection: $store.taskReminderLead
                )
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
            Image(systemName: ChronaSettingsPane.reminders.systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ChronaTokens.Colors.subtext)
            Text("Reminders")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ChronaTokens.Colors.text)
        }
    }

    private func reminderRow(
        isOn: Binding<Bool>,
        title: String,
        subtitle: String,
        leadSelection: Binding<ChronaTaskReminderLead>
    ) -> some View {
        HStack(alignment: .center, spacing: ChronaTokens.Space.md) {
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .help(title)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ChronaTokens.Typography.bodyMedium)
                    .foregroundStyle(ChronaTokens.Colors.text)
                Text(subtitle)
                    .font(ChronaTokens.Typography.caption)
                    .foregroundStyle(ChronaTokens.Colors.subtext)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: ChronaTokens.Space.sm) {
                Text("Before")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ChronaTokens.Colors.subtext)
                Picker("", selection: leadSelection) {
                    ForEach(ChronaTaskReminderLead.allCases) { lead in
                        Text(lead.rawValue.replacingOccurrences(of: "Before ", with: "")).tag(lead)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(minWidth: 100, alignment: .trailing)
            }
            .opacity(isOn.wrappedValue ? 1 : 0.45)
            .disabled(!isOn.wrappedValue)
        }
    }
}
