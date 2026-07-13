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

    private var document: ProgressDocument?

    /// The set of lesson ids the learner has completed.
    @Published private(set) var completedLessonIDs: Set<Int> = []

    /// The learning-stage milestones recorded for each lesson.
    @Published private(set) var stageEvents: [LessonStageEvent] = []

    /// True when a newer on-disk schema can only be opened without mutations.
    @Published private(set) var isReadOnlyForUnsupportedVersion = false

    /// Non-nil when a supported on-disk schema could not be decoded safely.
    @Published private(set) var loadError: String?

    /// Non-nil when the in-memory document could not be written to disk.
    @Published private(set) var saveError: String?

    private var protectedOriginalData: Data?

    private let fileURL: URL
    private let now: () -> Date
    private let makeEventID: () -> ProgressEventID
    private let writeData: (Data, URL) throws -> Void

    /// The exact local file this store reads and writes. Recovery UI may reveal
    /// this location, but callers cannot replace it or bypass the store's
    /// migration and fail-closed write gates.
    var persistenceURL: URL { fileURL }

    private var canMutate: Bool {
        !isReadOnlyForUnsupportedVersion && loadError == nil && document != nil
    }

    convenience init() {
        // Build the path to our Application Support folder + file.
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let folder = base.appendingPathComponent("SwiftTutorApprentice", isDirectory: true)
        let fileURL = folder.appendingPathComponent("progress.json", isDirectory: false)

        self.init(fileURL: fileURL, now: Date.init)
    }

    init(
        fileURL: URL,
        now: @escaping () -> Date,
        makeEventID: @escaping () -> ProgressEventID = {
            ProgressEventID(rawValue: UUID().uuidString)
        },
        writeData: @escaping (Data, URL) throws -> Void = ProgressStore.atomicWrite
    ) {
        self.fileURL = fileURL
        self.now = now
        self.makeEventID = makeEventID
        self.writeData = writeData

        load()
    }

    // MARK: - Queries

    func progress(for courseID: CourseID) -> CourseProgressDocument {
        document?.courses[courseID] ?? CourseProgressDocument()
    }

    func isComplete(_ key: LessonKey) -> Bool {
        progress(for: key.courseID).completedLessonLocalIDs.contains(key.localID)
    }

    func isComplete(_ lessonID: Int) -> Bool {
        isComplete(.swift(lessonID))
    }

    func hasViewedDeepLesson(_ key: LessonKey) -> Bool {
        progress(for: key.courseID).stageEvents.contains {
            $0.lessonLocalID == key.localID && $0.kind == .deepLessonViewed
        }
    }

    func hasViewedDeepLesson(_ lessonID: Int) -> Bool {
        hasViewedDeepLesson(.swift(lessonID))
    }

    func hasPassedModify(_ key: LessonKey) -> Bool {
        progress(for: key.courseID).stageEvents.contains {
            $0.lessonLocalID == key.localID && $0.kind == .modifyPassed
        }
    }

    func hasPassedModify(_ lessonID: Int) -> Bool {
        hasPassedModify(.swift(lessonID))
    }

    func presentationState(for key: LessonKey) -> LessonPresentationState? {
        progress(for: key.courseID).presentationStates[key.localID]
    }

    func recallAnswer(for key: LessonKey, questionID: String) -> Bool? {
        progress(for: key.courseID).stageEvents.first {
            $0.lessonLocalID == key.localID
                && $0.kind == .recallAnswered
                && $0.questionID == questionID
        }?.wasCorrect
    }

    func hasMeaningfulActivity(in courseID: CourseID) -> Bool {
        let courseProgress = progress(for: courseID)
        if courseProgress.lastLessonLocalID != nil
            || !courseProgress.completedLessonLocalIDs.isEmpty
            || !courseProgress.stageEvents.isEmpty
            || !courseProgress.assessmentAttempts.isEmpty
        {
            return true
        }
        if courseProgress.presentationStates.values.contains(where: {
            $0.status != .notStarted
        }) {
            return true
        }
        return courseProgress.reviews.contains { review in
            guard let satisfyingAttemptID = review.satisfyingAttemptID else {
                return false
            }
            return courseProgress.assessmentAttempts.contains {
                $0.id == satisfyingAttemptID && $0.lessonKey.courseID == courseID
            }
        }
    }

    func lastLessonKey(in courseID: CourseID) -> LessonKey? {
        let courseProgress = progress(for: courseID)
        if let localID = courseProgress.lastLessonLocalID {
            return LessonKey(courseID: courseID, localID: localID)
        }
        for review in courseProgress.reviews.reversed() {
            guard let satisfyingAttemptID = review.satisfyingAttemptID,
                  let attempt = courseProgress.assessmentAttempts.last(where: {
                      $0.id == satisfyingAttemptID && $0.lessonKey.courseID == courseID
                  })
            else { continue }
            return attempt.lessonKey
        }
        return nil
    }

    var completedCount: Int { completedLessonIDs.count }

    // MARK: - Changes

    /// Mark a lesson complete (no-op if already complete) and save.
    func markComplete(_ key: LessonKey) {
        guard canMutate else { return }
        var courseProgress = progress(for: key.courseID)
        guard courseProgress.completedLessonLocalIDs.insert(key.localID).inserted else {
            return
        }
        courseProgress.lastLessonLocalID = key.localID
        document?.courses[key.courseID] = courseProgress
        syncCompatibilitySurfaces()
        save()
    }

    func markComplete(_ lessonID: Int) {
        markComplete(.swift(lessonID))
    }

    func markDeepLessonViewed(_ key: LessonKey) {
        guard canMutate,
              !hasViewedDeepLesson(key)
        else { return }
        var courseProgress = progress(for: key.courseID)
        courseProgress.stageEvents.append(
            CourseStageEvent(
                id: makeEventID(),
                lessonLocalID: key.localID,
                kind: .deepLessonViewed,
                timestamp: now(),
                questionID: nil,
                wasCorrect: nil
            )
        )
        courseProgress.lastLessonLocalID = key.localID
        document?.courses[key.courseID] = courseProgress
        syncCompatibilitySurfaces()
        save()
    }

    func markDeepLessonViewed(_ lessonID: Int) {
        markDeepLessonViewed(.swift(lessonID))
    }

    func markModifyPassed(_ key: LessonKey) {
        guard canMutate,
              !hasPassedModify(key)
        else { return }
        var courseProgress = progress(for: key.courseID)
        courseProgress.stageEvents.append(
            CourseStageEvent(
                id: makeEventID(),
                lessonLocalID: key.localID,
                kind: .modifyPassed,
                timestamp: now(),
                questionID: nil,
                wasCorrect: nil
            )
        )
        courseProgress.lastLessonLocalID = key.localID
        document?.courses[key.courseID] = courseProgress
        syncCompatibilitySurfaces()
        save()
    }

    func markModifyPassed(_ lessonID: Int) {
        markModifyPassed(.swift(lessonID))
    }

    func recordRecallAnswer(
        lessonKey: LessonKey,
        questionID: String,
        wasCorrect: Bool
    ) {
        guard canMutate else { return }
        guard !questionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        var courseProgress = progress(for: lessonKey.courseID)
        guard !courseProgress.stageEvents.contains(where: {
            $0.lessonLocalID == lessonKey.localID
                && $0.kind == .recallAnswered
                && $0.questionID == questionID
        }) else {
            return
        }

        courseProgress.stageEvents.append(
            CourseStageEvent(
                id: makeEventID(),
                lessonLocalID: lessonKey.localID,
                kind: .recallAnswered,
                timestamp: now(),
                questionID: questionID,
                wasCorrect: wasCorrect
            )
        )
        courseProgress.lastLessonLocalID = lessonKey.localID
        document?.courses[lessonKey.courseID] = courseProgress
        syncCompatibilitySurfaces()
        save()
    }

    func recordRecallAnswer(lessonID: Int, questionID: String, wasCorrect: Bool) {
        recordRecallAnswer(
            lessonKey: .swift(lessonID),
            questionID: questionID,
            wasCorrect: wasCorrect
        )
    }

    func setPresentationState(
        _ state: LessonPresentationState,
        for key: LessonKey
    ) {
        guard canMutate else { return }
        var courseProgress = progress(for: key.courseID)
        courseProgress.presentationStates[key.localID] = state
        if state.status != .notStarted {
            courseProgress.lastLessonLocalID = key.localID
        }
        document?.courses[key.courseID] = courseProgress
        syncCompatibilitySurfaces()
        save()
    }

    func record(_ attempt: AssessmentAttempt) {
        guard canMutate,
              document?.courses.values.contains(where: { courseProgress in
                  courseProgress.assessmentAttempts.contains {
                      $0.id == attempt.id
                  }
              }) == false
        else { return }
        var courseProgress = progress(for: attempt.lessonKey.courseID)
        courseProgress.assessmentAttempts.append(attempt)
        courseProgress.lastLessonLocalID = attempt.lessonKey.localID
        document?.courses[attempt.lessonKey.courseID] = courseProgress
        syncCompatibilitySurfaces()
        save()
    }

    func recordSavedWorkspaceActivity(for key: LessonKey) {
        guard canMutate else { return }
        var courseProgress = progress(for: key.courseID)
        courseProgress.lastLessonLocalID = key.localID
        document?.courses[key.courseID] = courseProgress
        syncCompatibilitySurfaces()
        save()
    }

    /// Forget all progress and save.
    func reset(courseID: CourseID) {
        guard canMutate else { return }
        document?.courses[courseID] = CourseProgressDocument()
        syncCompatibilitySurfaces()
        save()
    }

    func reset() {
        reset(courseID: .swiftDevelopment)
    }

    func retrySave() {
        guard canMutate,
              saveError != nil
        else { return }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            document = ProgressDocument(
                version: ProgressDocument.currentVersion,
                courses: [.swiftDevelopment: CourseProgressDocument()]
            )
            syncCompatibilitySurfaces()
            return
        }

        switch ProgressMigration.decode(data: data) {
        case let .current(loadedDocument), let .migrated(_, loadedDocument):
            document = loadedDocument
        case let .unsupportedFuture(_, originalData):
            isReadOnlyForUnsupportedVersion = true
            protectedOriginalData = originalData
            document = nil
        case let .corruptSupported(_, originalData, reason):
            loadError = reason
            protectedOriginalData = originalData
            document = nil
        }
        syncCompatibilitySurfaces()
    }

    private func syncCompatibilitySurfaces() {
        let swiftProgress = document?.courses[.swiftDevelopment]
        completedLessonIDs = Set(
            (swiftProgress?.completedLessonLocalIDs ?? []).compactMap {
                Int($0.rawValue)
            }
        )
        stageEvents = (swiftProgress?.stageEvents ?? []).compactMap { event in
            guard let lessonID = Int(event.lessonLocalID.rawValue),
                  let kind = LessonStageEventKind(rawValue: event.kind.rawValue)
            else { return nil }
            return LessonStageEvent(
                lessonID: lessonID,
                kind: kind,
                timestamp: event.timestamp,
                questionID: event.questionID,
                wasCorrect: event.wasCorrect
            )
        }
    }

    private func save() {
        guard canMutate, let document else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = ProgressDateCoding.encodingStrategy
            let data = try encoder.encode(document)
            try writeData(data, fileURL)
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }

    static func atomicWrite(_ data: Data, _ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

}
