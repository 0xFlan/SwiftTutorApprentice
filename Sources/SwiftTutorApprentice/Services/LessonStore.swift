// LessonStore.swift
// ------------------------------------------------------------
// Owns the list of lessons and saves them to an editable JSON
// file, so lessons can be added or changed entirely inside the
// app — no recompiling, no editing files by hand.
//
// On first launch there's no file yet, so the store seeds itself
// from Curriculum.defaultLessons and writes them out. After that
// it reads and writes:
//
//   ~/Library/Application Support/SwiftTutorApprentice/lessons.json
//
// This is an ObservableObject: views that show the lesson list
// redraw automatically when lessons are added, edited, or removed.
// ------------------------------------------------------------

import Foundation

final class LessonStore: ObservableObject {

    /// The current lessons, in display order.
    @Published private(set) var lessons: [Lesson] = []

    /// Protects lesson files containing newer nested Deep Lesson data from any
    /// lossy automatic rewrite or editor mutation.
    @Published private(set) var isReadOnlyForUnsupportedDeepContent = false

    private let fileURL: URL
    private let defaults: [Lesson]
    private static let baselineSupportedBundledRevision = 1

    private static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let folder = base.appendingPathComponent("SwiftTutorApprentice", isDirectory: true)
        return folder.appendingPathComponent("lessons.json", isDirectory: false)
    }

    convenience init() {
        self.init(fileURL: Self.defaultFileURL, defaults: Curriculum.defaultLessons)
    }

    init(fileURL: URL, defaults: [Lesson]) {
        self.fileURL = fileURL
        self.defaults = defaults

        load()
    }

    // MARK: - Queries

    func lesson(id: Int) -> Lesson? {
        lessons.first { $0.id == id }
    }

    /// An id that isn't used by any current lesson (for new lessons).
    var nextAvailableID: Int {
        (lessons.map(\.id).max() ?? 0) + 1
    }

    // MARK: - Editing (used by the in-app lesson editor)

    /// Add a brand-new lesson to the end.
    func add(_ lesson: Lesson) {
        guard !isReadOnlyForUnsupportedDeepContent else { return }
        lessons.append(reconcilingBundledDeepContent(in: lesson))
        save()
    }

    /// Replace an existing lesson (matched by id) with an edited version.
    @discardableResult
    func update(_ lesson: Lesson) -> Lesson? {
        guard !isReadOnlyForUnsupportedDeepContent else { return nil }
        guard let index = lessons.firstIndex(where: { $0.id == lesson.id }) else { return nil }
        let reconciledLesson = reconcilingBundledDeepContent(in: lesson)
        lessons[index] = reconciledLesson
        save()
        return reconciledLesson
    }

    /// Delete a lesson by id. Won't delete the last remaining lesson.
    func delete(id: Int) {
        guard !isReadOnlyForUnsupportedDeepContent else { return }
        guard lessons.count > 1 else { return }
        lessons.removeAll { $0.id == id }
        save()
    }

    /// Move a lesson up or down in the list (for reordering).
    func move(id: Int, by offset: Int) {
        guard !isReadOnlyForUnsupportedDeepContent else { return }
        guard let index = lessons.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard target >= 0, target < lessons.count else { return }
        lessons.swapAt(index, target)
        save()
    }

    /// Throw away all changes and reload the built-in default curriculum.
    func restoreDefaults() {
        guard !isReadOnlyForUnsupportedDeepContent else { return }
        lessons = defaults
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Lesson].self, from: data),
              !decoded.isEmpty
        else {
            // No usable file yet — seed from the built-in curriculum.
            lessons = defaults
            save()
            return
        }
        lessons = decoded

        if decoded.contains(where: \.hasUnsupportedDeepContent)
            || decoded.contains(where: hasNewerBundledDeepContent)
        {
            isReadOnlyForUnsupportedDeepContent = true
            print("LessonStore: unsupported Deep Lesson data; lesson editing is read-only")
            return
        }

        mergeDefaults()
    }

    /// Enrich compatible built-in lessons with newly bundled deep content, then
    /// append any built-in lessons the saved file doesn't have yet. Compatibility
    /// requires the stable id, lesson kind, and starter code to still match so a
    /// learner's customized exercise is never replaced with stock content.
    ///
    /// Trade-off: a built-in lesson the learner deleted will reappear on the
    /// next launch. That's an acceptable choice for a curriculum app — use the
    /// editor to remove it again if needed.
    private func mergeDefaults() {
        var changed = false

        for index in lessons.indices {
            let savedLessonBeforeReconciliation = lessons[index]
            let reconciledLesson = reconcilingBundledDeepContent(
                in: savedLessonBeforeReconciliation
            )
            if reconciledLesson != savedLessonBeforeReconciliation {
                lessons[index] = reconciledLesson
                changed = true
            }

            let savedLesson = lessons[index]
            guard let defaultLesson = defaults.first(where: { $0.id == savedLesson.id }),
                  defaultLesson.kind == savedLesson.kind,
                  defaultLesson.starterCode == savedLesson.starterCode,
                  savedLessonBeforeReconciliation.deepContent == nil,
                  savedLesson.deepContent == nil,
                  let deepContent = defaultLesson.deepContent
            else { continue }

            lessons[index].deepContent = deepContent
            changed = true
        }

        var existingIDs = Set(lessons.map(\.id))
        for defaultLesson in defaults where existingIDs.insert(defaultLesson.id).inserted {
            lessons.append(defaultLesson)
            changed = true
        }

        if changed {
            save()
        }
    }

    private func hasNewerBundledDeepContent(_ lesson: Lesson) -> Bool {
        guard let provenance = lesson.deepContent?.provenance,
              provenance.source == .bundled
        else {
            return false
        }

        return provenance.revision > supportedBundledRevision(for: lesson.id)
    }

    private func supportedBundledRevision(for lessonID: Int) -> Int {
        guard let defaultProvenance = defaults
            .first(where: { $0.id == lessonID })?
            .deepContent?
            .provenance,
              defaultProvenance.source == .bundled
        else {
            return Self.baselineSupportedBundledRevision
        }

        return max(Self.baselineSupportedBundledRevision, defaultProvenance.revision)
    }

    private func reconcilingBundledDeepContent(in lesson: Lesson) -> Lesson {
        guard let savedDeepContent = lesson.deepContent,
              let savedProvenance = savedDeepContent.provenance,
              savedProvenance.source == .bundled
        else {
            return lesson
        }

        guard let defaultLesson = defaults.first(where: { $0.id == lesson.id }),
              defaultLesson.kind == lesson.kind,
              defaultLesson.starterCode == lesson.starterCode,
              let defaultDeepContent = defaultLesson.deepContent,
              let defaultProvenance = defaultDeepContent.provenance,
              defaultProvenance.source == .bundled
        else {
            var reconciledLesson = lesson
            reconciledLesson.deepContent = nil
            return reconciledLesson
        }

        guard savedProvenance.revision <= defaultProvenance.revision else {
            return lesson
        }

        var reconciledLesson = lesson
        reconciledLesson.deepContent = defaultDeepContent
        return reconciledLesson
    }

    private func save() {
        guard !isReadOnlyForUnsupportedDeepContent else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(lessons)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("LessonStore: could not save lessons — \(error.localizedDescription)")
        }
    }
}
