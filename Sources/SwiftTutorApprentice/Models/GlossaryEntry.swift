// GlossaryEntry.swift
// ------------------------------------------------------------
// The glossary is how the app teaches vocabulary. Each entry has:
//   - term:  the word being defined (e.g. "String")
//   - short: a one-line definition shown as a hover tooltip
//   - deep:  a fuller explanation shown when the term is clicked
//
// Everything is stored in a plain Swift dictionary so it is easy
// to read and easy to extend later.
//
// TODO: Add lesson JSON loading so glossary entries can live in
//       data files instead of being hardcoded here.
// ------------------------------------------------------------

import Foundation

/// One vocabulary entry the app can explain.
struct GlossaryEntry: Identifiable, Hashable {
    var id: String { term }
    let term: String
    let short: String
    let deep: String
}

/// A tiny in-memory glossary. Look terms up with `Glossary.entry(for:)`.
enum Glossary {

    /// The words the first lesson knows how to explain.
    /// Keyed by the lowercased term so lookups are case-insensitive.
    static let entries: [String: GlossaryEntry] = buildEntries()

    /// Ordered list of terms to display in the Lesson panel.
    static let displayOrder: [String] = [
        "Swift",
        "String",
        "function",
        "console",
        "standard output",
        "standard error",
        "exit code",
        "compiler"
    ]

    /// Look up an entry by term (case-insensitive). Returns nil if unknown.
    static func entry(for term: String) -> GlossaryEntry? {
        entries[term.lowercased()]
    }

    private static func buildEntries() -> [String: GlossaryEntry] {
        let all: [GlossaryEntry] = [
            GlossaryEntry(
                term: "Swift",
                short: "Apple's modern programming language.",
                deep: """
                Swift is the programming language Apple created for building \
                apps on macOS, iOS, iPadOS, watchOS, tvOS, and visionOS.

                It is designed to be safe (it catches many mistakes before \
                your app runs), fast, and readable. The code you are learning \
                here is the same language used to build real Apple apps.
                """
            ),
            GlossaryEntry(
                term: "String",
                short: "A String is text.",
                deep: """
                A String stores text, like "Hello", "Alex", or "iPhone".
                Swift treats anything inside quotation marks as text.

                "34" is a String, but 34 is an Int (a whole number).

                The difference matters: you can do math with Int values, but \
                a String is just characters. This is one of the first big \
                ideas in programming — values have types.
                """
            ),
            GlossaryEntry(
                term: "function",
                short: "A named block of code you can run.",
                deep: """
                A function is a reusable block of code that does one job.
                You "call" (run) it by writing its name followed by \
                parentheses, like print(...).

                A function can take inputs, called arguments, inside the \
                parentheses. print("Hello") calls the print function and \
                passes it one argument: the String "Hello".

                Real Apple apps are built almost entirely out of functions \
                calling other functions.
                """
            ),
            GlossaryEntry(
                term: "console",
                short: "The text area where a program prints messages.",
                deep: """
                The console is a text area where a program can write messages \
                for a human to read.

                In Terminal, the console is the window you typed the command \
                into. In Xcode, it is the debug area at the bottom of the \
                window. When you call print(...), the text shows up here.
                """
            ),
            GlossaryEntry(
                term: "standard output",
                short: "The normal output stream, called stdout.",
                deep: """
                Standard output — usually written as "stdout" — is the default \
                place a program sends its normal text.

                print(...) writes to standard output. Other tools (including \
                this app) can capture that text and show it to you. When your \
                program works correctly, its results appear on stdout.
                """
            ),
            GlossaryEntry(
                term: "standard error",
                short: "The separate error stream, called stderr.",
                deep: """
                Standard error — usually written as "stderr" — is a separate \
                stream just for error and warning messages.

                Keeping errors separate from normal output (stdout) means a \
                program's results don't get tangled up with its complaints. \
                When something goes wrong, read stderr first.
                """
            ),
            GlossaryEntry(
                term: "exit code",
                short: "A number showing success (0) or failure.",
                deep: """
                When a program finishes, it hands back a single number called \
                an exit code.

                0 means success — everything ran cleanly.
                Any other number (like 1) usually means something went wrong.

                Command-line tools and scripts use this number to decide what \
                to do next.
                """
            ),
            GlossaryEntry(
                term: "compiler",
                short: "Turns your Swift code into a runnable program.",
                deep: """
                The compiler reads your Swift source code, checks it for \
                mistakes, and translates it into instructions the computer \
                can actually run.

                If the compiler finds an error — a missing quote, a typo in a \
                name — it refuses to build the program and tells you what is \
                wrong. Learning to read those messages is a core skill.
                """
            )
        ]

        // Turn the list into a dictionary keyed by lowercased term.
        var byTerm: [String: GlossaryEntry] = [:]
        for entry in all {
            byTerm[entry.term.lowercased()] = entry
        }
        return byTerm
    }
}
