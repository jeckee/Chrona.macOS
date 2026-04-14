import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject private var chronaStore: ChronaStore
    @Binding var task: ChronaTask
    @StateObject private var noteController = NoteEditingController()
    @State private var conclusionDraft: String = ""
    @State private var isComposingConclusionText = false
    @State private var conclusionEditorHasVisibleContent = false
    @State private var isEditingTitle: Bool = false
    @State private var titleDraft: String = ""
    @State private var skipTitleCommitOnFocusLoss: Bool = false
    @FocusState private var isTitleFieldFocused: Bool

    private var detailScheduleBlock: ScheduleBlock? {
        chronaStore.scheduleBlock(forTaskId: task.id)
    }

    private var canEditConclusion: Bool {
        chronaStore.canEditConclusion
    }

    private var canEditTaskCoreFields: Bool {
        chronaStore.canEditTaskCoreFields
    }

    private var detailDurationMinutes: Int {
        if let b = detailScheduleBlock {
            max(1, b.durationMinutes)
        } else if let est = task.estimatedMinutes {
            est
        } else {
            30
        }
    }

    private var statusHeadline: String {
        task.status.displayName.uppercased()
    }

    private var priorityLine: String {
        task.priority.rawValue.capitalized
    }

    private var conclusionBinding: Binding<String> {
        Binding(
            get: { conclusionDraft },
            set: { conclusionDraft = $0 }
        )
    }

    private var hasConclusionText: Bool {
        !conclusionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func syncConclusionDraftFromTask() {
        conclusionDraft = task.conclusion ?? ""
        isComposingConclusionText = false
        conclusionEditorHasVisibleContent = !(task.conclusion ?? "").isEmpty
    }

    private func startTitleEditing() {
        guard canEditTaskCoreFields else { return }
        titleDraft = task.title
        skipTitleCommitOnFocusLoss = false
        isEditingTitle = true
        isTitleFieldFocused = true
    }

    private func cancelTitleEditing() {
        titleDraft = task.title
        skipTitleCommitOnFocusLoss = true
        isEditingTitle = false
        isTitleFieldFocused = false
    }

    private func commitTitleEditing() {
        guard isEditingTitle else { return }
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            titleDraft = task.title
        } else if trimmed != task.title {
            chronaStore.updateTaskTitle(id: task.id, title: trimmed)
            titleDraft = trimmed
        }
        isEditingTitle = false
    }

    private func commitConclusionIfNeeded() {
        guard canEditConclusion else { return }
        let trimmed = conclusionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue = trimmed.isEmpty ? nil : trimmed
        guard newValue != task.conclusion else { return }

        conclusionDraft = newValue ?? ""
        chronaStore.updateConclusion(id: task.id, conclusion: newValue)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                statusCapsule
                    .padding(.bottom, 12)

                titleSection
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
        .onAppear(perform: syncConclusionDraftFromTask)
        .onAppear {
            titleDraft = task.title
        }
        .onChange(of: task.id, perform: { _ in
            syncConclusionDraftFromTask()
            isEditingTitle = false
            titleDraft = task.title
        })
        .onChange(of: isTitleFieldFocused, perform: { focused in
            guard !focused, isEditingTitle else { return }
            if skipTitleCommitOnFocusLoss {
                skipTitleCommitOnFocusLoss = false
                return
            }
            commitTitleEditing()
        })
        .onDisappear(perform: commitConclusionIfNeeded)
    }

    @ViewBuilder
    private var titleSection: some View {
        if isEditingTitle {
            TextField("", text: $titleDraft)
                .textFieldStyle(.roundedBorder)
                .font(ChronaTokens.Typography.detailHero)
                .focused($isTitleFieldFocused)
                .onSubmit(commitTitleEditing)
                .onExitCommand(perform: cancelTitleEditing)
        } else {
            Text(task.title)
                .font(ChronaTokens.Typography.detailHero)
                .foregroundStyle(ChronaTokens.Colors.text)
                .tracking(-0.9)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture(perform: startTitleEditing)
                .help(canEditTaskCoreFields ? "Click to edit title" : "Past date is read-only")
        }
    }

    private var statusCapsule: some View {
        HStack(spacing: ChronaTokens.Space.sm) {
            Circle()
                .fill(statusCapsuleAccent)
                .frame(width: 8, height: 8)
            Text(statusHeadline)
                .font(.system(size: ChronaTokens.Typography.Size.caption, weight: .semibold))
                .foregroundStyle(statusCapsuleAccent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(statusCapsuleBackground)
        .clipShape(Capsule(style: .continuous))
    }

    private var statusCapsuleAccent: Color {
        switch task.status {
        case .todo: return ChronaTokens.Colors.subtext
        case .inProgress: return ChronaTokens.Colors.primary
        case .paused: return ChronaTokens.Colors.warning
        case .done: return ChronaTokens.Colors.success
        }
    }

    private var statusCapsuleBackground: Color {
        switch task.status {
        case .todo: return ChronaTokens.Colors.bgSoft
        case .inProgress: return ChronaTokens.Colors.primaryCardTint
        case .paused: return ChronaTokens.Colors.warningSoft
        case .done: return ChronaTokens.Colors.success.opacity(0.18)
        }
    }

    private var metaDividerRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: ChronaTokens.Space.lg) {
                durationMetaBlock

                Rectangle()
                    .fill(ChronaTokens.Colors.border)
                    .frame(width: 1, height: 32)

                priorityMetaBlock
            }
            .padding(.bottom, 25)

            Rectangle()
                .fill(ChronaTokens.Colors.borderHairline.opacity(1.2))
                .frame(height: ChronaTokens.Surface.strokeWidth)
        }
    }

    private var durationMetaBlock: some View {
        Menu {
            ForEach(TaskDurationOption.allCases) { option in
                Button(option.rawValue) {
                    chronaStore.updateTaskEstimatedMinutesWithScheduleAdjustment(id: task.id, minutes: option.minutes)
                }
            }
        } label: {
            metaPillBlock(
                systemImage: "clock",
                line1: ChronaFormatters.timeRange(
                    start: detailScheduleBlock?.startAt,
                    end: detailScheduleBlock?.endAt
                ),
                line2: "\(ChronaFormatters.durationString(minutes: detailDurationMinutes)) duration"
            )
        }
        .menuStyle(.borderlessButton)
        .disabled(!canEditTaskCoreFields)
        .help(canEditTaskCoreFields ? "Edit duration" : "Past date is read-only")
    }

    private var priorityMetaBlock: some View {
        Menu {
            ForEach(ChronaTaskPriority.allCases, id: \.self) { priority in
                Button(priority.rawValue.capitalized) {
                    chronaStore.updateTaskPriority(id: task.id, priority: priority)
                }
            }
        } label: {
            metaPillBlock(
                systemImage: "square.stack.3d.up.fill",
                line1: priorityLine,
                line2: "—"
            )
        }
        .menuStyle(.borderlessButton)
        .disabled(!canEditTaskCoreFields)
        .help(canEditTaskCoreFields ? "Edit priority" : "Past date is read-only")
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
                    if task.clues.isEmpty {
                        Text("• No AI suggestions yet.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(ChronaTokens.Colors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(task.clues) { clue in
                            Text("• \(clue.content)")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(ChronaTokens.Colors.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
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

                if !hasConclusionText && !conclusionEditorHasVisibleContent {
                    Text("Capture conclusions, thoughts, or blockers…")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(ChronaTokens.Colors.subtext)
                        .padding(.horizontal, 5 + ChronaTokens.Card.padding)
                        .padding(.vertical, 5 + ChronaTokens.Card.padding)
                        .allowsHitTesting(false)
                }

                AppKitTextEditor(
                    text: conclusionBinding,
                    controller: noteController,
                    isComposingText: $isComposingConclusionText,
                    editorHasVisibleContent: $conclusionEditorHasVisibleContent,
                    onCommit: commitConclusionIfNeeded
                )
                    .frame(minHeight: 128)
                    .padding(5)
                    .allowsHitTesting(canEditConclusion)
            }
        }
    }
}
