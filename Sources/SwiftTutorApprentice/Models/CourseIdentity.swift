import Foundation

struct CourseID: RawRepresentable, Hashable, Codable, Identifiable {
    let rawValue: String

    var id: String { rawValue }

    static let swiftDevelopment = Self(rawValue: "swift-development")
    static let webDevelopment = Self(rawValue: "web-development")
    static let cybersecurity = Self(rawValue: "cybersecurity")
    static let networking = Self(rawValue: "networking")
}

struct LessonLocalID: RawRepresentable, Hashable, Codable {
    let rawValue: String
}

struct LessonKey: Hashable, Codable, Identifiable {
    let courseID: CourseID
    let localID: LessonLocalID

    var id: String { "\(courseID.rawValue):\(localID.rawValue)" }

    static func swift(_ legacyID: Int) -> Self {
        Self(
            courseID: .swiftDevelopment,
            localID: LessonLocalID(rawValue: String(legacyID))
        )
    }
}

struct ModuleID: RawRepresentable, Hashable, Codable, Identifiable {
    let rawValue: String

    var id: String { rawValue }
}

struct ObjectiveSetID: RawRepresentable, Hashable, Codable {
    let rawValue: String
}

struct CourseLesson: Identifiable {
    let key: LessonKey
    let lesson: Lesson

    var id: LessonKey { key }
}
