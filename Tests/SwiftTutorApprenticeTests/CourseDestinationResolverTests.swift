import XCTest
@testable import SwiftTutorApprentice

final class CourseDestinationResolverTests: XCTestCase {
    private let orderedLessons: [LessonKey] = [.swift(1), .swift(2), .swift(3)]

    func testNoMeaningfulActivityStartsAtFirstLessonEvenWhenLastLessonExists() {
        let destination = CourseDestinationResolver.resolve(
            orderedLessons: orderedLessons,
            completed: [],
            lastLesson: .swift(3),
            hasMeaningfulActivity: false
        )

        XCTAssertEqual(
            destination,
            CourseDestination(label: .start, lessonKey: .swift(1))
        )
    }

    func testMeaningfulActivityContinuesAtIncompleteValidLastLesson() {
        XCTAssertEqual(
            resolve(completed: [.swift(1)], lastLesson: .swift(2)),
            CourseDestination(label: .continue, lessonKey: .swift(2))
        )
    }

    func testCompletedValidLastLessonContinuesAtFirstIncompleteLessonAfterIt() {
        XCTAssertEqual(
            resolve(completed: [.swift(2)], lastLesson: .swift(2)),
            CourseDestination(label: .continue, lessonKey: .swift(3))
        )
    }

    func testCompletedLastLessonAtEndWrapsOnceToFirstIncompleteLesson() {
        XCTAssertEqual(
            resolve(completed: [.swift(2), .swift(3)], lastLesson: .swift(3)),
            CourseDestination(label: .continue, lessonKey: .swift(1))
        )
    }

    func testInvalidLastLessonContinuesAtFirstIncompleteLessonInCourseOrder() {
        XCTAssertEqual(
            resolve(completed: [.swift(1)], lastLesson: .swift(99)),
            CourseDestination(label: .continue, lessonKey: .swift(2))
        )
    }

    func testNilLastLessonContinuesAtFirstIncompleteLessonInCourseOrder() {
        XCTAssertEqual(
            resolve(completed: [.swift(1)], lastLesson: nil),
            CourseDestination(label: .continue, lessonKey: .swift(2))
        )
    }

    func testAllReleasedLessonsCompleteReviewsValidStoredLastLesson() {
        XCTAssertEqual(
            resolve(completed: Set(orderedLessons), lastLesson: .swift(2)),
            CourseDestination(label: .review, lessonKey: .swift(2))
        )
    }

    func testAllReleasedLessonsCompleteReviewsFirstLessonWhenLastIsInvalidOrNil() {
        for lastLesson in [LessonKey.swift(99), nil] {
            XCTAssertEqual(
                resolve(completed: Set(orderedLessons), lastLesson: lastLesson),
                CourseDestination(label: .review, lessonKey: .swift(1))
            )
        }
    }

    func testEmptyReleasedLessonListReturnsNil() {
        XCTAssertNil(
            CourseDestinationResolver.resolve(
                orderedLessons: [],
                completed: [.swift(1)],
                lastLesson: .swift(1),
                hasMeaningfulActivity: true
            )
        )
    }

    private func resolve(
        completed: Set<LessonKey>,
        lastLesson: LessonKey?
    ) -> CourseDestination? {
        CourseDestinationResolver.resolve(
            orderedLessons: orderedLessons,
            completed: completed,
            lastLesson: lastLesson,
            hasMeaningfulActivity: true
        )
    }
}
