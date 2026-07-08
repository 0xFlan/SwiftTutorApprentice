// Lesson.swift
// ------------------------------------------------------------
// A Lesson holds all the teaching content for one step of the
// curriculum. The whole app is driven by this data: the panels
// just display whatever the current Lesson contains.
//
// The actual lessons live in Curriculum.swift.
//
// TODO: Load lessons from JSON/data files so the curriculum can
//       grow without recompiling.
// ------------------------------------------------------------

import Foundation

/// The teaching content for one lesson.
///
/// Properties are `var` so the in-app lesson editor can change them.
struct Lesson: Identifiable, Hashable, Codable {
    var id: Int
    var title: String

    /// One-sentence description of what the learner will achieve.
    var goal: String

    /// The exact code the learner is guided to type. Also used by the
    /// "Insert starter" button and shown under "What you will type".
    var starterCode: String

    /// Short bullet points describing what the lesson teaches.
    var teaches: [String]

    /// Which glossary terms to surface for this lesson (in display order).
    var glossaryTerms: [String]

    /// The key line of code, broken into tokens for the Syntax Lens.
    var syntaxTokens: [SyntaxToken]

    /// The "why does Swift need this?" text shown under the Syntax Lens.
    var syntaxWhy: String

    /// What correct code should print to standard output. Used to explain
    /// runs and to auto-mark a lesson complete when the output matches.
    var expectedOutput: String

    /// Substrings that should ALL appear (once structure is balanced) for
    /// the Live Coach to say "this looks right". Kept deliberately loose so
    /// small formatting differences don't trip beginners up.
    var successMarkers: [String]

    /// Shown by the Live Coach when the code looks right.
    var successMessage: String

    /// Shown by the Live Coach as a nudge when the code isn't there yet.
    var hint: String
}
