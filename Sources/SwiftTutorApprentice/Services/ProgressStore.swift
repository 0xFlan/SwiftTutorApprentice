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
// TODO: Track more than completion later (attempts, last code, notes).
// ------------------------------------------------------------

import Foundation

final class ProgressStore: ObservableObject {

    /// The set of lesson ids the learner has completed.
    @Published private(set) var completedLessonIDs: Set<Int> = []

    /// On-disk shape of the saved data.
    private struct SavedProgress: Codable {
        var completedLessonIDs: [Int]
    }

    private let fileURL: URL

    init() {
        // Build the path to our Application Support folder + file.
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let folder = base.appendingPathComponent("SwiftTutorApprentice", isDirectory: true)
        self.fileURL = folder.appendingPathComponent("progress.json", isDirectory: false)

        load()
    }

    // MARK: - Queries

    func isComplete(_ lessonID: Int) -> Bool {
        completedLessonIDs.contains(lessonID)
    }

    var completedCount: Int { completedLessonIDs.count }

    // MARK: - Changes

    /// Mark a lesson complete (no-op if already complete) and save.
    func markComplete(_ lessonID: Int) {
        guard !completedLessonIDs.contains(lessonID) else { return }
        completedLessonIDs.insert(lessonID)
        save()
    }

    /// Forget all progress and save.
    func reset() {
        completedLessonIDs.removeAll()
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
    }

    private func save() {
        let saved = SavedProgress(completedLessonIDs: completedLessonIDs.sorted())
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
}
