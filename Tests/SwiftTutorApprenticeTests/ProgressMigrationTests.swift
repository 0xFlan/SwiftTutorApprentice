import Foundation
import XCTest
@testable import SwiftTutorApprentice

final class ProgressMigrationTests: XCTestCase {
    func testVersionOneMigratesToSwiftCourse() throws {
        let data = Data(#"{ "completedLessonIDs": [1,3] }"#.utf8)

        let result = ProgressMigration.decode(data: data)

        guard case let .migrated(sourceVersion, document) = result else {
            return XCTFail("Expected migrated v1 document, got \(result)")
        }
        XCTAssertEqual(sourceVersion, 1)
        XCTAssertEqual(document.version, ProgressDocument.currentVersion)
        let swiftProgress = try XCTUnwrap(document.courses[.swiftDevelopment])
        XCTAssertEqual(
            swiftProgress.completedLessonLocalIDs,
            [LessonLocalID(rawValue: "1"), LessonLocalID(rawValue: "3")]
        )
        XCTAssertEqual(swiftProgress.stageEvents, [])
        XCTAssertEqual(swiftProgress.presentationStates, [:])
    }

    func testLossyVersionTwoElementDecoding() throws {
        let data = Data(
            #"""
            [
                {
                    "lessonID": 1,
                    "kind": "recallAnswered",
                    "timestamp": 0,
                    "questionID": null,
                    "wasCorrect": null
                },
                {
                    "lessonID": "not-an-integer",
                    "kind": "deepLessonViewed",
                    "timestamp": 0
                }
            ]
            """#.utf8
        )

        let events = try LegacyStageEventDecoder.decodeElements(from: data)

        XCTAssertEqual(
            events,
            [
                LegacyStageEvent(
                    lessonID: 1,
                    kind: .recallAnswered,
                    timestamp: Date(timeIntervalSinceReferenceDate: 0),
                    questionID: nil,
                    wasCorrect: nil
                )
            ]
        )
    }

    func testLegacyMetadataValidation() {
        XCTAssertTrue(ProgressMigration.hasValidMetadata(legacyEvent(
            kind: .recallAnswered,
            questionID: " question-1 ",
            wasCorrect: false
        )))
        XCTAssertFalse(ProgressMigration.hasValidMetadata(legacyEvent(
            kind: .recallAnswered,
            questionID: " \n\t ",
            wasCorrect: true
        )))
        XCTAssertFalse(ProgressMigration.hasValidMetadata(legacyEvent(
            kind: .recallAnswered,
            questionID: "question-1",
            wasCorrect: nil
        )))

        for kind in [LegacyStageEventKind.deepLessonViewed, .modifyPassed] {
            XCTAssertTrue(ProgressMigration.hasValidMetadata(legacyEvent(kind: kind)))
            XCTAssertFalse(ProgressMigration.hasValidMetadata(legacyEvent(
                kind: kind,
                questionID: "not-allowed"
            )))
            XCTAssertFalse(ProgressMigration.hasValidMetadata(legacyEvent(
                kind: kind,
                wasCorrect: true
            )))
        }
    }

    func testFirstLegacyLogicalEventWins() {
        let firstDate = Date(timeIntervalSinceReferenceDate: 10)
        let laterDate = Date(timeIntervalSinceReferenceDate: 20)
        let firstDeep = legacyEvent(kind: .deepLessonViewed, timestamp: firstDate)
        let firstRecall = legacyEvent(
            kind: .recallAnswered,
            timestamp: firstDate,
            questionID: "question-1",
            wasCorrect: false
        )
        let secondRecall = legacyEvent(
            kind: .recallAnswered,
            timestamp: laterDate,
            questionID: "question-2",
            wasCorrect: true
        )

        let unique = ProgressMigration.firstUniqueLegacyEvents(from: [
            firstDeep,
            legacyEvent(kind: .deepLessonViewed, timestamp: laterDate),
            firstRecall,
            legacyEvent(
                kind: .recallAnswered,
                timestamp: laterDate,
                questionID: "question-1",
                wasCorrect: true
            ),
            secondRecall
        ])

        XCTAssertEqual(unique, [firstDeep, firstRecall, secondRecall])
    }

    func testCanonicalLegacyEventID() throws {
        let wholeSecondEvent = legacyEvent(kind: .deepLessonViewed)
        let fractionalEvent = legacyEvent(
            kind: .deepLessonViewed,
            timestamp: Date(timeIntervalSinceReferenceDate: 0.123456789)
        )

        XCTAssertEqual(
            try XCTUnwrap(ProgressMigration.legacyEventID(for: wholeSecondEvent)).rawValue,
            "legacy-v2|swift-development|1|deepLessonViewed|-|978307200000"
        )
        XCTAssertTrue(
            try XCTUnwrap(ProgressMigration.legacyEventID(for: fractionalEvent)).rawValue
                .hasSuffix("|978307200123")
        )
    }

    func testLegacyEventConversion() throws {
        let timestamp = Date(timeIntervalSinceReferenceDate: 42.5)
        let legacy = legacyEvent(
            lessonID: 7,
            kind: .recallAnswered,
            timestamp: timestamp,
            questionID: "question-7",
            wasCorrect: false
        )

        let converted = try XCTUnwrap(ProgressMigration.courseEvent(from: legacy))

        XCTAssertEqual(converted.id, try XCTUnwrap(ProgressMigration.legacyEventID(for: legacy)))
        XCTAssertEqual(converted.lessonLocalID, LessonLocalID(rawValue: "7"))
        XCTAssertEqual(converted.kind, .recallAnswered)
        XCTAssertEqual(converted.timestamp, timestamp)
        XCTAssertEqual(converted.questionID, "question-7")
        XCTAssertEqual(converted.wasCorrect, false)
    }

    func testVersionTwoDocumentMapping() throws {
        let document = try migratedDocument(
            from: ProgressMigration.decode(data: fixtureData("version-2-progress")),
            sourceVersion: 2
        )

        let swiftProgress = try XCTUnwrap(document.courses[.swiftDevelopment])
        XCTAssertEqual(swiftProgress.completedLessonLocalIDs, [LessonLocalID(rawValue: "2")])
        XCTAssertEqual(
            swiftProgress.stageEvents,
            [
                CourseStageEvent(
                    id: ProgressEventID(
                        rawValue: "legacy-v2|swift-development|1|deepLessonViewed|-|978307200000"
                    ),
                    lessonLocalID: LessonLocalID(rawValue: "1"),
                    kind: .deepLessonViewed,
                    timestamp: Date(timeIntervalSinceReferenceDate: 0),
                    questionID: nil,
                    wasCorrect: nil
                )
            ]
        )
        XCTAssertEqual(swiftProgress.presentationStates, [:])
    }

    func testVersionTwoDropsOnlyInvalidEventsAndKeepsFirstDuplicate() throws {
        let data = Data(
            #"""
            {
              "version": 2,
              "completedLessonIDs": [8],
              "stageEvents": [
                {"lessonID":8,"kind":"deepLessonViewed","timestamp":0},
                {"lessonID":8,"kind":"modifyPassed","timestamp":"bad"},
                {"lessonID":8,"kind":"futureKind","timestamp":0},
                {"lessonID":8,"kind":"modifyPassed","timestamp":0,"questionID":"not-allowed"},
                {"lessonID":8,"kind":"deepLessonViewed","timestamp":10},
                {"lessonID":8,"kind":"recallAnswered","timestamp":1,"questionID":"q-1","wasCorrect":false},
                {"lessonID":8,"kind":"recallAnswered","timestamp":2,"questionID":"q-1","wasCorrect":true},
                {"lessonID":8,"kind":"recallAnswered","timestamp":3,"questionID":"q-2","wasCorrect":true},
                {"lessonID":8,"kind":"recallAnswered","timestamp":4,"questionID":"  ","wasCorrect":true}
              ]
            }
            """#.utf8
        )

        let document = try migratedDocument(
            from: ProgressMigration.decode(data: data),
            sourceVersion: 2
        )
        let events = try XCTUnwrap(document.courses[.swiftDevelopment]?.stageEvents)

        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].kind, .deepLessonViewed)
        XCTAssertEqual(events[0].timestamp, Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertEqual(
            events[0].id.rawValue,
            "legacy-v2|swift-development|8|deepLessonViewed|-|978307200000"
        )
        XCTAssertEqual(events[1].questionID, "q-1")
        XCTAssertEqual(events[1].wasCorrect, false)
        XCTAssertEqual(events[1].timestamp, Date(timeIntervalSinceReferenceDate: 1))
        XCTAssertEqual(events[2].questionID, "q-2")
    }

    func testVersionTwoFractionalDatePreservesExactTimestamp() throws {
        let timestamp = Date(timeIntervalSinceReferenceDate: 0.123456789)
        let data = Data(
            #"{"version":2,"completedLessonIDs":[],"stageEvents":[{"lessonID":1,"kind":"deepLessonViewed","timestamp":0.123456789}]}"#.utf8
        )
        let document = try migratedDocument(
            from: ProgressMigration.decode(data: data),
            sourceVersion: 2
        )
        XCTAssertEqual(
            document.courses[.swiftDevelopment]?.stageEvents.first?.timestamp,
            timestamp
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = ProgressDateCoding.encodingStrategy
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ProgressDateCoding.decodingStrategy
        let roundTripped = try decoder.decode(
            ProgressDocument.self,
            from: encoder.encode(document)
        )

        XCTAssertEqual(
            roundTripped.courses[.swiftDevelopment]?.stageEvents.first?.timestamp,
            timestamp
        )
    }

    func testVersionTwoDropsUnrepresentableTimestampWithoutTrapping() throws {
        let data = Data(
            #"{"version":2,"completedLessonIDs":[1],"stageEvents":[{"lessonID":1,"kind":"deepLessonViewed","timestamp":1e300}]}"#.utf8
        )

        let document = try migratedDocument(
            from: ProgressMigration.decode(data: data),
            sourceVersion: 2
        )
        let swiftProgress = try XCTUnwrap(document.courses[.swiftDevelopment])

        XCTAssertEqual(swiftProgress.completedLessonLocalIDs, [LessonLocalID(rawValue: "1")])
        XCTAssertEqual(swiftProgress.stageEvents, [])
    }

    func testVersionTwoUnrepresentableEventDoesNotReserveDedupeKey() throws {
        let data = Data(
            #"{"version":2,"completedLessonIDs":[],"stageEvents":[{"lessonID":1,"kind":"deepLessonViewed","timestamp":1e300},{"lessonID":1,"kind":"deepLessonViewed","timestamp":0}]}"#.utf8
        )

        let document = try migratedDocument(
            from: ProgressMigration.decode(data: data),
            sourceVersion: 2
        )
        let event = try XCTUnwrap(
            document.courses[.swiftDevelopment]?.stageEvents.first
        )

        XCTAssertEqual(
            event.id.rawValue,
            "legacy-v2|swift-development|1|deepLessonViewed|-|978307200000"
        )
        XCTAssertEqual(event.timestamp, Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertEqual(document.courses[.swiftDevelopment]?.stageEvents.count, 1)
    }

    func testCurrentVersionThreeResult() throws {
        let data = try fixtureData("version-3-progress")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ProgressDateCoding.decodingStrategy
        let expected = try decoder.decode(ProgressDocument.self, from: data)

        let result = ProgressMigration.decode(data: data)

        XCTAssertEqual(result, .current(expected))
    }

    func testFutureVersionSkipsPayloadDecode() {
        let exactBytes = Data(
            #"{ "version":4,"payload":"not decodable by this app" }"#.utf8
        )

        let result = ProgressMigration.decode(data: exactBytes)

        XCTAssertEqual(
            result,
            .unsupportedFuture(version: 4, originalData: exactBytes)
        )
    }

    func testExplicitNullVersionIsCorruptVersionOne() {
        let exactBytes = Data(
            #"{ "version": null, "completedLessonIDs": [1] }"#.utf8
        )

        let result = ProgressMigration.decode(data: exactBytes)

        guard case let .corruptSupported(version, originalData, reason) = result else {
            return XCTFail("Expected corrupt v1 result, got \(result)")
        }
        XCTAssertEqual(version, 1)
        XCTAssertEqual(originalData, exactBytes)
        XCTAssertFalse(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testCorruptSupportedVersionsPreserveBytes() {
        let cases: [(version: Int, data: Data)] = [
            (1, Data(#"{"completedLessonIDs":"not-an-array"}"#.utf8)),
            (2, Data(#"{"version":2,"completedLessonIDs":[],"stageEvents":"not-an-array"}"#.utf8)),
            (3, Data(#"{"version":3,"courses":"not-an-object"}"#.utf8))
        ]

        for testCase in cases {
            let result = ProgressMigration.decode(data: testCase.data)
            guard case let .corruptSupported(version, originalData, reason) = result else {
                XCTFail("Expected corrupt v\(testCase.version), got \(result)")
                continue
            }

            XCTAssertEqual(version, testCase.version)
            XCTAssertEqual(originalData, testCase.data)
            XCTAssertFalse(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Fixtures"
        ))
        return try Data(contentsOf: url)
    }

    private func migratedDocument(
        from result: ProgressLoadResult,
        sourceVersion expectedSourceVersion: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> ProgressDocument {
        guard case let .migrated(sourceVersion, document) = result else {
            XCTFail("Expected migrated document, got \(result)", file: file, line: line)
            throw MigrationTestError.unexpectedResult
        }
        XCTAssertEqual(sourceVersion, expectedSourceVersion, file: file, line: line)
        return document
    }

    private func legacyEvent(
        lessonID: Int = 1,
        kind: LegacyStageEventKind,
        timestamp: Date = Date(timeIntervalSinceReferenceDate: 0),
        questionID: String? = nil,
        wasCorrect: Bool? = nil
    ) -> LegacyStageEvent {
        LegacyStageEvent(
            lessonID: lessonID,
            kind: kind,
            timestamp: timestamp,
            questionID: questionID,
            wasCorrect: wasCorrect
        )
    }

    private enum MigrationTestError: Error {
        case unexpectedResult
    }
}
