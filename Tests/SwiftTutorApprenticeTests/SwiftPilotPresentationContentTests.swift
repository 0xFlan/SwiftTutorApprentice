import XCTest
@testable import SwiftTutorApprentice

final class SwiftPilotPresentationContentTests: XCTestCase {
    func testValidatorRejectsInvalidIdentityOrSceneCount() {
        let lesson = makeLesson()
        let course = makeCourse()

        assertValidationIssue(.blankPresentationID, in: makePresentation(id: " "), lesson: lesson, course: course)
        assertValidationIssue(.blankSceneID(sceneIndex: 0), in: makePresentation(sceneIDs: [" ", "scene-2", "scene-3"]), lesson: lesson, course: course)
        assertValidationIssue(.duplicateSceneID("scene-1"), in: makePresentation(sceneIDs: ["scene-1", "scene-1", "scene-3"]), lesson: lesson, course: course)
        assertValidationIssue(.blankCodeTokenID(sceneID: "scene-1"), in: makePresentation(tokenIDs: [" ", "token-2"]), lesson: lesson, course: course)
        assertValidationIssue(.duplicateCodeTokenID(sceneID: "scene-1", id: "token-1"), in: makePresentation(tokenIDs: ["token-1", "token-1"]), lesson: lesson, course: course)
        assertValidationIssue(.blankValueID(sceneID: "scene-1"), in: makePresentation(valueIDs: [" ", "value-2"]), lesson: lesson, course: course)
        assertValidationIssue(.duplicateValueID(sceneID: "scene-1", id: "value-1"), in: makePresentation(valueIDs: ["value-1", "value-1"]), lesson: lesson, course: course)
        assertValidationIssue(.blankClaimID(claimIndex: 0), in: makePresentation(claimIDs: [" ", "claim-2"]), lesson: lesson, course: course)
        assertValidationIssue(.duplicateClaimID("claim-1"), in: makePresentation(claimIDs: ["claim-1", "claim-1"]), lesson: lesson, course: course)
        assertValidationIssue(.invalidSceneCount(2), in: makePresentation(sceneIDs: ["scene-1", "scene-2"]), lesson: lesson, course: course)
        assertValidationIssue(.invalidSceneCount(7), in: makePresentation(sceneIDs: (1...7).map { "scene-\($0)" }), lesson: lesson, course: course)
    }

    func testValidatorRejectsInvalidProseOrState() {
        let lesson = makeLesson()
        let course = makeCourse()
        let validScenes = makeScenes(ids: ["scene-1", "scene-2", "scene-3"])

        assertValidationIssue(.blankPosterDescription, in: makePresentation(posterDescription: " "), lesson: lesson, course: course)

        let blankPosterState = PresentationVisualState(
            code: nil,
            codeTokens: [],
            values: [],
            output: nil,
            outputTargetID: nil,
            description: "\n"
        )
        assertValidationIssue(.blankVisualStateDescription(locationID: "poster", state: .poster), in: makePresentation(posterState: blankPosterState), lesson: lesson, course: course)

        var scenes = validScenes
        scenes[0] = makeScene(id: "scene-1", index: 0, caption: " \n")
        assertValidationIssue(.blankCaption(sceneID: "scene-1"), in: makePresentation(scenes: scenes), lesson: lesson, course: course)

        scenes = validScenes
        scenes[0] = makeScene(id: "scene-1", index: 0, narration: "\t")
        assertValidationIssue(.blankNarration(sceneID: "scene-1"), in: makePresentation(scenes: scenes), lesson: lesson, course: course)

        scenes = validScenes
        scenes[0] = makeScene(id: "scene-1", index: 0, staticDescription: " ")
        assertValidationIssue(.blankStaticDescription(sceneID: "scene-1"), in: makePresentation(scenes: scenes), lesson: lesson, course: course)

        scenes = validScenes
        let blankBeforeDescription = PresentationVisualState(
            code: scenes[0].before.code,
            codeTokens: scenes[0].before.codeTokens,
            values: scenes[0].before.values,
            output: scenes[0].before.output,
            outputTargetID: scenes[0].before.outputTargetID,
            description: " "
        )
        scenes[0] = makeScene(id: "scene-1", index: 0, before: blankBeforeDescription, after: scenes[0].after)
        assertValidationIssue(.blankVisualStateDescription(locationID: "scene-1", state: .before), in: makePresentation(scenes: scenes), lesson: lesson, course: course)

        scenes = validScenes
        let unchanged = makeState(tokenIDs: ["token-1"], valueIDs: ["value-1"], suffix: "unchanged")
        scenes[0] = makeScene(id: "scene-1", index: 0, before: unchanged, after: unchanged)
        assertValidationIssue(.sceneDoesNotChangeState(sceneID: "scene-1"), in: makePresentation(scenes: scenes), lesson: lesson, course: course)

        let omittedTranscript = validScenes.dropLast().map(\.narration).joined(separator: "\n\n")
        assertValidationIssue(.transcriptMissingNarration(sceneID: "scene-3"), in: makePresentation(scenes: validScenes, transcript: omittedTranscript), lesson: lesson, course: course)

        let reversedTranscript = validScenes.reversed().map(\.narration).joined(separator: "\n\n")
        assertValidationIssue(.transcriptNarrationOutOfOrder(sceneID: "scene-2"), in: makePresentation(scenes: validScenes, transcript: reversedTranscript), lesson: lesson, course: course)
    }

    func testValidatorRejectsInvalidLinkedActivity() {
        let lesson = makeLesson()
        let course = makeCourse()

        assertValidationIssue(
            .unknownFinalRecallQuestionID("missing-recall"),
            in: makePresentation(finalRecallQuestionID: "missing-recall"),
            lesson: lesson,
            course: course
        )
        assertValidationIssue(
            .missingAICodeExercise,
            in: makePresentation(includeAIExercise: false),
            lesson: lesson,
            course: course
        )
    }

    func testValidatorRejectsInvalidFocusTargets() {
        let lesson = makeLesson()
        let course = makeCourse()
        let before = PresentationVisualState(
            code: "print",
            codeTokens: [PresentationCodeToken(id: "print-token", text: "print")],
            values: [PresentationValue(id: "message-value", name: "message", value: "Hello")],
            output: nil,
            outputTargetID: nil,
            description: "Before output."
        )
        let after = PresentationVisualState(
            code: "print",
            codeTokens: [PresentationCodeToken(id: "print-token", text: "print")],
            values: [PresentationValue(id: "message-value", name: "message", value: "Hello")],
            output: "Hello",
            outputTargetID: "console",
            description: "After output."
        )

        func presentation(
            _ targets: [PresentationFocusTarget],
            before customBefore: PresentationVisualState? = nil,
            after customAfter: PresentationVisualState? = nil
        ) -> LessonPresentation {
            var scenes = makeScenes(ids: ["scene-1", "scene-2", "scene-3"])
            scenes[0] = makeScene(
                id: "scene-1",
                index: 0,
                focusTargets: targets,
                before: customBefore ?? before,
                after: customAfter ?? after
            )
            return makePresentation(scenes: scenes)
        }

        assertValidationIssue(.blankFocusTargetID(sceneID: "scene-1", kind: .codeToken), in: presentation([.init(kind: .codeToken, id: " ")]), lesson: lesson, course: course)
        assertValidationIssue(.duplicateFocusTarget(sceneID: "scene-1", kind: .value, id: "message-value"), in: presentation([.init(kind: .value, id: "message-value"), .init(kind: .value, id: "message-value")]), lesson: lesson, course: course)
        assertValidationIssue(.unresolvedCodeTokenFocus(sceneID: "scene-1", id: "missing-token"), in: presentation([.init(kind: .codeToken, id: "missing-token")]), lesson: lesson, course: course)
        assertValidationIssue(.unresolvedValueFocus(sceneID: "scene-1", id: "missing-value"), in: presentation([.init(kind: .value, id: "missing-value")]), lesson: lesson, course: course)
        assertValidationIssue(.unresolvedOutputFocus(sceneID: "scene-1", id: "missing-output"), in: presentation([.init(kind: .output, id: "missing-output")]), lesson: lesson, course: course)

        let mismatchedCode = PresentationVisualState(
            code: "print(1)",
            codeTokens: [PresentationCodeToken(id: "print-token", text: "print")],
            values: before.values,
            output: before.output,
            outputTargetID: before.outputTargetID,
            description: before.description
        )
        assertValidationIssue(.codeTokenTextMismatch(sceneID: "scene-1", state: .before), in: presentation([.init(kind: .codeToken, id: "print-token")], before: mismatchedCode), lesson: lesson, course: course)

        let tokenlessCode = PresentationVisualState(
            code: "print",
            codeTokens: [],
            values: [],
            output: nil,
            outputTargetID: nil,
            description: "Code is present without its authored tokens."
        )
        assertValidationIssue(
            .codeTokenTextMismatch(sceneID: "scene-1", state: .before),
            in: presentation([], before: tokenlessCode),
            lesson: lesson,
            course: course
        )
        assertValidationIssue(
            .codeTokenTextMismatch(sceneID: "scene-1", state: .after),
            in: presentation([], after: tokenlessCode),
            lesson: lesson,
            course: course
        )
    }

    func testValidatorRejectsInvalidMappings() {
        let lesson = makeLesson()
        let courseWithoutObjectives = makeCourse()
        let activeSet = ObjectiveSetID(rawValue: "swift-2026")
        let activeCourse = makeCourse(activeObjectiveSetID: activeSet)
        let knownObjective = ObjectiveID(rawValue: "objective-1")
        let known = [activeSet: Set([knownObjective])]

        assertValidationIssue(.blankConceptID(index: 0), in: makePresentation(conceptIDs: [" "]), lesson: lesson, course: courseWithoutObjectives)
        assertValidationIssue(.duplicateConceptID("test.concept"), in: makePresentation(conceptIDs: ["test.concept", "test.concept"]), lesson: lesson, course: courseWithoutObjectives)
        assertValidationIssue(.unknownExerciseConceptID("exercise-only"), in: makePresentation(exerciseConceptIDs: ["exercise-only"]), lesson: lesson, course: courseWithoutObjectives)

        let mappingWithUnknownConcept = ObjectiveMapping(
            conceptID: "mapping-only",
            objectiveSetID: activeSet,
            objectiveID: knownObjective
        )
        assertValidationIssue(.unknownMappingConceptID("mapping-only"), in: makePresentation(objectiveMappings: [mappingWithUnknownConcept]), lesson: lesson, course: activeCourse, knownObjectivesBySet: known)

        let validMapping = ObjectiveMapping(
            conceptID: "test.concept",
            objectiveSetID: activeSet,
            objectiveID: knownObjective
        )
        assertValidationIssue(.objectiveMappingsRequireActiveSet, in: makePresentation(objectiveMappings: [validMapping]), lesson: lesson, course: courseWithoutObjectives)

        let wrongSet = ObjectiveSetID(rawValue: "old-set")
        let wrongSetMapping = ObjectiveMapping(
            conceptID: "test.concept",
            objectiveSetID: wrongSet,
            objectiveID: knownObjective
        )
        assertValidationIssue(.wrongObjectiveSet(expected: activeSet, actual: wrongSet), in: makePresentation(objectiveMappings: [wrongSetMapping]), lesson: lesson, course: activeCourse, knownObjectivesBySet: known)

        let missingObjective = ObjectiveID(rawValue: "missing-objective")
        let missingObjectiveMapping = ObjectiveMapping(
            conceptID: "test.concept",
            objectiveSetID: activeSet,
            objectiveID: missingObjective
        )
        assertValidationIssue(.unknownObjectiveID(setID: activeSet, objectiveID: missingObjective), in: makePresentation(objectiveMappings: [missingObjectiveMapping]), lesson: lesson, course: activeCourse, knownObjectivesBySet: known)
    }

    func testLessonOnePresentation() throws {
        let presentation = SwiftPilotPresentationContent.lesson1
        let lesson = try XCTUnwrap(Curriculum.defaultLesson(id: 1))
        let deepContent = try XCTUnwrap(lesson.deepContent)

        XCTAssertEqual(presentation.id, "swift-1-print-output")
        XCTAssertEqual(presentation.scenes.map(\.id), ["print-call", "string-literal", "execution", "output"])
        XCTAssertEqual(presentation.scenes.map(\.narration), deepContent.segments.map(\.explanation))
        XCTAssertEqual(presentation.transcript, presentation.scenes.map(\.narration).joined(separator: "\n\n"))
        XCTAssertEqual(presentation.finalRecallQuestionID, "lesson-1-recall-quotation-marks")
        XCTAssertEqual(presentation.provenance, .init(source: .bundled, revision: 1))
        XCTAssertEqual(presentation.objectiveMappings, [])
        XCTAssertTrue(presentation.conceptIDs.allSatisfy { $0.rawValue.hasPrefix("swift.lesson-1.") })

        XCTAssertNil(presentation.posterState.code)
        XCTAssertTrue(presentation.posterState.codeTokens.isEmpty)
        XCTAssertTrue(presentation.posterState.values.isEmpty)
        XCTAssertNil(presentation.posterState.output)

        let printCall = presentation.scenes[0]
        XCTAssertNil(printCall.before.code)
        XCTAssertEqual(printCall.after.code, "print(\"Hello, Swift!\")")
        XCTAssertEqual(printCall.after.codeTokens.map(\.id), ["print-function", "open-paren", "string-literal", "close-paren"])

        let stringLiteral = presentation.scenes[1]
        XCTAssertEqual(stringLiteral.focusTargets, [.init(kind: .codeToken, id: "string-literal")])
        XCTAssertEqual(stringLiteral.after.values.map(\.id), ["message-value"])
        XCTAssertEqual(stringLiteral.after.values.first?.value, "Hello, Swift!")

        let execution = presentation.scenes[2]
        XCTAssertEqual(execution.before.values.first?.value, "ready")
        XCTAssertEqual(execution.after.values.first?.value, "executing")

        let output = presentation.scenes[3]
        XCTAssertNil(output.before.output)
        XCTAssertEqual(output.after.output, "Hello, Swift!")
        XCTAssertEqual(output.after.outputTargetID, "stdout")
        XCTAssertEqual(output.focusTargets, [.init(kind: .output, id: "stdout")])

        let exercise = try XCTUnwrap(presentation.aiCodeExercise)
        XCTAssertEqual(exercise.claims.map(\.isCorrect), [true, false])
        XCTAssertEqual(exercise.claims[1].text, "The quotation marks appear in the printed output.")
        XCTAssertTrue(exercise.claims.allSatisfy { !$0.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        XCTAssertEqual(Set(exercise.conceptIDs).subtracting(presentation.conceptIDs), [])

        assertCompleteStaticDescriptions(presentation)
        XCTAssertEqual(
            PresentationContentValidator.validate(
                presentation,
                lesson: lesson,
                course: try XCTUnwrap(CourseCatalog.default[.swiftDevelopment]),
                knownObjectivesBySet: [:]
            ),
            []
        )
    }

    func testLessonTwoPresentation() throws {
        let presentation = SwiftPilotPresentationContent.lesson2
        let lesson = try XCTUnwrap(Curriculum.defaultLesson(id: 2))
        let deepContent = try XCTUnwrap(lesson.deepContent)

        XCTAssertEqual(presentation.id, "swift-2-constant-binding")
        XCTAssertEqual(presentation.scenes.map(\.id), ["let-binding", "stored-value", "name-lookup", "output"])
        XCTAssertEqual(presentation.scenes.map(\.narration), deepContent.segments.map(\.explanation))
        XCTAssertEqual(presentation.transcript, presentation.scenes.map(\.narration).joined(separator: "\n\n"))
        XCTAssertEqual(presentation.finalRecallQuestionID, "lesson-2-recall-quoted-name")
        XCTAssertEqual(presentation.objectiveMappings, [])
        XCTAssertTrue(presentation.conceptIDs.allSatisfy { $0.rawValue.hasPrefix("swift.lesson-2.") })

        XCTAssertNil(presentation.scenes[0].before.code)
        XCTAssertEqual(presentation.scenes[0].after.code, "let name = \"Alex\"")
        XCTAssertEqual(presentation.scenes[1].after.values, [
            PresentationValue(id: "name-value", name: "name", value: "Alex")
        ])
        XCTAssertEqual(presentation.scenes[2].after.code, "let name = \"Alex\"\nprint(name)")
        XCTAssertTrue(presentation.scenes[2].after.codeTokens.contains { $0.id == "name-reference" })
        XCTAssertEqual(presentation.scenes[2].focusTargets, [.init(kind: .codeToken, id: "name-reference")])
        XCTAssertNil(presentation.scenes[3].before.output)
        XCTAssertEqual(presentation.scenes[3].after.output, "Alex")
        XCTAssertEqual(presentation.scenes[3].after.outputTargetID, "stdout")

        let exercise = try XCTUnwrap(presentation.aiCodeExercise)
        XCTAssertEqual(exercise.claims.map(\.isCorrect), [true, false])
        XCTAssertEqual(exercise.claims[1].text, "`print(\"name\")` reads the value stored in `name`.")
        XCTAssertTrue(exercise.claims.allSatisfy { !$0.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })

        assertCompleteStaticDescriptions(presentation)
        XCTAssertEqual(
            PresentationContentValidator.validate(
                presentation,
                lesson: lesson,
                course: try XCTUnwrap(CourseCatalog.default[.swiftDevelopment]),
                knownObjectivesBySet: [:]
            ),
            []
        )
    }

    func testLessonThreePresentation() throws {
        let presentation = SwiftPilotPresentationContent.lesson3
        let lesson = try XCTUnwrap(Curriculum.defaultLesson(id: 3))
        let deepContent = try XCTUnwrap(lesson.deepContent)
        let expectedNarrations = [
            deepContent.segments[0].explanation,
            deepContent.segments[2].explanation,
            deepContent.segments[1].explanation,
            deepContent.segments[3].explanation
        ]

        XCTAssertEqual(presentation.id, "swift-3-variable-mutation")
        XCTAssertEqual(presentation.scenes.map(\.id), ["var-binding", "first-value", "reassignment", "output"])
        XCTAssertEqual(presentation.scenes.map(\.narration), expectedNarrations)
        XCTAssertEqual(presentation.transcript, expectedNarrations.joined(separator: "\n\n"))
        XCTAssertEqual(presentation.finalRecallQuestionID, "lesson-3-recall-var")
        XCTAssertEqual(presentation.objectiveMappings, [])
        XCTAssertTrue(presentation.conceptIDs.allSatisfy { $0.rawValue.hasPrefix("swift.lesson-3.") })

        XCTAssertNil(presentation.scenes[0].before.code)
        XCTAssertEqual(presentation.scenes[0].after.code, "var count = 1")
        XCTAssertEqual(presentation.scenes[1].after.values, [
            PresentationValue(id: "count-value", name: "count", value: "1")
        ])
        XCTAssertEqual(presentation.scenes[2].before.values.first?.value, "1")
        XCTAssertEqual(presentation.scenes[2].after.values.first?.value, "2")
        XCTAssertEqual(presentation.scenes[2].after.code, "var count = 1\ncount = 2")
        XCTAssertNil(presentation.scenes[3].before.output)
        XCTAssertEqual(presentation.scenes[3].after.code, "var count = 1\ncount = 2\nprint(count)")
        XCTAssertEqual(presentation.scenes[3].after.output, "2")
        XCTAssertEqual(presentation.scenes[3].after.outputTargetID, "stdout")

        let exercise = try XCTUnwrap(presentation.aiCodeExercise)
        XCTAssertEqual(exercise.claims.map(\.isCorrect), [true, false])
        XCTAssertEqual(exercise.claims[1].text, "Changing `var` to `let` still permits reassignment.")
        XCTAssertTrue(exercise.claims.allSatisfy { !$0.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })

        assertCompleteStaticDescriptions(presentation)
        XCTAssertEqual(
            PresentationContentValidator.validate(
                presentation,
                lesson: lesson,
                course: try XCTUnwrap(CourseCatalog.default[.swiftDevelopment]),
                knownObjectivesBySet: [:]
            ),
            []
        )
    }

    func testOnlyFirstThreeLessonsHavePresentations() {
        XCTAssertEqual(
            Curriculum.defaultLessons.prefix(3).compactMap { $0.presentation?.id },
            [
                "swift-1-print-output",
                "swift-2-constant-binding",
                "swift-3-variable-mutation"
            ]
        )
        for lessonID in 4...24 {
            XCTAssertNil(
                Curriculum.defaultLesson(id: lessonID)?.presentation,
                "Lesson \(lessonID) must remain outside the presentation pilot"
            )
        }

        let customLesson = Lesson(
            id: 1000,
            title: "Custom lesson",
            goal: "Custom goal",
            starterCode: "",
            teaches: [],
            glossaryTerms: [],
            syntaxTokens: [],
            syntaxWhy: "",
            expectedOutput: "",
            successMarkers: [],
            successMessage: "",
            hint: ""
        )
        XCTAssertNil(customLesson.presentation)
    }

    private func assertCompleteStaticDescriptions(
        _ presentation: LessonPresentation,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(presentation.posterDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, file: file, line: line)
        XCTAssertFalse(presentation.posterState.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, file: file, line: line)
        for scene in presentation.scenes {
            XCTAssertFalse(scene.staticDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, file: file, line: line)
            XCTAssertFalse(scene.before.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, file: file, line: line)
            XCTAssertFalse(scene.after.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, file: file, line: line)
        }
    }

    private func assertValidationIssue(
        _ expected: PresentationValidationIssue,
        in presentation: LessonPresentation,
        lesson: Lesson,
        course: CourseDefinition,
        knownObjectivesBySet: [ObjectiveSetID: Set<ObjectiveID>] = [:],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let issues = PresentationContentValidator.validate(
            presentation,
            lesson: lesson,
            course: course,
            knownObjectivesBySet: knownObjectivesBySet
        )
        XCTAssertTrue(issues.contains(expected), "Expected \(expected), got \(issues)", file: file, line: line)
    }

    private func makePresentation(
        id: String = "test-presentation",
        sceneIDs: [String] = ["scene-1", "scene-2", "scene-3"],
        tokenIDs: [String] = ["token-1", "token-2"],
        valueIDs: [String] = ["value-1", "value-2"],
        claimIDs: [String] = ["claim-1", "claim-2"],
        scenes suppliedScenes: [PresentationScene]? = nil,
        transcript suppliedTranscript: String? = nil,
        finalRecallQuestionID: String = "recall-1",
        includeAIExercise: Bool = true,
        conceptIDs: [ConceptID] = ["test.concept"],
        exerciseConceptIDs: [ConceptID] = ["test.concept"],
        objectiveMappings: [ObjectiveMapping] = [],
        posterDescription: String = "A complete static poster.",
        posterState suppliedPosterState: PresentationVisualState? = nil
    ) -> LessonPresentation {
        let scenes = suppliedScenes ?? makeScenes(ids: sceneIDs, firstTokenIDs: tokenIDs, firstValueIDs: valueIDs)
        return LessonPresentation(
            id: id,
            title: "Test presentation",
            posterDescription: posterDescription,
            posterState: suppliedPosterState ?? makeState(tokenIDs: ["poster-token"], valueIDs: ["poster-value"], suffix: "poster"),
            scenes: scenes,
            transcript: suppliedTranscript ?? scenes.map(\.narration).joined(separator: "\n\n"),
            narrationLocale: "en-US",
            finalRecallQuestionID: finalRecallQuestionID,
            aiCodeExercise: includeAIExercise ? AICodeReviewExercise(
                id: "exercise-1",
                prompt: "Review this generated code.",
                generatedCode: "print(1)",
                claims: claimIDs.enumerated().map { index, claimID in
                    AICodeClaim(
                        id: claimID,
                        text: "Claim \(index + 1)",
                        isCorrect: index == 0,
                        explanation: "Evidence for claim \(index + 1)."
                    )
                },
                conceptIDs: exerciseConceptIDs
            ) : nil,
            conceptIDs: conceptIDs,
            objectiveMappings: objectiveMappings,
            provenance: .init(source: .bundled, revision: 1)
        )
    }

    private func makeScenes(
        ids: [String],
        firstTokenIDs: [String] = ["token-1", "token-2"],
        firstValueIDs: [String] = ["value-1", "value-2"]
    ) -> [PresentationScene] {
        ids.enumerated().map { index, sceneID in
            makeScene(
                id: sceneID,
                index: index,
                tokenIDs: index == 0 ? firstTokenIDs : ["token-\(index + 3)"],
                valueIDs: index == 0 ? firstValueIDs : ["value-\(index + 3)"]
            )
        }
    }

    private func makeScene(
        id: String,
        index: Int,
        caption: String? = nil,
        narration: String? = nil,
        staticDescription: String? = nil,
        tokenIDs: [String]? = nil,
        valueIDs: [String]? = nil,
        focusTargets: [PresentationFocusTarget] = [],
        before suppliedBefore: PresentationVisualState? = nil,
        after suppliedAfter: PresentationVisualState? = nil
    ) -> PresentationScene {
        let currentTokenIDs = tokenIDs ?? ["token-\(index + 1)"]
        let currentValueIDs = valueIDs ?? ["value-\(index + 1)"]
        let before = suppliedBefore ?? makeState(tokenIDs: currentTokenIDs, valueIDs: currentValueIDs, suffix: "before-\(index)")
        let after = suppliedAfter ?? makeState(tokenIDs: currentTokenIDs, valueIDs: currentValueIDs, suffix: "after-\(index)")
        return PresentationScene(
            id: id,
            title: "Scene \(index + 1)",
            caption: caption ?? "Caption \(index + 1)",
            narration: narration ?? "Narration \(index + 1).",
            staticDescription: staticDescription ?? "Static scene \(index + 1).",
            visualKind: .codeExecution,
            focusTargets: focusTargets,
            before: before,
            after: after
        )
    }

    private func makeState(tokenIDs: [String], valueIDs: [String], suffix: String) -> PresentationVisualState {
        PresentationVisualState(
            code: tokenIDs.enumerated().map { index, _ in "token\(index)" }.joined(),
            codeTokens: tokenIDs.enumerated().map { index, id in
                PresentationCodeToken(id: id, text: "token\(index)")
            },
            values: valueIDs.enumerated().map { index, id in
                PresentationValue(id: id, name: "value\(index)", value: suffix)
            },
            output: nil,
            outputTargetID: nil,
            description: "State \(suffix)."
        )
    }

    private func makeLesson() -> Lesson {
        Lesson(
            id: 999,
            title: "Test lesson",
            goal: "Test goal",
            starterCode: "print(1)",
            teaches: [],
            glossaryTerms: [],
            syntaxTokens: [],
            syntaxWhy: "Test why",
            expectedOutput: "1",
            successMarkers: [],
            successMessage: "Success",
            hint: "Hint",
            deepContent: LessonDeepContent(
                title: "Deep lesson",
                introduction: "Introduction",
                segments: [],
                microscopeTokens: [],
                modifyTask: ModifyTask(
                    id: "modify-1",
                    prompt: "Modify",
                    starterCode: "print(1)",
                    expectedCode: "print(2)",
                    predictionPrompt: "Predict",
                    expectedOutput: "2",
                    successExplanation: "Explanation",
                    conceptIDs: ["test.concept"]
                ),
                recallQuestions: [
                    RecallQuestion(
                        id: "recall-1",
                        prompt: "Recall?",
                        choices: ["Yes", "No"],
                        correctChoiceIndex: 0,
                        explanation: "Because.",
                        conceptIDs: ["test.concept"]
                    )
                ]
            )
        )
    }

    private func makeCourse(activeObjectiveSetID: ObjectiveSetID? = nil) -> CourseDefinition {
        CourseDefinition(
            id: .swiftDevelopment,
            title: "Swift",
            summary: "Test course",
            symbolName: "swift",
            accentName: "orange",
            availability: .available,
            releaseLevel: .pilot,
            runtimeKind: .swiftConsole,
            certificationTargets: [],
            activeObjectiveSetID: activeObjectiveSetID
        )
    }
}
