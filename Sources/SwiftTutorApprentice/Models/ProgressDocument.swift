import Foundation

struct WireDate: Codable {
    let iso8601: String
    let referenceSeconds: Double
}

enum ProgressDateCoding {
    static let encodingStrategy: JSONEncoder.DateEncodingStrategy = .custom { date, encoder in
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try WireDate(
            iso8601: formatter.string(from: date),
            referenceSeconds: date.timeIntervalSinceReferenceDate
        ).encode(to: encoder)
    }

    static let decodingStrategy: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        if let wireDate = try? WireDate(from: decoder) {
            guard parseISO8601(wireDate.iso8601) != nil else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Invalid ISO 8601 date: \(wireDate.iso8601)"
                    )
                )
            }
            return Date(timeIntervalSinceReferenceDate: wireDate.referenceSeconds)
        }

        let container = try decoder.singleValueContainer()
        let iso8601 = try container.decode(String.self)
        guard let date = parseISO8601(iso8601) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO 8601 date: \(iso8601)"
            )
        }
        return date
    }

    private static func parseISO8601(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let wholeSecondFormatter = ISO8601DateFormatter()
        wholeSecondFormatter.formatOptions = [.withInternetDateTime]
        return wholeSecondFormatter.date(from: value)
    }
}

struct CourseProgressDocument: Codable, Equatable {
    var completedLessonLocalIDs: Set<LessonLocalID> = []
    var stageEvents: [CourseStageEvent] = []
    var presentationStates: [LessonLocalID: LessonPresentationState] = [:]
    var assessmentAttempts: [AssessmentAttempt] = []
    var reviews: [ReviewRecord] = []
    var lastLessonLocalID: LessonLocalID?
    var readinessSnapshots: [ReadinessSnapshot] = []

    private enum CodingKeys: String, CodingKey {
        case completedLessonLocalIDs
        case stageEvents
        case presentationStates
        case assessmentAttempts
        case reviews
        case lastLessonLocalID
        case readinessSnapshots
    }

    init(
        completedLessonLocalIDs: Set<LessonLocalID> = [],
        stageEvents: [CourseStageEvent] = [],
        presentationStates: [LessonLocalID: LessonPresentationState] = [:],
        assessmentAttempts: [AssessmentAttempt] = [],
        reviews: [ReviewRecord] = [],
        lastLessonLocalID: LessonLocalID? = nil,
        readinessSnapshots: [ReadinessSnapshot] = []
    ) {
        self.completedLessonLocalIDs = completedLessonLocalIDs
        self.stageEvents = stageEvents
        self.presentationStates = presentationStates
        self.assessmentAttempts = assessmentAttempts
        self.reviews = reviews
        self.lastLessonLocalID = lastLessonLocalID
        self.readinessSnapshots = readinessSnapshots
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        completedLessonLocalIDs = try container.decode(
            Set<LessonLocalID>.self,
            forKey: .completedLessonLocalIDs
        )
        stageEvents = try container.decode([CourseStageEvent].self, forKey: .stageEvents)

        let rawPresentationStates = try container.decode(
            [String: LessonPresentationState].self,
            forKey: .presentationStates
        )
        guard rawPresentationStates.keys.allSatisfy(Self.isValidRawKey) else {
            throw DecodingError.dataCorruptedError(
                forKey: .presentationStates,
                in: container,
                debugDescription: "Presentation state keys must not be empty"
            )
        }
        presentationStates = Dictionary(
            uniqueKeysWithValues: rawPresentationStates.map {
                (LessonLocalID(rawValue: $0.key), $0.value)
            }
        )

        assessmentAttempts = try container.decode(
            [AssessmentAttempt].self,
            forKey: .assessmentAttempts
        )
        reviews = try container.decode([ReviewRecord].self, forKey: .reviews)
        lastLessonLocalID = try container.decodeIfPresent(
            LessonLocalID.self,
            forKey: .lastLessonLocalID
        )
        readinessSnapshots = try container.decode(
            [ReadinessSnapshot].self,
            forKey: .readinessSnapshots
        )
    }

    func encode(to encoder: Encoder) throws {
        guard presentationStates.keys.allSatisfy({ Self.isValidRawKey($0.rawValue) }) else {
            throw EncodingError.invalidValue(
                presentationStates,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Presentation state keys must not be empty"
                )
            )
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(completedLessonLocalIDs, forKey: .completedLessonLocalIDs)
        try container.encode(stageEvents, forKey: .stageEvents)
        try container.encode(
            Dictionary(
                uniqueKeysWithValues: presentationStates.map {
                    ($0.key.rawValue, $0.value)
                }
            ),
            forKey: .presentationStates
        )
        try container.encode(assessmentAttempts, forKey: .assessmentAttempts)
        try container.encode(reviews, forKey: .reviews)
        try container.encodeIfPresent(lastLessonLocalID, forKey: .lastLessonLocalID)
        try container.encode(readinessSnapshots, forKey: .readinessSnapshots)
    }

    private static func isValidRawKey(_ rawKey: String) -> Bool {
        !rawKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ProgressDocument: Codable, Equatable {
    static let currentVersion = 3

    var version: Int
    var courses: [CourseID: CourseProgressDocument]

    private enum CodingKeys: String, CodingKey {
        case version
        case courses
    }

    init(version: Int, courses: [CourseID: CourseProgressDocument]) {
        self.version = version
        self.courses = courses
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)

        let rawCourses = try container.decode(
            [String: CourseProgressDocument].self,
            forKey: .courses
        )
        guard rawCourses.keys.allSatisfy(Self.isValidRawKey) else {
            throw DecodingError.dataCorruptedError(
                forKey: .courses,
                in: container,
                debugDescription: "Course progress keys must not be empty"
            )
        }
        courses = Dictionary(
            uniqueKeysWithValues: rawCourses.map {
                (CourseID(rawValue: $0.key), $0.value)
            }
        )
    }

    func encode(to encoder: Encoder) throws {
        guard courses.keys.allSatisfy({ Self.isValidRawKey($0.rawValue) }) else {
            throw EncodingError.invalidValue(
                courses,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Course progress keys must not be empty"
                )
            )
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(
            Dictionary(
                uniqueKeysWithValues: courses.map { ($0.key.rawValue, $0.value) }
            ),
            forKey: .courses
        )
    }

    private static func isValidRawKey(_ rawKey: String) -> Bool {
        !rawKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
