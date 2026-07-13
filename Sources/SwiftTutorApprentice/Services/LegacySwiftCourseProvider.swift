final class LegacySwiftCourseProvider: CourseContentProvider {
    let courseID = CourseID.swiftDevelopment

    private let store: LessonStore
    private let moduleID = ModuleID(rawValue: "swift-current")

    init(store: LessonStore) {
        self.store = store
    }

    var modules: [CourseModule] {
        [
            CourseModule(
                id: moduleID,
                title: "Swift Foundations",
                band: .foundations,
                orderedLessonLocalIDs: store.lessons.map {
                    LessonLocalID(rawValue: String($0.id))
                }
            )
        ]
    }

    func lessons(in moduleID: ModuleID) -> [CourseLesson] {
        guard moduleID == self.moduleID else { return [] }
        return store.lessons.map { lesson in
            CourseLesson(key: .swift(lesson.id), lesson: lesson)
        }
    }

    func lesson(for key: LessonKey) -> CourseLesson? {
        guard key.courseID == courseID,
              let legacyID = Int(key.localID.rawValue),
              key.localID.rawValue == String(legacyID),
              let lesson = store.lesson(id: legacyID)
        else {
            return nil
        }

        return CourseLesson(key: .swift(lesson.id), lesson: lesson)
    }

    func contains(_ key: LessonKey) -> Bool {
        lesson(for: key) != nil
    }
}
