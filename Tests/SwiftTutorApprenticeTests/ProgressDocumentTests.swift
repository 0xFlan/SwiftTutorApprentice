import Foundation
import XCTest
@testable import SwiftTutorApprentice

final class ProgressDocumentTests: XCTestCase {
    func testStringIdentitiesRoundTripRawValues() throws {
        try assertStringIdentityRoundTrip(ProgressEventID(rawValue: "event-1"), expected: "event-1")
        try assertStringIdentityRoundTrip(ActivityID(rawValue: "activity-1"), expected: "activity-1")
        try assertStringIdentityRoundTrip(ItemVariantID(rawValue: "variant-1"), expected: "variant-1")
        try assertStringIdentityRoundTrip(AttemptID(rawValue: "attempt-1"), expected: "attempt-1")
        try assertStringIdentityRoundTrip(ObjectiveID(rawValue: "3.1"), expected: "3.1")
        try assertStringIdentityRoundTrip(ReviewID(rawValue: "review-1"), expected: "review-1")
        try assertStringIdentityRoundTrip(MasteryPolicyVersion(rawValue: "policy-1"), expected: "policy-1")
    }

    func testCourseStageEventRoundTripsAllFields() throws {
        let event = CourseStageEvent(
            id: ProgressEventID(rawValue: "event-1"),
            lessonLocalID: LessonLocalID(rawValue: "1"),
            kind: .recallAnswered,
            timestamp: Date(timeIntervalSince1970: 100),
            questionID: "recall-1",
            wasCorrect: false
        )

        let decoded = try JSONDecoder().decode(
            CourseStageEvent.self,
            from: JSONEncoder().encode(event)
        )

        XCTAssertEqual(decoded, event)
    }

    func testLessonPresentationStateRepresentsIntentionalNotStartedState() throws {
        let state = LessonPresentationState(
            status: .notStarted,
            lastSceneID: nil,
            presentationRevision: 1,
            firstStartedAt: nil,
            lastOpenedAt: nil,
            replayCount: 0
        )

        let decoded = try JSONDecoder().decode(
            LessonPresentationState.self,
            from: JSONEncoder().encode(state)
        )

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.status, .notStarted)
        XCTAssertNil(decoded.lastSceneID)
        XCTAssertNil(decoded.firstStartedAt)
        XCTAssertNil(decoded.lastOpenedAt)
        XCTAssertEqual(decoded.presentationRevision, 1)
        XCTAssertEqual(decoded.replayCount, 0)
    }

    func testLessonPresentationStateDecodesLegacyWireWithoutPresentationID() throws {
        let data = Data(#"{"status":"started","lastSceneID":"scene-2","presentationRevision":3,"replayCount":1}"#.utf8)

        let decoded = try JSONDecoder().decode(LessonPresentationState.self, from: data)

        XCTAssertNil(decoded.presentationID)
        XCTAssertEqual(decoded.lastSceneID, "scene-2")
        XCTAssertEqual(decoded.presentationRevision, 3)
    }

    func testLessonPresentationStateRoundTripsPresentationIDOnExactWireObject() throws {
        let state = LessonPresentationState(
            status: .started,
            lastSceneID: "scene-1",
            presentationRevision: 3,
            firstStartedAt: nil,
            lastOpenedAt: nil,
            replayCount: 0,
            presentationID: "presentation-v2"
        )

        let encoded = try JSONEncoder().encode(state)
        let wire = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(wire["presentationID"] as? String, "presentation-v2")
        XCTAssertEqual(try JSONDecoder().decode(LessonPresentationState.self, from: encoded), state)
    }

    func testVersionThreeRoundTrip() throws {
        let mapping = ObjectiveMapping(
            conceptID: ConceptID(rawValue: "swift.lesson-1.string-literal"),
            objectiveSetID: ObjectiveSetID(rawValue: "swift-associate-2024"),
            objectiveID: ObjectiveID(rawValue: "3.1")
        )
        let attempt = AssessmentAttempt(
            id: AttemptID(rawValue: "attempt-1"),
            lessonKey: .swift(1),
            activityID: ActivityID(rawValue: "swift.lesson-1.ai-review"),
            itemVariantID: ItemVariantID(rawValue: "v1"),
            conceptIDs: [mapping.conceptID],
            objectiveMappings: [mapping],
            scaffoldLevel: .none,
            result: .passed,
            contentRevision: 1,
            wasPreviouslySeen: false,
            submittedAt: Date(timeIntervalSince1970: 100)
        )
        let review = ReviewRecord(
            id: ReviewID(rawValue: "review-1"),
            conceptID: mapping.conceptID,
            createdAt: Date(timeIntervalSince1970: 200),
            dueAt: Date(timeIntervalSince1970: 300),
            policyVersion: MasteryPolicyVersion(rawValue: "policy-1"),
            sourceEvidenceAttemptIDs: [attempt.id],
            satisfyingAttemptID: attempt.id
        )
        let snapshot = ReadinessSnapshot(
            objectiveSetID: mapping.objectiveSetID,
            policyVersion: review.policyVersion,
            calculatedAt: Date(timeIntervalSince1970: 400),
            evidenceAttemptIDs: [attempt.id]
        )
        let course = CourseProgressDocument(
            completedLessonLocalIDs: [LessonLocalID(rawValue: "1")],
            stageEvents: [],
            presentationStates: [:],
            assessmentAttempts: [attempt],
            reviews: [review],
            lastLessonLocalID: LessonLocalID(rawValue: "1"),
            readinessSnapshots: [snapshot]
        )
        let document = ProgressDocument(
            version: ProgressDocument.currentVersion,
            courses: [.swiftDevelopment: course]
        )

        let decoded = try JSONDecoder().decode(
            ProgressDocument.self,
            from: JSONEncoder().encode(document)
        )

        XCTAssertEqual(decoded, document)
    }

    func testVersionThreeUsesObjectCourseKeys() throws {
        let document = ProgressDocument(
            version: ProgressDocument.currentVersion,
            courses: [.swiftDevelopment: CourseProgressDocument()]
        )

        let encoded = try JSONEncoder().encode(document)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        let courses = try XCTUnwrap(object["courses"] as? [String: Any])

        XCTAssertNotNil(courses["swift-development"])

        let courseData = try JSONEncoder().encode(CourseProgressDocument())
        let courseObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: courseData) as? [String: Any]
        )
        let invalidData = try JSONSerialization.data(withJSONObject: [
            "version": ProgressDocument.currentVersion,
            "courses": ["": courseObject]
        ])

        XCTAssertThrowsError(
            try JSONDecoder().decode(ProgressDocument.self, from: invalidData)
        )
    }

    func testEncodingRejectsEmptyCourseKey() {
        let document = ProgressDocument(
            version: ProgressDocument.currentVersion,
            courses: [CourseID(rawValue: ""): CourseProgressDocument()]
        )

        XCTAssertThrowsError(try JSONEncoder().encode(document))
    }

    func testVersionThreeUsesObjectPresentationStateKeys() throws {
        let state = LessonPresentationState(
            status: .notStarted,
            lastSceneID: nil,
            presentationRevision: 1,
            firstStartedAt: nil,
            lastOpenedAt: nil,
            replayCount: 0
        )
        let course = CourseProgressDocument(
            presentationStates: [LessonLocalID(rawValue: "1"): state]
        )

        let encoded = try JSONEncoder().encode(course)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        let presentationStates = try XCTUnwrap(
            object["presentationStates"] as? [String: Any]
        )

        XCTAssertNotNil(presentationStates["1"])

        var invalidObject = object
        invalidObject["presentationStates"] = ["": try XCTUnwrap(presentationStates["1"])]
        let invalidData = try JSONSerialization.data(withJSONObject: invalidObject)

        XCTAssertThrowsError(
            try JSONDecoder().decode(CourseProgressDocument.self, from: invalidData)
        )
    }

    func testEncodingRejectsEmptyPresentationStateKey() {
        let state = LessonPresentationState(
            status: .notStarted,
            lastSceneID: nil,
            presentationRevision: 1,
            firstStartedAt: nil,
            lastOpenedAt: nil,
            replayCount: 0
        )
        let course = CourseProgressDocument(
            presentationStates: [LessonLocalID(rawValue: ""): state]
        )

        XCTAssertThrowsError(try JSONEncoder().encode(course))
    }

    func testExactFractionalTimestamp() throws {
        let timestamp = Date(timeIntervalSinceReferenceDate: 0.123456789)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = ProgressDateCoding.encodingStrategy
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ProgressDateCoding.decodingStrategy

        let encoded = try encoder.encode(timestamp)
        let decoded = try decoder.decode(Date.self, from: encoded)
        let wireDate = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        let iso8601 = try XCTUnwrap(wireDate["iso8601"] as? String)
        let referenceSeconds = try XCTUnwrap(wireDate["referenceSeconds"] as? Double)

        XCTAssertEqual(decoded, timestamp)
        XCTAssertTrue(iso8601.hasPrefix("2001-01-01T00:00:00."))
        XCTAssertTrue(iso8601.hasSuffix("Z"))
        XCTAssertEqual(referenceSeconds, timestamp.timeIntervalSinceReferenceDate)

        let wholeSecondData = Data(#""2001-01-01T00:00:00Z""#.utf8)
        XCTAssertEqual(
            try decoder.decode(Date.self, from: wholeSecondData),
            Date(timeIntervalSinceReferenceDate: 0)
        )
    }

    func testDecodesStandaloneFractionalISO8601String() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ProgressDateCoding.decodingStrategy
        let data = Data(#""2001-01-01T00:00:00.123Z""#.utf8)

        let decoded = try decoder.decode(Date.self, from: data)

        XCTAssertEqual(decoded, Date(timeIntervalSince1970: 978_307_200.123))
    }

    func testWireDateRejectsMalformedISO8601DespiteValidReferenceSeconds() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ProgressDateCoding.decodingStrategy
        let data = Data(
            #"{"iso8601":"not-a-date","referenceSeconds":0}"#.utf8
        )

        XCTAssertThrowsError(try decoder.decode(Date.self, from: data))
    }

    func testVersionThreeLiteralFixtureRoundTripsExactly() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(
                forResource: "version-3-progress",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        )
        let fixtureData = try Data(contentsOf: fixtureURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ProgressDateCoding.decodingStrategy
        let document = try decoder.decode(ProgressDocument.self, from: fixtureData)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = ProgressDateCoding.encodingStrategy
        encoder.outputFormatting = [.sortedKeys]
        let reencodedData = try encoder.encode(document)

        let fixtureObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: fixtureData) as? NSDictionary
        )
        let reencodedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: reencodedData) as? NSDictionary
        )

        XCTAssertEqual(document.version, ProgressDocument.currentVersion)
        XCTAssertEqual(fixtureObject, reencodedObject)
    }

    private func assertStringIdentityRoundTrip<ID>(
        _ identity: ID,
        expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws where ID: RawRepresentable & Codable & Equatable, ID.RawValue == String {
        let encoded = try JSONEncoder().encode(identity)
        let decoded = try JSONDecoder().decode(ID.self, from: encoded)

        XCTAssertEqual(decoded, identity, file: file, line: line)
        XCTAssertEqual(decoded.rawValue, expected, file: file, line: line)
    }
}
