enum InstructionalBand: String, Codable {
    case orientation
    case foundations
    case application
    case mastery
    case projects
    case certificationPreparation
}

struct CourseModule: Identifiable, Hashable {
    let id: ModuleID
    let title: String
    let band: InstructionalBand
    let orderedLessonLocalIDs: [LessonLocalID]
}

protocol CourseContentProvider {
    var courseID: CourseID { get }
    var modules: [CourseModule] { get }

    func lessons(in moduleID: ModuleID) -> [CourseLesson]
    func lesson(for key: LessonKey) -> CourseLesson?
    func contains(_ key: LessonKey) -> Bool
}

enum CourseContentError: Error, Equatable {
    case unknownCourse(CourseID)
    case comingNext(CourseID)
    case contentUnavailable(CourseID)
}

struct CourseContentRegistry {
    private let providers: [CourseID: any CourseContentProvider]

    init(providers: [CourseID: any CourseContentProvider]) {
        self.providers = providers.filter { courseID, provider in
            provider.courseID == courseID
        }
    }

    func provider(for courseID: CourseID) throws -> any CourseContentProvider {
        guard let definition = CourseCatalog.default[courseID] else {
            throw CourseContentError.unknownCourse(courseID)
        }

        switch definition.availability {
        case .comingNext:
            throw CourseContentError.comingNext(courseID)
        case .available:
            guard let provider = providers[courseID] else {
                throw CourseContentError.contentUnavailable(courseID)
            }
            return provider
        case .contentUnavailable:
            throw CourseContentError.contentUnavailable(courseID)
        }
    }
}
