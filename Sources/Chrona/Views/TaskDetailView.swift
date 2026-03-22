import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject private var store: TaskStore
    @Binding var task: ChronaTask
    @StateObject private var noteController = NoteEditingController()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                statusCapsule
                    .padding(.bottom, 12)

                Text(task.title)
                    .font(ChronaTokens.Typography.detailHero)
                    .foregroundStyle(ChronaTokens.Colors.text)
                    .tracking(-0.9)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                metaDividerRow
                    .padding(.top, 16)

                aiSection
                    .padding(.top, 32)

                notesSection
                    .padding(.top, 36)
            }
            .frame(maxWidth: ChronaTokens.Page.detailContentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ChronaTokens.Page.detailHorizontalPadding)
            .padding(.vertical, ChronaTokens.Page.detailVerticalPadding)
        }
        .background(ChronaTokens.Colors.canvas)
    }

    private var statusCapsule: some View {
        HStack(spacing: ChronaTokens.Space.sm) {
            Circle()
                .fill(ChronaTokens.Colors.primary)
                .frame(width: 8, height: 8)
            Text(task.status.rawValue.uppercased())
                .font(.system(size: ChronaTokens.Typography.Size.caption, weight: .semibold))
                .foregroundStyle(ChronaTokens.Colors.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(ChronaTokens.Colors.primaryCardTint)
        .clipShape(Capsule(style: .continuous))
    }

    private var metaDividerRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: ChronaTokens.Space.lg) {
                metaPillBlock(
                    systemImage: "clock",
                    line1: ChronaFormatters.timeRange(start: task.scheduledStart, end: task.scheduledEnd),
                    line2: "\(ChronaFormatters.durationString(minutes: task.durationMinutes)) duration"
                )

                Rectangle()
                    .fill(ChronaTokens.Colors.border)
                    .frame(width: 1, height: 32)

                metaPillBlock(
                    systemImage: "square.stack.3d.up.fill",
                    line1: task.priority.rawValue,
                    line2: task.projectName
                )
            }
            .padding(.bottom, 25)

            Rectangle()
                .fill(ChronaTokens.Colors.borderHairline.opacity(1.2))
                .frame(height: ChronaTokens.Surface.strokeWidth)
        }
    }

    private func metaPillBlock(systemImage: String, line1: String, line2: String) -> some View {
        HStack(alignment: .center, spacing: ChronaTokens.Space.sm) {
            ZStack {
                Circle()
                    .fill(ChronaTokens.Colors.bg)
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ChronaTokens.Colors.text.opacity(0.85))
            }
            .frame(width: 32, height: 32)
            .overlay {
                Circle()
                    .strokeBorder(ChronaTokens.Colors.border, lineWidth: ChronaTokens.Surface.strokeWidth)
            }
            .shadow(color: ChronaTokens.Elevation.cardShadowColor, radius: 1, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(line1)
                    .font(ChronaTokens.Typography.metaEmphasis)
                    .foregroundStyle(ChronaTokens.Colors.text)
                Text(line2)
                    .font(ChronaTokens.Typography.metaSecondary)
                    .foregroundStyle(ChronaTokens.Colors.subtext)
            }
        }
    }

    private var aiSection: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: ChronaTokens.Radius.xl, style: .continuous)
                .fill(ChronaTokens.Gradients.aiSuggestionPanel)
                .overlay {
                    RoundedRectangle(cornerRadius: ChronaTokens.Radius.xl, style: .continuous)
                        .strokeBorder(ChronaTokens.Colors.aiCardBorder, lineWidth: ChronaTokens.Surface.strokeWidth)
                }
                .shadow(color: ChronaTokens.Elevation.cardShadowColor, radius: 1, x: 0, y: 1)

            Image(systemName: "wand.and.stars")
                .font(.system(size: 96, weight: .ultraLight))
                .foregroundStyle(ChronaTokens.Colors.primary.opacity(0.08))
                .rotationEffect(.degrees(12))
                .offset(x: 180, y: -48)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: ChronaTokens.Space.lg) {
                HStack(alignment: .firstTextBaseline, spacing: ChronaTokens.Space.sm) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ChronaTokens.Colors.primary)
                    Text("AI SUGGESTIONS")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(0.35)
                        .foregroundStyle(ChronaTokens.Colors.primary)
                }

                VStack(alignment: .leading, spacing: 11.5) {
                    ForEach(task.suggestedActions) { action in
                        let resolved = store.tasks.first(where: { $0.id == task.id })?
                            .suggestedActions.first(where: { $0.id == action.id })
                        let text = resolved?.text ?? action.text

                        Text("• \(text)")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(ChronaTokens.Colors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(25)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONCLUSION")
                .font(.system(size: 14, weight: .semibold))
                .tracking(0.35)
                .foregroundStyle(ChronaTokens.Colors.subtext)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: ChronaTokens.Radius.lg, style: .continuous)
                    .fill(ChronaTokens.Colors.bg)
                    .overlay {
                        RoundedRectangle(cornerRadius: ChronaTokens.Radius.lg, style: .continuous)
                            .strokeBorder(ChronaTokens.Colors.border, lineWidth: ChronaTokens.Surface.strokeWidth)
                    }
                    .shadow(color: ChronaTokens.Elevation.cardShadowColor, radius: 1, x: 0, y: 1)

                if task.notes.isEmpty {
                    Text("Capture conclusions, thoughts, or blockers…")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color(red: 156 / 255, green: 163 / 255, blue: 175 / 255))
                        .padding(.horizontal, 17)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }

                AppKitTextEditor(text: $task.notes, controller: noteController)
                    .frame(minHeight: 128)
                    .padding(5)
            }
        }
    }
}
