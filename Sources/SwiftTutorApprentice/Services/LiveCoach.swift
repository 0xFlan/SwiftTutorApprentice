// LiveCoach.swift
// ------------------------------------------------------------
// The Live Coach reads whatever is in the code editor and returns
// friendly, beginner-level feedback. It updates as the learner types.
//
// It is RULE-BASED (no AI yet) and works in two layers:
//   1. Generic structural checks that apply to ANY lesson
//      (empty editor, unbalanced quotes / parentheses / braces).
//   2. Lesson-specific checks driven by data on the Lesson itself
//      (its successMarkers, successMessage, and hint).
//
// This keeps the coach reusable across the whole curriculum: adding
// a new lesson doesn't require touching this file.
//
// TODO: Replace rule-based LiveCoach with AI-assisted explanations.
// TODO: Add a "review my whole file" button that sends code to Claude/Codex.
// ------------------------------------------------------------

import Foundation

struct LiveCoach {

    /// Feedback for the current editor contents, in the context of a lesson.
    func feedback(for code: String, lesson: Lesson) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

        // --- Layer 1: generic checks ---

        // Empty editor.
        if trimmed.isEmpty {
            return "Start by typing:\n\(lesson.starterCode)"
        }

        // Unbalanced quotes / parentheses / braces.
        let structuralProblems = structuralProblems(in: trimmed)
        if !structuralProblems.isEmpty {
            var lines = ["This isn't finished yet:"]
            lines.append(contentsOf: structuralProblems.map { "• \($0)" })
            lines.append("")
            lines.append("Aim for:\n\(lesson.starterCode)")
            return lines.joined(separator: "\n")
        }

        // --- Layer 2: lesson-specific checks ---

        // Looks right: all of the lesson's success markers are present.
        let hasAllMarkers = lesson.successMarkers.allSatisfy { trimmed.contains($0) }
        if hasAllMarkers {
            var message = lesson.successMessage
            if !lesson.expectedOutput.isEmpty {
                message += "\n\nWhen you run this, the expected output is:\n\(lesson.expectedOutput)"
            }
            return message
        }

        // Not there yet: show the lesson's hint.
        return lesson.hint
    }

    // MARK: - Generic structural analysis

    /// Returns a beginner-friendly message for each structural problem found.
    /// An empty result means quotes, parentheses, and braces are all balanced.
    private func structuralProblems(in code: String) -> [String] {
        var problems: [String] = []

        let quoteCount = code.filter { $0 == "\"" }.count
        if quoteCount % 2 != 0 {
            problems.append(
                "You have an opening quotation mark \" without a matching closing one. "
                + "Quotation marks come in pairs — one to start the text, one to end it."
            )
        }

        let openParens = code.filter { $0 == "(" }.count
        let closeParens = code.filter { $0 == ")" }.count
        if openParens > closeParens {
            problems.append("You opened a parenthesis ( but haven't closed it with ) yet.")
        } else if closeParens > openParens {
            problems.append("You have a closing parenthesis ) with no matching opening ( before it.")
        }

        let openBraces = code.filter { $0 == "{" }.count
        let closeBraces = code.filter { $0 == "}" }.count
        if openBraces > closeBraces {
            problems.append("You opened a brace { but haven't closed it with } yet. Every { needs a matching }.")
        } else if closeBraces > openBraces {
            problems.append("You have a closing brace } with no matching opening { before it.")
        }

        return problems
    }
}
