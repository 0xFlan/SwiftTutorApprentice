// SyntaxToken.swift
// ------------------------------------------------------------
// The "Syntax Lens" breaks a line of code into its pieces
// (tokens) and explains each one. A token is just a small,
// meaningful chunk of the code, like `print`, `(`, or `"`.
//
// The actual tokens for each lesson live in Curriculum.swift,
// alongside the lesson they belong to.
//
// TODO: Generate tokens automatically from any line of Swift,
//       instead of curating them per lesson by hand.
// ------------------------------------------------------------

import Foundation

/// One clickable piece of a line of code, plus a beginner explanation.
struct SyntaxToken: Identifiable, Hashable {
    // A stable id, unique within one lesson's token list.
    let id: Int
    /// What is shown on the token chip, e.g. `print` or `(`.
    let display: String
    /// The beginner explanation shown when the token is tapped.
    let explanation: String
}
