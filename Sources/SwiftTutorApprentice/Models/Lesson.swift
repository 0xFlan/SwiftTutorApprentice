// Lesson.swift
// ------------------------------------------------------------
// A Lesson holds the teaching content shown in the Lesson panel.
// For the MVP we hardcode a single lesson (Lesson 1). Later this
// can be loaded from data files.
//
// TODO: Add lesson JSON loading and a full curriculum database.
// TODO: Add progress tracking (which lessons are complete).
// ------------------------------------------------------------

import Foundation

/// The teaching content for one lesson.
struct Lesson: Identifiable {
    let id: Int
    let title: String
    let goal: String
    /// The exact code the learner is expected to type.
    let codeToType: String
    /// Short bullet points describing what the lesson teaches.
    let teaches: [String]

    /// The one and only lesson in the MVP.
    static let lesson1 = Lesson(
        id: 1,
        title: "Printing Text in Swift",
        goal: "Learn how to display text in the console using print.",
        codeToType: "print(\"Hello, Swift!\")",
        teaches: [
            "print",
            "function call",
            "parentheses",
            "quotation marks",
            "String",
            "console output"
        ]
    )
}
