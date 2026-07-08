// LiveCoach.swift
// ------------------------------------------------------------
// The Live Coach reads whatever is currently in the code editor
// and returns friendly, beginner-level feedback about it.
//
// For the MVP this is RULE-BASED: it looks for a few specific
// patterns and responds. There is no AI here yet.
//
// TODO: Replace rule-based LiveCoach with AI-assisted explanations.
// TODO: Add Claude/Codex project review buttons that feed code here.
// ------------------------------------------------------------

import Foundation

/// Analyzes editor text and produces beginner feedback.
struct LiveCoach {

    /// The exact code this lesson is guiding the learner toward.
    private let target = "print(\"Hello, Swift!\")"

    /// Return feedback for the current editor contents.
    func feedback(for code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

        // Case D: nothing typed yet.
        if trimmed.isEmpty {
            return """
            Start by typing:
            print("Hello, Swift!")
            """
        }

        // Case A: the target line is present and looks complete.
        if trimmed.contains(target) {
            return """
            Good. This calls the print function and gives it one String: "Hello, Swift!".

            • print sends text to the console.
            • The parentheses hold the input for the function.
            • The quotation marks tell Swift this is text.

            When you run this, the expected output is:
            Hello, Swift!
            """
        }

        // Case B: a print(...) call that is not finished (unbalanced quotes/parens).
        if trimmed.contains("print(") {
            let quoteCount = trimmed.filter { $0 == "\"" }.count
            let openParens = trimmed.filter { $0 == "(" }.count
            let closeParens = trimmed.filter { $0 == ")" }.count

            let missingQuote = (quoteCount % 2 != 0)
            let missingParen = (openParens > closeParens)

            if missingQuote || missingParen {
                var lines: [String] = [
                    "You started a print(...) but it isn't finished yet:"
                ]
                if missingQuote {
                    lines.append(
                        "• You have an opening quotation mark \" but no matching closing one. "
                        + "Quotation marks come in pairs — one to start the text and one to end it."
                    )
                }
                if missingParen {
                    lines.append(
                        "• You opened a parenthesis ( but haven't closed it with ) yet. "
                        + "Every ( needs a matching )."
                    )
                }
                lines.append("")
                lines.append("Aim for: print(\"Hello, Swift!\")")
                return lines.joined(separator: "\n")
            }
        }

        // Case C: there is quoted text somewhere.
        if trimmed.contains("\"") {
            return """
            Anything you put inside quotation marks " " is treated as a String — \
            literal text. Swift won't try to run it or look it up as a name; it \
            just keeps the characters exactly as typed.

            For this lesson, try passing the String into print:
            print("Hello, Swift!")
            """
        }

        // Fallback: something else was typed.
        return """
        Keep going. For this lesson the goal is to call the print function with \
        a String, like this:
        print("Hello, Swift!")

        print writes text to the console.
        """
    }
}
