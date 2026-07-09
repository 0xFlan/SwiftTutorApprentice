// ProgressStore.swift
// ------------------------------------------------------------
// Remembers which lessons the learner has completed, and saves
// that to a small JSON file so it survives quitting the app.
//
// The file lives at:
//   ~/Library/Application Support/SwiftTutorApprentice/progress.json
//
// It's deliberately plain, human-readable JSON — you can open it
// and see exactly what the app stored. This mirrors how real apps
// persist small amounts of local state.
//
// This is an ObservableObject: SwiftUI views that observe it
// automatically redraw when `completedLessonIDs` changes.
//
// ------------------------------------------------------------

import Foundation

enum LessonStageEventKind: String, Codable, Hashable {
    case deepLessonViewed
    case modifyPassed
    case recallAnswered
}

struct LessonStageEvent: Codable, Hashable {
    let lessonID: Int
    let kind: LessonStageEventKind
    let timestamp: Date
    let questionID: String?
    let wasCorrect: Bool?
}

final class ProgressStore: ObservableObject {

    private static let currentVersion = 2

    /// The set of lesson ids the learner has completed.
    @Published private(set) var completedLessonIDs: Set<Int> = []

    /// The learning-stage milestones recorded for each lesson.
    @Published private(set) var stageEvents: [LessonStageEvent] = []

    /// On-disk shape of the saved data.
    private struct SavedProgress: Codable {
        var version: Int
        var completedLessonIDs: [Int]
        var stageEvents: [LessonStageEvent]

        private enum CodingKeys: String, CodingKey {
            case version
            case completedLessonIDs
            case stageEvents
        }

        init(
            version: Int,
            completedLessonIDs: [Int],
            stageEvents: [LessonStageEvent]
        ) {
            self.version = version
            self.completedLessonIDs = completedLessonIDs
            self.stageEvents = stageEvents
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
            completedLessonIDs = try container.decode([Int].self, forKey: .completedLessonIDs)
            stageEvents = (try? container.decode(
                LossyStageEvents.self,
                forKey: .stageEvents
            ))?.events ?? []
        }
    }

    private struct LossyStageEvents: Decodable {
        let events: [LessonStageEvent]

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            var decodedEvents: [LessonStageEvent] = []

            while !container.isAtEnd {
                let eventDecoder = try container.superDecoder()
                if let event = try? LessonStageEvent(from: eventDecoder) {
                    decodedEvents.append(event)
                }
            }

            events = decodedEvents
        }
    }

    private struct StageEventKey: Hashable {
        let lessonID: Int
        let kind: LessonStageEventKind
        let questionID: String?
    }

    private let fileURL: URL
    private let now: () -> Date
    private var isReadOnly = false

    convenience init() {
        // Build the path to our Application Support folder + file.
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let folder = base.appendingPathComponent("SwiftTutorApprentice", isDirectory: true)
        let fileURL = folder.appendingPathComponent("progress.json", isDirectory: false)

        self.init(fileURL: fileURL, now: Date.init)
    }

    init(fileURL: URL, now: @escaping () -> Date) {
        self.fileURL = fileURL
        self.now = now

        load()
    }

    // MARK: - Queries

    func isComplete(_ lessonID: Int) -> Bool {
        completedLessonIDs.contains(lessonID)
    }

    func hasViewedDeepLesson(_ lessonID: Int) -> Bool {
        stageEvents.contains {
            $0.lessonID == lessonID && $0.kind == .deepLessonViewed
        }
    }

    func hasPassedModify(_ lessonID: Int) -> Bool {
        stageEvents.contains {
            $0.lessonID == lessonID && $0.kind == .modifyPassed
        }
    }

    var completedCount: Int { completedLessonIDs.count }

    // MARK: - Changes

    /// Mark a lesson complete (no-op if already complete) and save.
    func markComplete(_ lessonID: Int) {
        guard !isReadOnly, !completedLessonIDs.contains(lessonID) else { return }
        completedLessonIDs.insert(lessonID)
        save()
    }

    func markDeepLessonViewed(_ lessonID: Int) {
        guard !isReadOnly, !hasViewedDeepLesson(lessonID) else { return }
        stageEvents.append(
            LessonStageEvent(
                lessonID: lessonID,
                kind: .deepLessonViewed,
                timestamp: now(),
                questionID: nil,
                wasCorrect: nil
            )
        )
        save()
    }

    func markModifyPassed(_ lessonID: Int) {
        guard !isReadOnly, !hasPassedModify(lessonID) else { return }
        stageEvents.append(
            LessonStageEvent(
                lessonID: lessonID,
                kind: .modifyPassed,
                timestamp: now(),
                questionID: nil,
                wasCorrect: nil
            )
        )
        save()
    }

    func recordRecallAnswer(lessonID: Int, questionID: String, wasCorrect: Bool) {
        guard !isReadOnly else { return }
        guard !questionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        guard !stageEvents.contains(where: {
            $0.lessonID == lessonID
                && $0.kind == .recallAnswered
                && $0.questionID == questionID
        }) else {
            return
        }

        stageEvents.append(
            LessonStageEvent(
                lessonID: lessonID,
                kind: .recallAnswered,
                timestamp: now(),
                questionID: questionID,
                wasCorrect: wasCorrect
            )
        )
        save()
    }

    /// Forget all progress and save.
    func reset() {
        guard !isReadOnly else { return }
        completedLessonIDs.removeAll()
        stageEvents.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode(SavedProgress.self, from: data)
        else {
            return // No file yet (first launch) — start empty.
        }
        completedLessonIDs = Set(saved.completedLessonIDs)
        stageEvents = Self.validUniqueEvents(from: saved.stageEvents)
        isReadOnly = !(1...Self.currentVersion).contains(saved.version)
    }

    private func save() {
        guard !isReadOnly else { return }
        let saved = SavedProgress(
            version: Self.currentVersion,
            completedLessonIDs: completedLessonIDs.sorted(),
            stageEvents: stageEvents
        )
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(saved)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // For a personal MVP, failing to save progress is not fatal;
            // we just print so it's visible while developing.
            print("ProgressStore: could not save progress — \(error.localizedDescription)")
        }
    }

    private static func hasValidMetadata(_ event: LessonStageEvent) -> Bool {
        switch event.kind {
        case .recallAnswered:
            guard let questionID = event.questionID else { return false }
            return !questionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && event.wasCorrect != nil
        case .deepLessonViewed, .modifyPassed:
            return event.questionID == nil && event.wasCorrect == nil
        }
    }

    private static func validUniqueEvents(
        from events: [LessonStageEvent]
    ) -> [LessonStageEvent] {
        var seenKeys: Set<StageEventKey> = []
        var uniqueEvents: [LessonStageEvent] = []

        for event in events where hasValidMetadata(event) {
            let key = StageEventKey(
                lessonID: event.lessonID,
                kind: event.kind,
                questionID: event.kind == .recallAnswered ? event.questionID : nil
            )
            guard seenKeys.insert(key).inserted else { continue }
            uniqueEvents.append(event)
        }

        return uniqueEvents
    }
}
