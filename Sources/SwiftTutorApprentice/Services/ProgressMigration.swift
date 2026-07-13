import Foundation

enum ProgressLoadResult: Equatable {
    case current(ProgressDocument)
    case migrated(sourceVersion: Int, document: ProgressDocument)
    case unsupportedFuture(version: Int, originalData: Data)
    case corruptSupported(version: Int, originalData: Data, reason: String)
}

enum LegacyStageEventKind: String, Codable, Hashable {
    case deepLessonViewed
    case modifyPassed
    case recallAnswered
}

struct LegacyStageEvent: Codable, Equatable {
    let lessonID: Int
    let kind: LegacyStageEventKind
    let timestamp: Date
    let questionID: String?
    let wasCorrect: Bool?
}

enum LegacyStageEventDecoder {
    struct Elements: Decodable {
        let events: [LegacyStageEvent]

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            var events: [LegacyStageEvent] = []

            while !container.isAtEnd {
                let elementDecoder = try container.superDecoder()
                if let event = try? LegacyStageEvent(from: elementDecoder) {
                    events.append(event)
                }
            }
            self.events = events
        }
    }

    static func decodeElements(from data: Data) throws -> [LegacyStageEvent] {
        try JSONDecoder().decode(Elements.self, from: data).events
    }
}

enum ProgressMigration {
    private struct LegacyEventKey: Hashable {
        let lessonID: Int
        let kind: LegacyStageEventKind
        let recallQuestionID: String?
    }

    static func hasValidMetadata(_ event: LegacyStageEvent) -> Bool {
        switch event.kind {
        case .recallAnswered:
            guard let questionID = event.questionID else { return false }
            return !questionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && event.wasCorrect != nil
        case .deepLessonViewed, .modifyPassed:
            return event.questionID == nil && event.wasCorrect == nil
        }
    }

    static func firstUniqueLegacyEvents(
        from events: [LegacyStageEvent]
    ) -> [LegacyStageEvent] {
        var seen: Set<LegacyEventKey> = []
        return events.filter { event in
            let key = LegacyEventKey(
                lessonID: event.lessonID,
                kind: event.kind,
                recallQuestionID: event.kind == .recallAnswered ? event.questionID : nil
            )
            return seen.insert(key).inserted
        }
    }

    static func hasRepresentableCanonicalTimestamp(_ event: LegacyStageEvent) -> Bool {
        canonicalMilliseconds(for: event.timestamp) != nil
    }

    private static func canonicalMilliseconds(for timestamp: Date) -> Int64? {
        let roundedMilliseconds = (
            timestamp.timeIntervalSince1970 * 1_000
        ).rounded()
        guard roundedMilliseconds.isFinite,
              let milliseconds = Int64(exactly: roundedMilliseconds)
        else { return nil }
        return milliseconds
    }

    static func legacyEventID(for event: LegacyStageEvent) -> ProgressEventID? {
        guard let milliseconds = canonicalMilliseconds(for: event.timestamp) else {
            return nil
        }

        return ProgressEventID(rawValue: [
            "legacy-v2",
            CourseID.swiftDevelopment.rawValue,
            String(event.lessonID),
            event.kind.rawValue,
            event.questionID ?? "-",
            String(milliseconds)
        ].joined(separator: "|"))
    }

    static func courseEvent(from event: LegacyStageEvent) -> CourseStageEvent? {
        guard let eventID = legacyEventID(for: event) else { return nil }

        let kind: CourseStageEventKind
        switch event.kind {
        case .deepLessonViewed:
            kind = .deepLessonViewed
        case .modifyPassed:
            kind = .modifyPassed
        case .recallAnswered:
            kind = .recallAnswered
        }

        return CourseStageEvent(
            id: eventID,
            lessonLocalID: LessonLocalID(rawValue: String(event.lessonID)),
            kind: kind,
            timestamp: event.timestamp,
            questionID: event.questionID,
            wasCorrect: event.wasCorrect
        )
    }

    private struct VersionEnvelope: Decodable {
        let version: Int

        private enum CodingKeys: String, CodingKey {
            case version
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if container.contains(.version) {
                version = try container.decode(Int.self, forKey: .version)
            } else {
                version = 1
            }
        }
    }

    private struct VersionOneProgress: Decodable {
        let completedLessonIDs: [Int]
    }

    private struct VersionTwoProgress: Decodable {
        let completedLessonIDs: [Int]
        let stageEvents: [LegacyStageEvent]

        private enum CodingKeys: String, CodingKey {
            case completedLessonIDs
            case stageEvents
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            completedLessonIDs = try container.decode(
                [Int].self,
                forKey: .completedLessonIDs
            )
            stageEvents = try container.decode(
                LegacyStageEventDecoder.Elements.self,
                forKey: .stageEvents
            ).events
        }
    }

    static func decode(data: Data) -> ProgressLoadResult {
        let decoder = JSONDecoder()
        let version: Int

        do {
            version = try decoder.decode(VersionEnvelope.self, from: data).version
        } catch {
            return .corruptSupported(version: 1, originalData: data, reason: String(describing: error))
        }

        if version > ProgressDocument.currentVersion {
            return .unsupportedFuture(version: version, originalData: data)
        }

        do {
            let completedLessonIDs: [Int]
            let stageEvents: [LegacyStageEvent]
            switch version {
            case 1:
                completedLessonIDs = try decoder.decode(
                    VersionOneProgress.self,
                    from: data
                ).completedLessonIDs
                stageEvents = []
            case 2:
                let legacy = try decoder.decode(VersionTwoProgress.self, from: data)
                completedLessonIDs = legacy.completedLessonIDs
                stageEvents = firstUniqueLegacyEvents(
                    from: legacy.stageEvents
                        .filter(hasValidMetadata)
                        .filter(hasRepresentableCanonicalTimestamp)
                )
            case ProgressDocument.currentVersion:
                let currentDecoder = JSONDecoder()
                currentDecoder.dateDecodingStrategy = ProgressDateCoding.decodingStrategy
                return .current(try currentDecoder.decode(ProgressDocument.self, from: data))
            default:
                return .corruptSupported(
                    version: version,
                    originalData: data,
                    reason: "Progress version \(version) is not implemented"
                )
            }

            let swiftProgress = CourseProgressDocument(
                completedLessonLocalIDs: Set(completedLessonIDs.map {
                    LessonLocalID(rawValue: String($0))
                }),
                stageEvents: stageEvents.compactMap(courseEvent)
            )
            return .migrated(
                sourceVersion: version,
                document: ProgressDocument(
                    version: ProgressDocument.currentVersion,
                    courses: [.swiftDevelopment: swiftProgress]
                )
            )
        } catch {
            return .corruptSupported(
                version: version,
                originalData: data,
                reason: String(describing: error)
            )
        }
    }
}
