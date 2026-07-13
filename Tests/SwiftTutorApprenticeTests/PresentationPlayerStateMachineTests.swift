import Foundation
import XCTest
@testable import SwiftTutorApprentice

final class PresentationPlayerStateMachineTests: XCTestCase {
    private let presentation = SwiftPilotPresentationContent.lesson1

    func testEntryModeUsesExactFirstVisitAndReturnPolicy() throws {
        let firstSceneID = try XCTUnwrap(presentation.scenes.first?.id)
        let secondSceneID = presentation.scenes[1].id

        XCTAssertEqual(
            PresentationPlayerStateMachine.entryMode(
                presentation: presentation,
                savedState: nil
            ),
            .expandedPoster
        )
        XCTAssertEqual(
            PresentationPlayerStateMachine.entryMode(
                presentation: presentation,
                savedState: state(status: .notStarted, sceneID: firstSceneID)
            ),
            .expandedPoster
        )
        XCTAssertEqual(
            PresentationPlayerStateMachine.entryMode(
                presentation: presentation,
                savedState: state(status: .started, sceneID: secondSceneID)
            ),
            .compactResume(sceneID: secondSceneID)
        )
        XCTAssertEqual(
            PresentationPlayerStateMachine.entryMode(
                presentation: presentation,
                savedState: state(status: .started, sceneID: secondSceneID, revision: 0)
            ),
            .compactResume(sceneID: firstSceneID)
        )
        XCTAssertEqual(
            PresentationPlayerStateMachine.entryMode(
                presentation: presentation,
                savedState: state(status: .started, sceneID: "removed-scene")
            ),
            .compactResume(sceneID: firstSceneID)
        )
        XCTAssertEqual(
            PresentationPlayerStateMachine.entryMode(
                presentation: presentation,
                savedState: state(status: .skipped, sceneID: firstSceneID, revision: 0)
            ),
            .compactSummary(status: .skipped)
        )
        XCTAssertEqual(
            PresentationPlayerStateMachine.entryMode(
                presentation: presentation,
                savedState: state(status: .completed, sceneID: "removed-scene", revision: 0)
            ),
            .compactSummary(status: .completed)
        )
    }

    func testDifferentPresentationIdentityAlwaysReturnsToFirstVisitPoster() throws {
        for status in [PresentationStatus.started, .skipped, .completed] {
            let saved = state(
                status: status,
                sceneID: presentation.scenes.last?.id,
                revision: presentation.provenance.revision
            )
            var replaced = saved
            replaced.presentationID = "retired-presentation"

            XCTAssertEqual(
                PresentationPlayerStateMachine.entryMode(
                    presentation: presentation,
                    savedState: replaced
                ),
                .expandedPoster
            )
        }
    }

    func testReplacementStartAndSkipResetOldPresentationIntent() throws {
        let now = Date(timeIntervalSinceReferenceDate: 44)
        var old = state(
            status: .completed,
            sceneID: presentation.scenes.last?.id,
            firstStartedAt: Date(timeIntervalSinceReferenceDate: 1),
            lastOpenedAt: Date(timeIntervalSinceReferenceDate: 2),
            replayCount: 9
        )
        old.presentationID = "retired-presentation"

        let started = try XCTUnwrap(PresentationPlayerStateMachine.start(
            presentation: presentation,
            savedState: old,
            now: now
        ))
        XCTAssertEqual(started.presentationID, presentation.id)
        XCTAssertEqual(started.firstStartedAt, now)
        XCTAssertEqual(started.replayCount, 0)
        XCTAssertEqual(started.lastSceneID, presentation.scenes.first?.id)

        let skipped = PresentationPlayerStateMachine.skip(
            presentation: presentation,
            savedState: old,
            now: now
        )
        XCTAssertEqual(skipped.presentationID, presentation.id)
        XCTAssertNil(skipped.firstStartedAt)
        XCTAssertEqual(skipped.replayCount, 0)
        XCTAssertNil(skipped.lastSceneID)
    }

    func testReplacementCompleteDoesNotCarryOldPresentationIntent() throws {
        let now = Date(timeIntervalSinceReferenceDate: 55)
        var old = state(
            status: .started,
            sceneID: presentation.scenes.last?.id,
            firstStartedAt: Date(timeIntervalSinceReferenceDate: 1),
            lastOpenedAt: Date(timeIntervalSinceReferenceDate: 2),
            replayCount: 9
        )
        old.presentationID = "retired-presentation"

        let completed = try XCTUnwrap(PresentationPlayerStateMachine.complete(
            presentation: presentation,
            savedState: old,
            now: now
        ))

        XCTAssertEqual(completed.presentationID, presentation.id)
        XCTAssertNil(completed.firstStartedAt)
        XCTAssertEqual(completed.replayCount, 0)
        XCTAssertEqual(completed.lastSceneID, presentation.scenes.last?.id)
    }

    func testLegacyMissingIdentityKeepsCompatibleStateUntilIntentionalMutation() throws {
        var legacy = state(
            status: .started,
            sceneID: presentation.scenes[1].id,
            firstStartedAt: Date(timeIntervalSinceReferenceDate: 1),
            replayCount: 2
        )
        legacy.presentationID = nil

        XCTAssertEqual(
            PresentationPlayerStateMachine.entryMode(
                presentation: presentation,
                savedState: legacy
            ),
            .compactResume(sceneID: presentation.scenes[1].id)
        )
        let next = try XCTUnwrap(PresentationPlayerStateMachine.next(
            presentation: presentation,
            savedState: legacy,
            now: Date(timeIntervalSinceReferenceDate: 5)
        ))
        XCTAssertEqual(next.presentationID, presentation.id)
        XCTAssertEqual(next.firstStartedAt, legacy.firstStartedAt)
        XCTAssertEqual(next.replayCount, 2)
    }

    func testEmptyPresentationIsUnavailableAndSceneDependentActionsFailClosed() throws {
        let emptyPresentation = try makeDecodedEmptyPresentation()
        let now = Date(timeIntervalSinceReferenceDate: 55)
        let savedState = state(
            status: .started,
            sceneID: "removed-scene",
            firstStartedAt: now,
            lastOpenedAt: now
        )

        XCTAssertEqual(
            PresentationPlayerStateMachine.entryMode(
                presentation: emptyPresentation,
                savedState: nil
            ),
            .unavailable
        )
        XCTAssertEqual(
            PresentationPlayerStateMachine.entryMode(
                presentation: emptyPresentation,
                savedState: savedState
            ),
            .unavailable
        )
        XCTAssertNil(PresentationPlayerStateMachine.start(
            presentation: emptyPresentation,
            savedState: nil,
            now: now
        ))
        XCTAssertNil(PresentationPlayerStateMachine.next(
            presentation: emptyPresentation,
            savedState: savedState,
            now: now
        ))
        XCTAssertNil(PresentationPlayerStateMachine.back(
            presentation: emptyPresentation,
            savedState: savedState,
            now: now
        ))
        XCTAssertNil(PresentationPlayerStateMachine.replay(
            presentation: emptyPresentation,
            savedState: savedState,
            now: now
        ))
        XCTAssertNil(PresentationPlayerStateMachine.complete(
            presentation: emptyPresentation,
            savedState: savedState,
            now: now
        ))
        let skipped = PresentationPlayerStateMachine.skip(
            presentation: emptyPresentation,
            savedState: savedState,
            now: now
        )
        XCTAssertEqual(skipped.status, .skipped)
        XCTAssertNil(skipped.lastSceneID)
    }

    func testStartNextAndBackTransitions() throws {
        let now = Date(timeIntervalSinceReferenceDate: 1_234)
        let later = Date(timeIntervalSinceReferenceDate: 2_345)
        let firstSceneID = try XCTUnwrap(presentation.scenes.first?.id)
        let secondSceneID = presentation.scenes[1].id

        let started = try XCTUnwrap(PresentationPlayerStateMachine.start(
            presentation: presentation,
            savedState: nil,
            now: now
        ))
        XCTAssertEqual(
            started,
            LessonPresentationState(
                status: .started,
                lastSceneID: firstSceneID,
                presentationRevision: presentation.provenance.revision,
                firstStartedAt: now,
                lastOpenedAt: now,
                replayCount: 0,
                presentationID: presentation.id
            )
        )

        let next = try XCTUnwrap(PresentationPlayerStateMachine.next(
            presentation: presentation,
            savedState: started,
            now: later
        ))
        XCTAssertEqual(next.status, started.status)
        XCTAssertEqual(next.lastSceneID, secondSceneID)
        XCTAssertEqual(next.presentationRevision, started.presentationRevision)
        XCTAssertEqual(next.firstStartedAt, started.firstStartedAt)
        XCTAssertEqual(next.lastOpenedAt, later)
        XCTAssertEqual(next.replayCount, started.replayCount)

        let back = try XCTUnwrap(PresentationPlayerStateMachine.back(
            presentation: presentation,
            savedState: next,
            now: later.addingTimeInterval(1)
        ))
        XCTAssertEqual(back.lastSceneID, firstSceneID)
        XCTAssertEqual(back.firstStartedAt, now)
        XCTAssertEqual(back.lastOpenedAt, later.addingTimeInterval(1))

        let boundedBack = try XCTUnwrap(PresentationPlayerStateMachine.back(
            presentation: presentation,
            savedState: back,
            now: later.addingTimeInterval(2)
        ))
        XCTAssertEqual(boundedBack.lastSceneID, firstSceneID)
        XCTAssertEqual(boundedBack.firstStartedAt, now)

        let repeatedStart = try XCTUnwrap(PresentationPlayerStateMachine.start(
            presentation: presentation,
            savedState: started,
            now: later
        ))
        XCTAssertEqual(repeatedStart.firstStartedAt, now)
        XCTAssertEqual(repeatedStart.lastOpenedAt, later)
        XCTAssertEqual(repeatedStart.replayCount, 0)

        let staleResume = state(
            status: .started,
            sceneID: try XCTUnwrap(presentation.scenes.last?.id),
            revision: presentation.provenance.revision - 1,
            firstStartedAt: now,
            lastOpenedAt: now
        )
        let nextAfterRevisionRepair = try XCTUnwrap(PresentationPlayerStateMachine.next(
            presentation: presentation,
            savedState: staleResume,
            now: later
        ))
        XCTAssertEqual(nextAfterRevisionRepair.lastSceneID, secondSceneID)
        XCTAssertEqual(
            nextAfterRevisionRepair.presentationRevision,
            presentation.provenance.revision
        )
        let backAfterRevisionRepair = try XCTUnwrap(PresentationPlayerStateMachine.back(
            presentation: presentation,
            savedState: staleResume,
            now: later
        ))
        XCTAssertEqual(backAfterRevisionRepair.lastSceneID, firstSceneID)
    }

    func testSkipReplayAndCompleteTransitions() throws {
        let firstStartedAt = Date(timeIntervalSinceReferenceDate: 100)
        let now = Date(timeIntervalSinceReferenceDate: 5_000)
        let firstSceneID = try XCTUnwrap(presentation.scenes.first?.id)
        let finalSceneID = try XCTUnwrap(presentation.scenes.last?.id)
        let started = state(
            status: .started,
            sceneID: presentation.scenes[1].id,
            firstStartedAt: firstStartedAt,
            lastOpenedAt: firstStartedAt,
            replayCount: 2
        )

        let skipped = PresentationPlayerStateMachine.skip(
            presentation: presentation,
            savedState: started,
            now: now
        )
        XCTAssertEqual(
            skipped,
            LessonPresentationState(
                status: .skipped,
                lastSceneID: nil,
                presentationRevision: presentation.provenance.revision,
                firstStartedAt: firstStartedAt,
                lastOpenedAt: now,
                replayCount: 2,
                presentationID: presentation.id
            )
        )

        let directSkip = PresentationPlayerStateMachine.skip(
            presentation: presentation,
            savedState: nil,
            now: now
        )
        XCTAssertNil(directSkip.firstStartedAt)
        XCTAssertNil(directSkip.lastSceneID)
        XCTAssertEqual(directSkip.replayCount, 0)

        let replayed = try XCTUnwrap(PresentationPlayerStateMachine.replay(
            presentation: presentation,
            savedState: skipped,
            now: now.addingTimeInterval(1)
        ))
        XCTAssertEqual(replayed.status, .started)
        XCTAssertEqual(replayed.lastSceneID, firstSceneID)
        XCTAssertEqual(replayed.presentationRevision, presentation.provenance.revision)
        XCTAssertEqual(replayed.firstStartedAt, firstStartedAt)
        XCTAssertEqual(replayed.lastOpenedAt, now.addingTimeInterval(1))
        XCTAssertEqual(replayed.replayCount, 3)

        let replayedWithoutPriorStart = try XCTUnwrap(PresentationPlayerStateMachine.replay(
            presentation: presentation,
            savedState: directSkip,
            now: now.addingTimeInterval(2)
        ))
        XCTAssertEqual(replayedWithoutPriorStart.firstStartedAt, now.addingTimeInterval(2))
        XCTAssertEqual(replayedWithoutPriorStart.replayCount, 1)

        let completedBeforeReplay = state(
            status: .completed,
            sceneID: finalSceneID,
            firstStartedAt: firstStartedAt,
            lastOpenedAt: now,
            replayCount: 7
        )
        let replayedFromCompleted = try XCTUnwrap(PresentationPlayerStateMachine.replay(
            presentation: presentation,
            savedState: completedBeforeReplay,
            now: now.addingTimeInterval(2.5)
        ))
        XCTAssertEqual(replayedFromCompleted.status, .started)
        XCTAssertEqual(replayedFromCompleted.lastSceneID, firstSceneID)
        XCTAssertEqual(replayedFromCompleted.firstStartedAt, firstStartedAt)
        XCTAssertEqual(replayedFromCompleted.replayCount, 8)

        let completed = try XCTUnwrap(PresentationPlayerStateMachine.complete(
            presentation: presentation,
            savedState: started,
            now: now.addingTimeInterval(3)
        ))
        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(completed.lastSceneID, finalSceneID)
        XCTAssertEqual(completed.presentationRevision, presentation.provenance.revision)
        XCTAssertEqual(completed.firstStartedAt, firstStartedAt)
        XCTAssertEqual(completed.lastOpenedAt, now.addingTimeInterval(3))
        XCTAssertEqual(completed.replayCount, 2)
    }

    func testEveryTransitionNormalizesNegativeDecodedReplayCounts() throws {
        let now = Date(timeIntervalSinceReferenceDate: 8_000)
        let firstSceneID = try XCTUnwrap(presentation.scenes.first?.id)
        let negative = state(
            status: .started,
            sceneID: firstSceneID,
            firstStartedAt: now,
            lastOpenedAt: now,
            replayCount: -4
        )

        XCTAssertEqual(try XCTUnwrap(PresentationPlayerStateMachine.start(
            presentation: presentation,
            savedState: negative,
            now: now
        )).replayCount, 0)
        XCTAssertEqual(try XCTUnwrap(PresentationPlayerStateMachine.next(
            presentation: presentation,
            savedState: negative,
            now: now
        )).replayCount, 0)
        XCTAssertEqual(try XCTUnwrap(PresentationPlayerStateMachine.back(
            presentation: presentation,
            savedState: negative,
            now: now
        )).replayCount, 0)
        XCTAssertEqual(PresentationPlayerStateMachine.skip(
            presentation: presentation,
            savedState: negative,
            now: now
        ).replayCount, 0)
        XCTAssertEqual(try XCTUnwrap(PresentationPlayerStateMachine.replay(
            presentation: presentation,
            savedState: negative,
            now: now
        )).replayCount, 1)
        XCTAssertEqual(try XCTUnwrap(PresentationPlayerStateMachine.complete(
            presentation: presentation,
            savedState: negative,
            now: now
        )).replayCount, 0)
    }

    func testReplayCountSaturatesAtMaximumWithoutOverflow() throws {
        let now = Date(timeIntervalSinceReferenceDate: 9_000)
        let maximum = state(
            status: .completed,
            sceneID: try XCTUnwrap(presentation.scenes.last?.id),
            firstStartedAt: now,
            lastOpenedAt: now,
            replayCount: .max
        )

        let replayed = try XCTUnwrap(PresentationPlayerStateMachine.replay(
            presentation: presentation,
            savedState: maximum,
            now: now
        ))
        XCTAssertEqual(replayed.replayCount, .max)
    }

    private func state(
        status: PresentationStatus,
        sceneID: String?,
        revision: Int? = nil,
        firstStartedAt: Date? = nil,
        lastOpenedAt: Date? = nil,
        replayCount: Int = 0
    ) -> LessonPresentationState {
        LessonPresentationState(
            status: status,
            lastSceneID: sceneID,
            presentationRevision: revision ?? presentation.provenance.revision,
            firstStartedAt: firstStartedAt,
            lastOpenedAt: lastOpenedAt,
            replayCount: replayCount,
            presentationID: presentation.id
        )
    }

    private func makeDecodedEmptyPresentation() throws -> LessonPresentation {
        let emptyPresentation = LessonPresentation(
            id: presentation.id,
            title: presentation.title,
            posterDescription: presentation.posterDescription,
            posterState: presentation.posterState,
            scenes: [],
            transcript: presentation.transcript,
            narrationLocale: presentation.narrationLocale,
            finalRecallQuestionID: presentation.finalRecallQuestionID,
            aiCodeExercise: presentation.aiCodeExercise,
            conceptIDs: presentation.conceptIDs,
            objectiveMappings: presentation.objectiveMappings,
            provenance: presentation.provenance
        )
        return try JSONDecoder().decode(
            LessonPresentation.self,
            from: JSONEncoder().encode(emptyPresentation)
        )
    }
}
