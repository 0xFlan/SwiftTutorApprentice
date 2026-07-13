import Foundation

enum PresentationValidationIssue: Equatable {
    case blankPresentationID
    case blankSceneID(sceneIndex: Int)
    case duplicateSceneID(String)
    case blankCodeTokenID(sceneID: String)
    case duplicateCodeTokenID(sceneID: String, id: String)
    case blankValueID(sceneID: String)
    case duplicateValueID(sceneID: String, id: String)
    case blankClaimID(claimIndex: Int)
    case duplicateClaimID(String)
    case invalidSceneCount(Int)
    case blankCaption(sceneID: String)
    case blankNarration(sceneID: String)
    case blankStaticDescription(sceneID: String)
    case sceneDoesNotChangeState(sceneID: String)
    case transcriptMissingNarration(sceneID: String)
    case transcriptNarrationOutOfOrder(sceneID: String)
    case unknownFinalRecallQuestionID(String)
    case missingAICodeExercise
    case blankFocusTargetID(sceneID: String, kind: PresentationFocusKind)
    case duplicateFocusTarget(sceneID: String, kind: PresentationFocusKind, id: String)
    case unresolvedCodeTokenFocus(sceneID: String, id: String)
    case unresolvedValueFocus(sceneID: String, id: String)
    case unresolvedOutputFocus(sceneID: String, id: String)
    case codeTokenTextMismatch(sceneID: String, state: PresentationStatePosition)
    case blankConceptID(index: Int)
    case duplicateConceptID(String)
    case unknownExerciseConceptID(String)
    case unknownMappingConceptID(String)
    case objectiveMappingsRequireActiveSet
    case wrongObjectiveSet(expected: ObjectiveSetID, actual: ObjectiveSetID)
    case unknownObjectiveID(setID: ObjectiveSetID, objectiveID: ObjectiveID)
    case blankPosterDescription
    case blankVisualStateDescription(locationID: String, state: PresentationStatePosition)
}

enum PresentationStatePosition: Equatable {
    case poster
    case before
    case after
}

enum PresentationContentValidator {
    static func validate(
        _ presentation: LessonPresentation,
        lesson: Lesson,
        course: CourseDefinition,
        knownObjectivesBySet: [ObjectiveSetID: Set<ObjectiveID>]
    ) -> [PresentationValidationIssue] {
        var issues: [PresentationValidationIssue] = []

        if isBlank(presentation.id) {
            issues.append(.blankPresentationID)
        }
        if !(3...6).contains(presentation.scenes.count) {
            issues.append(.invalidSceneCount(presentation.scenes.count))
        }

        appendBlankAndDuplicateSceneIssues(presentation.scenes, to: &issues)
        appendStateIdentityIssues(presentation.posterState, locationID: "poster", to: &issues)
        for scene in presentation.scenes {
            appendStateIdentityIssues(scene.before, locationID: scene.id, to: &issues)
            appendStateIdentityIssues(scene.after, locationID: scene.id, to: &issues)
        }
        appendClaimIdentityIssues(presentation.aiCodeExercise?.claims ?? [], to: &issues)
        appendProseAndStateIssues(presentation, to: &issues)
        appendLinkedActivityIssues(presentation, lesson: lesson, course: course, to: &issues)
        appendFocusTargetIssues(presentation.scenes, to: &issues)
        appendMappingIssues(
            presentation,
            course: course,
            knownObjectivesBySet: knownObjectivesBySet,
            to: &issues
        )

        return issues
    }

    private static func appendMappingIssues(
        _ presentation: LessonPresentation,
        course: CourseDefinition,
        knownObjectivesBySet: [ObjectiveSetID: Set<ObjectiveID>],
        to issues: inout [PresentationValidationIssue]
    ) {
        var conceptIDs: Set<ConceptID> = []
        for (index, conceptID) in presentation.conceptIDs.enumerated() {
            if isBlank(conceptID.rawValue) {
                issues.append(.blankConceptID(index: index))
            } else if !conceptIDs.insert(conceptID).inserted {
                issues.append(.duplicateConceptID(conceptID.rawValue))
            }
        }

        for conceptID in presentation.aiCodeExercise?.conceptIDs ?? []
        where !conceptIDs.contains(conceptID) {
            issues.append(.unknownExerciseConceptID(conceptID.rawValue))
        }

        for mapping in presentation.objectiveMappings
        where !conceptIDs.contains(mapping.conceptID) {
            issues.append(.unknownMappingConceptID(mapping.conceptID.rawValue))
        }

        guard let activeSetID = course.activeObjectiveSetID else {
            if !presentation.objectiveMappings.isEmpty {
                issues.append(.objectiveMappingsRequireActiveSet)
            }
            return
        }

        for mapping in presentation.objectiveMappings {
            guard mapping.objectiveSetID == activeSetID else {
                issues.append(
                    .wrongObjectiveSet(
                        expected: activeSetID,
                        actual: mapping.objectiveSetID
                    )
                )
                continue
            }
            if !(knownObjectivesBySet[activeSetID]?.contains(mapping.objectiveID) ?? false) {
                issues.append(
                    .unknownObjectiveID(
                        setID: activeSetID,
                        objectiveID: mapping.objectiveID
                    )
                )
            }
        }
    }

    private static func appendFocusTargetIssues(
        _ scenes: [PresentationScene],
        to issues: inout [PresentationValidationIssue]
    ) {
        for scene in scenes {
            var seenFocusTargets: Set<String> = []
            let tokenIDs = Set((scene.before.codeTokens + scene.after.codeTokens).map(\.id))
            let valueIDs = Set((scene.before.values + scene.after.values).map(\.id))
            let outputIDs = Set([scene.before.outputTargetID, scene.after.outputTargetID].compactMap { $0 })

            for target in scene.focusTargets {
                if isBlank(target.id) {
                    issues.append(.blankFocusTargetID(sceneID: scene.id, kind: target.kind))
                    continue
                }

                let identity = "\(target.kind.rawValue)\u{0}\(target.id)"
                if !seenFocusTargets.insert(identity).inserted {
                    issues.append(.duplicateFocusTarget(sceneID: scene.id, kind: target.kind, id: target.id))
                }

                switch target.kind {
                case .codeToken where !tokenIDs.contains(target.id):
                    issues.append(.unresolvedCodeTokenFocus(sceneID: scene.id, id: target.id))
                case .value where !valueIDs.contains(target.id):
                    issues.append(.unresolvedValueFocus(sceneID: scene.id, id: target.id))
                case .output where !outputIDs.contains(target.id):
                    issues.append(.unresolvedOutputFocus(sceneID: scene.id, id: target.id))
                default:
                    break
                }
            }

            appendCodeTokenEqualityIssue(scene.before, sceneID: scene.id, position: .before, to: &issues)
            appendCodeTokenEqualityIssue(scene.after, sceneID: scene.id, position: .after, to: &issues)
        }
    }

    private static func appendCodeTokenEqualityIssue(
        _ state: PresentationVisualState,
        sceneID: String,
        position: PresentationStatePosition,
        to issues: inout [PresentationValidationIssue]
    ) {
        guard state.code != nil || !state.codeTokens.isEmpty else { return }
        let joinedTokenText = state.codeTokens.map(\.text).joined()
        if state.code != joinedTokenText {
            issues.append(.codeTokenTextMismatch(sceneID: sceneID, state: position))
        }
    }

    private static func appendLinkedActivityIssues(
        _ presentation: LessonPresentation,
        lesson: Lesson,
        course: CourseDefinition,
        to issues: inout [PresentationValidationIssue]
    ) {
        let recallIDs = Set(lesson.deepContent?.recallQuestions.map(\.id) ?? [])
        if !recallIDs.contains(presentation.finalRecallQuestionID) {
            issues.append(.unknownFinalRecallQuestionID(presentation.finalRecallQuestionID))
        }
        if course.releaseLevel == .pilot, presentation.aiCodeExercise == nil {
            issues.append(.missingAICodeExercise)
        }
    }

    private static func appendProseAndStateIssues(
        _ presentation: LessonPresentation,
        to issues: inout [PresentationValidationIssue]
    ) {
        if isBlank(presentation.posterDescription) {
            issues.append(.blankPosterDescription)
        }
        if isBlank(presentation.posterState.description) {
            issues.append(.blankVisualStateDescription(locationID: "poster", state: .poster))
        }
        for scene in presentation.scenes {
            if isBlank(scene.caption) {
                issues.append(.blankCaption(sceneID: scene.id))
            }
            if isBlank(scene.narration) {
                issues.append(.blankNarration(sceneID: scene.id))
            }
            if isBlank(scene.staticDescription) {
                issues.append(.blankStaticDescription(sceneID: scene.id))
            }
            if scene.before == scene.after {
                issues.append(.sceneDoesNotChangeState(sceneID: scene.id))
            }
            if isBlank(scene.before.description) {
                issues.append(.blankVisualStateDescription(locationID: scene.id, state: .before))
            }
            if isBlank(scene.after.description) {
                issues.append(.blankVisualStateDescription(locationID: scene.id, state: .after))
            }
        }

        var searchStart = presentation.transcript.startIndex
        for scene in presentation.scenes where !isBlank(scene.narration) {
            let remaining = searchStart..<presentation.transcript.endIndex
            if let range = presentation.transcript.range(of: scene.narration, range: remaining) {
                searchStart = range.upperBound
            } else if presentation.transcript.contains(scene.narration) {
                issues.append(.transcriptNarrationOutOfOrder(sceneID: scene.id))
            } else {
                issues.append(.transcriptMissingNarration(sceneID: scene.id))
            }
        }
    }

    private static func appendBlankAndDuplicateSceneIssues(
        _ scenes: [PresentationScene],
        to issues: inout [PresentationValidationIssue]
    ) {
        var seen: Set<String> = []
        for (index, scene) in scenes.enumerated() {
            if isBlank(scene.id) {
                issues.append(.blankSceneID(sceneIndex: index))
            } else if !seen.insert(scene.id).inserted {
                issues.append(.duplicateSceneID(scene.id))
            }
        }
    }

    private static func appendStateIdentityIssues(
        _ state: PresentationVisualState,
        locationID: String,
        to issues: inout [PresentationValidationIssue]
    ) {
        var tokenIDs: Set<String> = []
        for token in state.codeTokens {
            if isBlank(token.id) {
                issues.append(.blankCodeTokenID(sceneID: locationID))
            } else if !tokenIDs.insert(token.id).inserted {
                issues.append(.duplicateCodeTokenID(sceneID: locationID, id: token.id))
            }
        }

        var valueIDs: Set<String> = []
        for value in state.values {
            if isBlank(value.id) {
                issues.append(.blankValueID(sceneID: locationID))
            } else if !valueIDs.insert(value.id).inserted {
                issues.append(.duplicateValueID(sceneID: locationID, id: value.id))
            }
        }
    }

    private static func appendClaimIdentityIssues(
        _ claims: [AICodeClaim],
        to issues: inout [PresentationValidationIssue]
    ) {
        var seen: Set<String> = []
        for (index, claim) in claims.enumerated() {
            if isBlank(claim.id) {
                issues.append(.blankClaimID(claimIndex: index))
            } else if !seen.insert(claim.id).inserted {
                issues.append(.duplicateClaimID(claim.id))
            }
        }
    }

    private static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
