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
struct Lesson: Identifiable, Hashable {
    let id: Int
    let title: String

    /// One-sentence description of what the learner will achieve.
    let goal: String

    /// The exact code the learner is guided to type. Also used by the
    /// "Insert starter" button and shown under "What you will type".
    let starterCode: String

    /// Short bullet points describing what the lesson teaches.
    let teaches: [String]

    /// Which glossary terms to surface for this lesson (in display order).
    let glossaryTerms: [String]

    /// The key line of code, broken into tokens for the Syntax Lens.
    let syntaxTokens: [SyntaxToken]

    /// The "why does Swift need this?" text shown under the Syntax Lens.
    let syntaxWhy: String

    /// What correct code should print to standard output. Used to explain
    /// runs and to auto-mark a lesson complete when the output matches.
    let expectedOutput: String

    /// Substrings that should ALL appear (once structure is balanced) for
    /// the Live Coach to say "this looks right". Kept deliberately loose so
    /// small formatting differences don't trip beginners up.
    let successMarkers: [String]

    /// Shown by the Live Coach when the code looks right.
    let successMessage: String

    /// Shown by the Live Coach as a nudge when the code isn't there yet.
    let hint: String
}
