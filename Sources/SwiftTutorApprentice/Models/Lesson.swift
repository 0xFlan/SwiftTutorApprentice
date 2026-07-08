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

/// What kind of lesson this is.
/// - `code`: the learner types Swift and runs it (the normal loop).
/// - `concept`: a read-only lesson for ideas the local runner can't execute
///   (e.g. SwiftUI, which builds a UI rather than console output).
enum LessonKind: String, Codable {
    case code
    case concept
}

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

    /// Shown by the Live Coach when the code looks right. For `concept`
    /// lessons this doubles as the main explanation.
    var successMessage: String

    /// Shown by the Live Coach as a nudge when the code isn't there yet.
    var hint: String

    /// Runnable code lesson (default) or read-only concept lesson.
    /// Defaults to `.code` so existing call sites and older saved files
    /// (which have no `kind` field) keep working.
    var kind: LessonKind = .code
}

// Custom decoding lives in an extension so the memberwise initializer is still
// synthesized (Curriculum literals rely on it). This tolerates older
// lessons.json files that predate the `kind` field — a missing `kind` decodes
// to `.code` instead of failing the whole load.
extension Lesson {
    private enum CodingKeys: String, CodingKey {
        case id, title, goal, starterCode, teaches, glossaryTerms,
             syntaxTokens, syntaxWhy, expectedOutput, successMarkers,
             successMessage, hint, kind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        goal = try c.decode(String.self, forKey: .goal)
        starterCode = try c.decode(String.self, forKey: .starterCode)
        teaches = try c.decode([String].self, forKey: .teaches)
        glossaryTerms = try c.decode([String].self, forKey: .glossaryTerms)
        syntaxTokens = try c.decode([SyntaxToken].self, forKey: .syntaxTokens)
        syntaxWhy = try c.decode(String.self, forKey: .syntaxWhy)
        expectedOutput = try c.decode(String.self, forKey: .expectedOutput)
        successMarkers = try c.decode([String].self, forKey: .successMarkers)
        successMessage = try c.decode(String.self, forKey: .successMessage)
        hint = try c.decode(String.self, forKey: .hint)
        kind = try c.decodeIfPresent(LessonKind.self, forKey: .kind) ?? .code
    }
}
