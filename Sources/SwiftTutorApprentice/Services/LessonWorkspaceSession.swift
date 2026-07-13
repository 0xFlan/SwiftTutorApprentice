import Combine
import Foundation

struct LessonStagePresentation {
    let lessonKey: LessonKey
    let lesson: Lesson
    let content: LessonDeepContent
    let existingEditorCode: String
}

enum ActiveLessonStage: Identifiable {
    case deepLesson(LessonStagePresentation)
    case modify(LessonStagePresentation)

    var id: String {
        switch self {
        case .deepLesson(let presentation):
            return "deep-lesson-\(presentation.lessonKey.id)"
        case .modify(let presentation):
            return "modify-\(presentation.lessonKey.id)"
        }
    }
}

struct LessonRecallFocusRequest: Equatable {
    let lessonKey: LessonKey
    let generation: UInt64
    var scrollAcknowledged = false
    var focusAcknowledged = false
}

@MainActor
final class LessonWorkspaceSession: ObservableObject {
    @Published private(set) var controller: PresentationPlayerController?
    @Published var activeLessonStage: ActiveLessonStage?
    @Published private(set) var recallFocusGeneration: UInt64 = 0
    @Published private(set) var recallFocusRequest: LessonRecallFocusRequest?
    @Published private(set) var practiceFocusGeneration: UInt64 = 0
    @Published private(set) var playerExpansionGeneration: UInt64 = 0
    @Published private(set) var playerExpansionLessonKey: LessonKey?
    @Published private(set) var pendingAssessmentAttempt: AssessmentAttempt?

    private let now: () -> Date
    private let makeAttemptID: () -> AttemptID
    private let waitForAdvance: () async -> Void
    private let narrator: PresentationNarrating?
    private let defaultReduceMotion: () -> Bool
    private var currentReduceMotion: Bool?

    init(
        now: @escaping () -> Date = Date.init,
        makeAttemptID: @escaping () -> AttemptID = {
            AttemptID(rawValue: UUID().uuidString)
        },
        waitForAdvance: @escaping () async -> Void = {
            try? await Task.sleep(for: .seconds(2))
        },
        narrator: PresentationNarrating? = nil,
        reduceMotion: @escaping () -> Bool = { false }
    ) {
        self.now = now
        self.makeAttemptID = makeAttemptID
        self.waitForAdvance = waitForAdvance
        self.narrator = narrator
        self.defaultReduceMotion = reduceMotion
    }

    func updateReduceMotion(_ reduceMotion: Bool) {
        currentReduceMotion = reduceMotion
    }

    func activate(
        for lessonKey: LessonKey,
        presentation: LessonPresentation?,
        savedState: LessonPresentationState?,
        persist: @escaping (LessonKey, LessonPresentationState) -> Void
    ) {
        invalidateRecallFocusRequest()
        controller?.deactivate()
        activeLessonStage = nil
        pendingAssessmentAttempt = nil
        playerExpansionLessonKey = nil

        guard let presentation else {
            controller = nil
            return
        }

        controller = PresentationPlayerController(
            lessonKey: lessonKey,
            presentation: presentation,
            savedState: savedState,
            now: now,
            persist: persist,
            waitForAdvance: waitForAdvance,
            narrator: narrator,
            reduceMotion: { [weak self] in
                guard let self else { return false }
                return self.currentReduceMotion ?? self.defaultReduceMotion()
            }
        )
    }

    func cancel() {
        invalidateRecallFocusRequest()
        controller?.deactivate()
        controller = nil
        activeLessonStage = nil
        pendingAssessmentAttempt = nil
        playerExpansionLessonKey = nil
    }

    func requestRecallFocus(for lessonKey: LessonKey? = nil) {
        guard let lessonKey = lessonKey ?? controller?.lessonKey else { return }
        recallFocusGeneration &+= 1
        recallFocusRequest = LessonRecallFocusRequest(
            lessonKey: lessonKey,
            generation: recallFocusGeneration
        )
    }

    func activeRecallFocusGeneration(for lessonKey: LessonKey) -> UInt64 {
        guard recallFocusRequest?.lessonKey == lessonKey,
              recallFocusRequest?.focusAcknowledged == false
        else { return 0 }
        return recallFocusRequest?.generation ?? 0
    }

    func acknowledgeRecallScroll(
        generation: UInt64,
        lessonKey: LessonKey
    ) {
        updateRecallAcknowledgement(
            generation: generation,
            lessonKey: lessonKey,
            scroll: true
        )
    }

    func acknowledgeRecallFocus(
        generation: UInt64,
        lessonKey: LessonKey
    ) {
        updateRecallAcknowledgement(
            generation: generation,
            lessonKey: lessonKey,
            scroll: false
        )
    }

    private func updateRecallAcknowledgement(
        generation: UInt64,
        lessonKey: LessonKey,
        scroll: Bool
    ) {
        guard var request = recallFocusRequest,
              request.lessonKey == lessonKey,
              request.generation == generation
        else { return }
        if scroll {
            request.scrollAcknowledged = true
        } else {
            request.focusAcknowledged = true
        }
        recallFocusRequest = request.scrollAcknowledged && request.focusAcknowledged
            ? nil
            : request
    }

    private func invalidateRecallFocusRequest() {
        recallFocusRequest = nil
    }

    func openWatch() {
        guard let controller else { return }
        switch controller.entryMode {
        case .expandedPoster:
            controller.start()
        case .compactResume:
            break
        case .compactSummary:
            controller.replay()
        case .unavailable:
            return
        }
        playerExpansionGeneration &+= 1
        playerExpansionLessonKey = controller.lessonKey
    }

    func recordPlayerExpanded(for lessonKey: LessonKey) {
        guard controller?.lessonKey == lessonKey else { return }
        playerExpansionLessonKey = lessonKey
    }

    func continueAfterRecall(modify: LessonStagePresentation?) {
        if let modify {
            activeLessonStage = .modify(modify)
        } else {
            practiceFocusGeneration &+= 1
        }
    }

    func recordRecallAnswer(
        lessonKey: LessonKey,
        questionID: String,
        wasCorrect: Bool,
        progress: ProgressStore
    ) {
        progress.recordRecallAnswer(
            lessonKey: lessonKey,
            questionID: questionID,
            wasCorrect: wasCorrect
        )
    }

    func recordModifyPassed(
        _ presentation: LessonStagePresentation,
        progress: ProgressStore
    ) {
        progress.markModifyPassed(presentation.lessonKey)
    }

    func canReplaceEditor(
        for presentation: LessonStagePresentation,
        selectedLessonKey: LessonKey?
    ) -> Bool {
        selectedLessonKey == presentation.lessonKey
    }

    @discardableResult
    func submitAICodeReview(
        _ evaluation: AICodeReviewEvaluation,
        lessonKey: LessonKey,
        presentation: LessonPresentation,
        exercise: AICodeReviewExercise,
        progress: ProgressStore
    ) -> AssessmentAttempt? {
        guard case .complete(_, _, _, let passed) = evaluation else { return nil }

        let activityID = ActivityID(rawValue: exercise.id)
        let itemVariantID = ItemVariantID(rawValue: "\(exercise.id):default")
        let priorAttempts = progress.progress(for: lessonKey.courseID).assessmentAttempts
        let attempt = AssessmentAttempt(
            id: makeAttemptID(),
            lessonKey: lessonKey,
            activityID: activityID,
            itemVariantID: itemVariantID,
            conceptIDs: exercise.conceptIDs,
            objectiveMappings: presentation.objectiveMappings,
            scaffoldLevel: .none,
            result: passed ? .passed : .failed,
            contentRevision: presentation.provenance.revision,
            wasPreviouslySeen: priorAttempts.contains {
                $0.itemVariantID == itemVariantID
            },
            submittedAt: now()
        )

        pendingAssessmentAttempt = attempt
        progress.record(attempt)
        if progress.saveError == nil {
            pendingAssessmentAttempt = nil
        }
        return attempt
    }

    func retryPendingAssessmentSave(progress: ProgressStore) {
        guard pendingAssessmentAttempt != nil else { return }
        progress.retrySave()
        if progress.saveError == nil {
            pendingAssessmentAttempt = nil
        }
    }
}
