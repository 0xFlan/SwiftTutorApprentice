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

    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let folder = base.appendingPathComponent("SwiftTutorApprentice", isDirectory: true)
        self.fileURL = folder.appendingPathComponent("lessons.json", isDirectory: false)

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
        lessons.append(lesson)
        save()
    }

    /// Replace an existing lesson (matched by id) with an edited version.
    func update(_ lesson: Lesson) {
        guard let index = lessons.firstIndex(where: { $0.id == lesson.id }) else { return }
        lessons[index] = lesson
        save()
    }

    /// Delete a lesson by id. Won't delete the last remaining lesson.
    func delete(id: Int) {
        guard lessons.count > 1 else { return }
        lessons.removeAll { $0.id == id }
        save()
    }

    /// Move a lesson up or down in the list (for reordering).
    func move(id: Int, by offset: Int) {
        guard let index = lessons.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard target >= 0, target < lessons.count else { return }
        lessons.swapAt(index, target)
        save()
    }

    /// Throw away all changes and reload the built-in default curriculum.
    func restoreDefaults() {
        lessons = Curriculum.defaultLessons
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Lesson].self, from: data),
              !decoded.isEmpty
        else {
            // No usable file yet — seed from the built-in curriculum.
            lessons = Curriculum.defaultLessons
            save()
            return
        }
        lessons = decoded
    }

    private func save() {
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
