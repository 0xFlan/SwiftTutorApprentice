import XCTest
@testable import SwiftTutorApprentice

final class CourseHomeCardModelTests: XCTestCase {
    func testReleasedSwiftProjectsTruthfulCompletionAndDestination() throws {
        let definition = try XCTUnwrap(CourseCatalog.default[.swiftDevelopment])
        let provider = CardCourseProvider(courseID: .swiftDevelopment, lessonIDs: [1, 2, 3])
        var progress = CourseProgressDocument()
        progress.completedLessonLocalIDs = [LessonLocalID(rawValue: "1")]
        let destination = CourseDestination(label: .continue, lessonKey: .swift(2))

        let card = CourseHomeCardModel(
            course: definition,
            provider: provider,
            progress: progress,
            destination: destination
        )

        XCTAssertEqual(card.id, .swiftDevelopment)
        XCTAssertEqual(card.progressText, "1 of 3 lessons complete")
        XCTAssertEqual(card.primaryActionLabel, "Continue")
        XCTAssertEqual(card.destination, .swift(2))
        XCTAssertTrue(card.isPrimaryActionEnabled)
        XCTAssertEqual(card.availabilityText, "Available")
        XCTAssertTrue(card.targetCredentialText.contains("App Development with Swift Associate"))
    }

    func testReleasedSwiftUsesOnlyReleasedLessonIDsAndDerivedActionLabel() throws {
        let definition = try XCTUnwrap(CourseCatalog.default[.swiftDevelopment])
        let provider = CardCourseProvider(courseID: .swiftDevelopment, lessonIDs: [1, 2])
        var progress = CourseProgressDocument()
        progress.completedLessonLocalIDs = [
            LessonLocalID(rawValue: "1"),
            LessonLocalID(rawValue: "retired-lesson")
        ]

        for label in [CourseActionLabel.start, .continue, .review] {
            let card = CourseHomeCardModel(
                course: definition,
                provider: provider,
                progress: progress,
                destination: CourseDestination(label: label, lessonKey: .swift(1))
            )
            XCTAssertEqual(card.progressText, "1 of 2 lessons complete")
            XCTAssertEqual(card.primaryActionLabel, label.rawValue)
        }
    }

    func testComingNextCardsShowTargetsWithoutProgressOrReadinessClaims() throws {
        for courseID in [CourseID.webDevelopment, .cybersecurity, .networking] {
            let definition = try XCTUnwrap(CourseCatalog.default[courseID])
            var progress = CourseProgressDocument()
            progress.completedLessonLocalIDs = [LessonLocalID(rawValue: "1")]

            let card = CourseHomeCardModel(
                course: definition,
                provider: nil,
                progress: progress,
                destination: nil
            )

            XCTAssertEqual(card.availabilityText, "Coming next")
            XCTAssertEqual(card.primaryActionLabel, "Coming next")
            XCTAssertFalse(card.isPrimaryActionEnabled)
            XCTAssertNil(card.progressText)
            XCTAssertNil(card.destination)
            XCTAssertFalse(card.targetCredentialText.isEmpty)
            XCTAssertTrue(
                card.targetCredentialText.contains(definition.certificationTargets[0].credentialName)
            )
        }
    }

    func testCardsContainNoUnsupportedMotivationOrOutcomeClaims() {
        let forbidden = [
            "leaderboard", "streak-loss", "mastery",
            "guaranteed job", "guaranteed certification", "ready for certification",
            "%"
        ]

        for definition in CourseCatalog.default.definitions {
            let provider: (any CourseContentProvider)? = definition.id == .swiftDevelopment
                ? CardCourseProvider(courseID: .swiftDevelopment, lessonIDs: [1, 2, 3])
                : nil
            let destination = provider.map { _ in
                CourseDestination(label: .start, lessonKey: .swift(1))
            }
            let card = CourseHomeCardModel(
                course: definition,
                provider: provider,
                progress: CourseProgressDocument(),
                destination: destination
            )
            let allText = card.displayText.joined(separator: " ").lowercased()

            for phrase in forbidden {
                XCTAssertFalse(allText.contains(phrase), "\(definition.id.rawValue) contains \(phrase)")
            }
            let words = allText.split { !$0.isLetter && !$0.isNumber }.map(String.init)
            XCTAssertFalse(words.contains("xp"), "\(definition.id.rawValue) contains XP")
        }
    }
}

private struct CardCourseProvider: CourseContentProvider {
    let courseID: CourseID
    let modules: [CourseModule]

    init(courseID: CourseID, lessonIDs: [Int]) {
        self.courseID = courseID
        modules = [
            CourseModule(
                id: ModuleID(rawValue: "released"),
                title: "Released",
                band: .foundations,
                orderedLessonLocalIDs: lessonIDs.map { LessonLocalID(rawValue: String($0)) }
            )
        ]
    }

    func lessons(in moduleID: ModuleID) -> [CourseLesson] { [] }
    func lesson(for key: LessonKey) -> CourseLesson? { nil }
    func contains(_ key: LessonKey) -> Bool {
        key.courseID == courseID
            && modules.flatMap(\.orderedLessonLocalIDs).contains(key.localID)
    }
}
