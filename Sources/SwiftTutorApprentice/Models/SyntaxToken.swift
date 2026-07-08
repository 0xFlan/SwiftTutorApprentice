// SyntaxToken.swift
// ------------------------------------------------------------
// The "Syntax Lens" breaks a line of code into its pieces
// (tokens) and explains each one. A token is just a small,
// meaningful chunk of the code, like `print`, `(`, or `"`.
//
// For the MVP these tokens are hardcoded for the line:
//     print("Hello, Swift!")
//
// TODO: Add Syntax Lens support for more Swift symbols and lines
//       (generate tokens from any code, not just this one line).
// ------------------------------------------------------------

import Foundation

/// One clickable piece of a line of code, plus a beginner explanation.
struct SyntaxToken: Identifiable, Hashable {
    // A stable id. We use a manual id (not UUID) so the same tokens
    // are produced every time — handy for previews and testing.
    let id: Int
    /// What is shown on the token chip, e.g. `print` or `(`.
    let display: String
    /// The beginner explanation shown when the token is tapped.
    let explanation: String
}

enum SyntaxLens {

    /// Tokens for the first lesson's line: print("Hello, Swift!")
    static let helloWorldTokens: [SyntaxToken] = [
        SyntaxToken(
            id: 0,
            display: "print",
            explanation: "A Swift function that writes something to the console."
        ),
        SyntaxToken(
            id: 1,
            display: "(",
            explanation: "Starts the input area for the function. Swift needs it so it knows where the function's input begins."
        ),
        SyntaxToken(
            id: 2,
            display: "\"",
            explanation: "Starts a piece of text. Everything after this quotation mark is treated as literal text until the next one."
        ),
        SyntaxToken(
            id: 3,
            display: "Hello, Swift!",
            explanation: "The exact text value being passed into print. This is a String."
        ),
        SyntaxToken(
            id: 4,
            display: "\"",
            explanation: "Ends the text. A pair of quotation marks marks the start and end of a String."
        ),
        SyntaxToken(
            id: 5,
            display: ")",
            explanation: "Ends the input area for the function."
        )
    ]

    /// The "why does Swift need this?" explanation shown under the tokens.
    static let whyExplanation: String = """
    Swift needs the parentheses ( ) so it knows where the function's input \
    starts and ends.

    Swift needs the quotation marks " " so it knows Hello, Swift! is literal \
    text, not the name of a variable or function.
    """
}
