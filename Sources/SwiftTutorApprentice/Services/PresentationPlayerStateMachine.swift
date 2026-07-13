import Foundation

enum PresentationEntryMode: Equatable {
    case unavailable
    case expandedPoster
    case compactResume(sceneID: String)
    case compactSummary(status: PresentationStatus)
}

enum PresentationPlayerStateMachine {
    static func entryMode(
        presentation: LessonPresentation,
        savedState: LessonPresentationState?
    ) -> PresentationEntryMode {
        guard let firstSceneID = firstSceneID(in: presentation) else {
            return .unavailable
        }
        guard let savedState, savedState.status != .notStarted else {
            return .expandedPoster
        }
        guard presentationIdentityMatches(
            savedState: savedState,
            presentation: presentation
        ) else {
            return .expandedPoster
        }

        switch savedState.status {
        case .notStarted:
            return .expandedPoster
        case .started:
            if savedState.presentationRevision == presentation.provenance.revision,
               let savedSceneID = savedState.lastSceneID,
               presentation.scenes.contains(where: { $0.id == savedSceneID }) {
                return .compactResume(sceneID: savedSceneID)
            }
            return .compactResume(sceneID: firstSceneID)
        case .skipped:
            return .compactSummary(status: .skipped)
        case .completed:
            return .compactSummary(status: .completed)
        }
    }

    static func start(
        presentation: LessonPresentation,
        savedState: LessonPresentationState?,
        now: Date
    ) -> LessonPresentationState? {
        guard let firstSceneID = firstSceneID(in: presentation) else {
            return nil
        }
        let savedState = compatibleSavedState(
            savedState,
            for: presentation
        )
        return LessonPresentationState(
            status: .started,
            lastSceneID: firstSceneID,
            presentationRevision: presentation.provenance.revision,
            firstStartedAt: savedState?.firstStartedAt ?? now,
            lastOpenedAt: now,
            replayCount: normalizedReplayCount(savedState),
            presentationID: presentation.id
        )
    }

    static func next(
        presentation: LessonPresentation,
        savedState: LessonPresentationState?,
        now: Date
    ) -> LessonPresentationState? {
        guard var state = activeState(
            presentation: presentation,
            savedState: savedState,
            now: now
        ) else { return nil }
        let currentIndex = sceneIndex(for: state.lastSceneID, in: presentation) ?? 0
        let nextIndex = min(currentIndex + 1, presentation.scenes.count - 1)
        state.lastSceneID = presentation.scenes[nextIndex].id
        state.lastOpenedAt = now
        return state
    }

    static func back(
        presentation: LessonPresentation,
        savedState: LessonPresentationState?,
        now: Date
    ) -> LessonPresentationState? {
        guard var state = activeState(
            presentation: presentation,
            savedState: savedState,
            now: now
        ) else { return nil }
        let currentIndex = sceneIndex(for: state.lastSceneID, in: presentation) ?? 0
        let previousIndex = max(currentIndex - 1, 0)
        state.lastSceneID = presentation.scenes[previousIndex].id
        state.lastOpenedAt = now
        return state
    }

    static func skip(
        presentation: LessonPresentation,
        savedState: LessonPresentationState?,
        now: Date
    ) -> LessonPresentationState {
        LessonPresentationState(
            status: .skipped,
            lastSceneID: nil,
            presentationRevision: presentation.provenance.revision,
            firstStartedAt: compatibleSavedState(savedState, for: presentation)?.firstStartedAt,
            lastOpenedAt: now,
            replayCount: normalizedReplayCount(
                compatibleSavedState(savedState, for: presentation)
            ),
            presentationID: presentation.id
        )
    }

    static func replay(
        presentation: LessonPresentation,
        savedState: LessonPresentationState?,
        now: Date
    ) -> LessonPresentationState? {
        guard let firstSceneID = firstSceneID(in: presentation) else {
            return nil
        }
        let savedState = compatibleSavedState(
            savedState,
            for: presentation
        )
        return LessonPresentationState(
            status: .started,
            lastSceneID: firstSceneID,
            presentationRevision: presentation.provenance.revision,
            firstStartedAt: savedState?.firstStartedAt ?? now,
            lastOpenedAt: now,
            replayCount: incrementedReplayCount(savedState),
            presentationID: presentation.id
        )
    }

    static func complete(
        presentation: LessonPresentation,
        savedState: LessonPresentationState?,
        now: Date
    ) -> LessonPresentationState? {
        guard let finalSceneID = finalSceneID(in: presentation) else {
            return nil
        }
        let savedState = compatibleSavedState(
            savedState,
            for: presentation
        )
        return LessonPresentationState(
            status: .completed,
            lastSceneID: finalSceneID,
            presentationRevision: presentation.provenance.revision,
            firstStartedAt: savedState?.firstStartedAt,
            lastOpenedAt: now,
            replayCount: normalizedReplayCount(savedState),
            presentationID: presentation.id
        )
    }

    private static func activeState(
        presentation: LessonPresentation,
        savedState: LessonPresentationState?,
        now: Date
    ) -> LessonPresentationState? {
        guard let firstSceneID = firstSceneID(in: presentation) else {
            return nil
        }
        guard var state = savedState else {
            return start(presentation: presentation, savedState: nil, now: now)
        }
        if presentationIdentityMatches(
            savedState: state,
            presentation: presentation
        ) == false {
            return start(presentation: presentation, savedState: nil, now: now)
        }

        let revisionIsCurrent = state.presentationRevision
            == presentation.provenance.revision
        state.status = .started
        state.presentationRevision = presentation.provenance.revision
        state.firstStartedAt = state.firstStartedAt ?? now
        state.lastOpenedAt = now
        state.replayCount = normalizedReplayCount(state)
        state.presentationID = presentation.id
        if revisionIsCurrent == false
            || sceneIndex(for: state.lastSceneID, in: presentation) == nil {
            state.lastSceneID = firstSceneID
        }
        return state
    }

    private static func sceneIndex(
        for sceneID: String?,
        in presentation: LessonPresentation
    ) -> Int? {
        guard let sceneID else { return nil }
        return presentation.scenes.firstIndex { $0.id == sceneID }
    }

    private static func firstSceneID(in presentation: LessonPresentation) -> String? {
        presentation.scenes.first?.id
    }

    private static func finalSceneID(in presentation: LessonPresentation) -> String? {
        presentation.scenes.last?.id
    }

    private static func normalizedReplayCount(
        _ state: LessonPresentationState?
    ) -> Int {
        max(state?.replayCount ?? 0, 0)
    }

    private static func incrementedReplayCount(
        _ state: LessonPresentationState?
    ) -> Int {
        let replayCount = normalizedReplayCount(state)
        return replayCount == .max ? .max : replayCount + 1
    }

    private static func presentationIdentityMatches(
        savedState: LessonPresentationState,
        presentation: LessonPresentation
    ) -> Bool {
        savedState.presentationID == nil
            || savedState.presentationID == presentation.id
    }

    private static func compatibleSavedState(
        _ savedState: LessonPresentationState?,
        for presentation: LessonPresentation
    ) -> LessonPresentationState? {
        guard let savedState,
              presentationIdentityMatches(
                savedState: savedState,
                presentation: presentation
              ) else {
            return nil
        }
        return savedState
    }
}
