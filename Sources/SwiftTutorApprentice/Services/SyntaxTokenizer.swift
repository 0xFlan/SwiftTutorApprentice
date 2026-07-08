// SyntaxTokenizer.swift
// ------------------------------------------------------------
// Splits a line of Swift into tokens with generic, beginner-level
// explanations. Used two ways:
//   • As a fallback for the Syntax Lens when a lesson has no curated
//     tokens (e.g. a lesson you just authored in the app).
//   • Behind the "Auto-generate tokens" button in the lesson editor.
//
// This is a small hand-written scanner — not a full Swift parser.
// It recognizes keywords, types, string literals, numbers, common
// operators, and punctuation, and labels everything else as a name.
//
// TODO: Grow the keyword/symbol tables as the curriculum expands.
// ------------------------------------------------------------

import Foundation

enum SyntaxTokenizer {

    /// Produce tokens for the first meaningful line of `code`.
    /// (One line keeps the Syntax Lens focused, like the curated lessons.)
    static func tokenize(_ code: String) -> [SyntaxToken] {
        guard let line = firstMeaningfulLine(of: code) else { return [] }

        var tokens: [SyntaxToken] = []
        var nextID = 0
        func add(_ display: String, _ explanation: String) {
            tokens.append(SyntaxToken(id: nextID, display: display, explanation: explanation))
            nextID += 1
        }

        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]

            // Skip whitespace — tokens are the non-space pieces.
            if c == " " || c == "\t" {
                i += 1
                continue
            }

            // String literal: consume through the closing quote.
            if c == "\"" {
                var text = "\""
                i += 1
                while i < chars.count {
                    text.append(chars[i])
                    let ch = chars[i]
                    i += 1
                    if ch == "\"" { break }
                }
                add(text, "A String — literal text inside quotation marks. Swift keeps it exactly as written.")
                continue
            }

            // Identifier or keyword: letters, digits, underscore.
            if c.isLetter || c == "_" {
                var word = ""
                while i < chars.count, chars[i].isLetter || chars[i].isNumber || chars[i] == "_" {
                    word.append(chars[i])
                    i += 1
                }
                add(word, explanationForWord(word))
                continue
            }

            // Number literal (Int or Double).
            if c.isNumber {
                var num = ""
                var sawDot = false
                while i < chars.count, chars[i].isNumber || (chars[i] == "." && !sawDot) {
                    if chars[i] == "." { sawDot = true }
                    num.append(chars[i])
                    i += 1
                }
                add(num, sawDot
                    ? "A Double — a number with a decimal point."
                    : "An Int — a whole number. No quotes, so Swift treats it as a number.")
                continue
            }

            // Multi-character operators (check before single characters).
            if let (op, meaning) = matchOperator(chars, at: i) {
                add(op, meaning)
                i += op.count
                continue
            }

            // Single punctuation / operator character.
            let s = String(c)
            add(s, explanationForSymbol(s))
            i += 1
        }

        return tokens
    }

    /// A generic "why the syntax?" note for auto-generated breakdowns.
    static let autoWhy = """
    This breakdown was generated automatically from the code. Tap any piece to \
    see what it is. Keywords, names, text, numbers, and symbols each play a \
    different role — Swift needs every piece to understand what you mean.
    """

    // MARK: - Private

    private static func firstMeaningfulLine(of code: String) -> String? {
        for raw in code.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("//") { continue }
            return line
        }
        return nil
    }

    private static func explanationForWord(_ word: String) -> String {
        if let kw = keywords[word] { return kw }
        if let ty = types[word] { return ty }
        // Capitalized words are type names by convention.
        if let first = word.first, first.isUppercase {
            return "A type name (types are Capitalized by convention)."
        }
        return "A name you chose — a variable, constant, function, or parameter."
    }

    private static func matchOperator(_ chars: [Character], at i: Int) -> (String, String)? {
        for (op, meaning) in multiCharOperators {
            let opChars = Array(op)
            if i + opChars.count <= chars.count, Array(chars[i..<i + opChars.count]) == opChars {
                return (op, meaning)
            }
        }
        return nil
    }

    private static func explanationForSymbol(_ s: String) -> String {
        symbols[s] ?? "A symbol Swift uses to structure the code."
    }

    private static let keywords: [String: String] = [
        "let": "Creates a constant — a name whose value cannot change.",
        "var": "Creates a variable — a name whose value can change.",
        "func": "Defines a function — a named, reusable block of code.",
        "return": "Sends a value back from a function to its caller.",
        "if": "Runs the following block only when its condition is true.",
        "else": "Runs when the matching if condition was false.",
        "guard": "Requires a condition to be true, or exits early via its else.",
        "for": "Starts a loop that repeats once per item.",
        "in": "Connects a loop's variable to the collection it loops over.",
        "while": "Starts a loop that repeats while its condition is true.",
        "struct": "Defines a struct — your own value type that groups data.",
        "class": "Defines a class — your own reference (shared) type.",
        "enum": "Defines an enum — a type with a fixed set of cases.",
        "case": "One option inside an enum, or one match in a switch.",
        "switch": "Chooses among several cases based on a value.",
        "throws": "Marks a function that can throw an error.",
        "throw": "Signals an error and stops the current work.",
        "do": "Starts a block where thrown errors can be caught.",
        "try": "Marks a call that might throw an error.",
        "catch": "Handles an error thrown inside a do block.",
        "import": "Brings in another module of code (e.g. Foundation, SwiftUI).",
        "true": "A Bool value meaning yes / on.",
        "false": "A Bool value meaning no / off.",
        "nil": "The absence of a value (used with optionals).",
        "self": "Refers to the current instance inside a type.",
        "print": "A Swift function that writes text to the console.",
        "default": "The fallback used when no other case matches."
    ]

    private static let types: [String: String] = [
        "String": "The text type — anything inside quotation marks.",
        "Int": "The whole-number type (no decimal point).",
        "Double": "The decimal-number type.",
        "Bool": "The true/false type.",
        "Error": "The protocol that error types conform to."
    ]

    // Order matters: longer operators are checked first.
    private static let multiCharOperators: [(String, String)] = [
        ("->", "Introduces a function's return type: what value it hands back."),
        ("==", "Equality test — true when both sides are equal."),
        ("!=", "Inequality test — true when the two sides differ."),
        ("<=", "\"Less than or equal to\" comparison."),
        (">=", "\"Greater than or equal to\" comparison."),
        ("&&", "The AND operator — true only when both sides are true."),
        ("||", "The OR operator — true when either side is true."),
        ("+=", "Adds the right value into the left one and stores the result."),
        ("-=", "Subtracts the right value from the left one and stores the result."),
        ("...", "A closed range including both ends."),
        ("..<", "A range up to, but not including, the end.")
    ]

    private static let symbols: [String: String] = [
        "(": "Opens a group — a function's inputs, or grouping in an expression.",
        ")": "Closes the group opened by (.",
        "{": "Opens a block of code — a body, closure, or type definition.",
        "}": "Closes the block opened by {.",
        "[": "Opens an array or dictionary, or a subscript lookup.",
        "]": "Closes the [ .",
        ":": "Separates a name from its type, or a key from its value.",
        ",": "Separates items in a list.",
        ".": "Reaches into a value to a property, method, or case.",
        "=": "Assignment — stores the value on the right into the name on the left.",
        "+": "The addition operator (or joins two Strings).",
        "-": "The subtraction operator.",
        "*": "The multiplication operator.",
        "/": "The division operator.",
        "<": "\"Less than\" comparison.",
        ">": "\"Greater than\" comparison.",
        "!": "\"Not\" — flips a Bool, or force-unwraps an optional.",
        "?": "Marks an optional — a value that might be missing.",
        "\"": "A quotation mark — marks the start or end of a String."
    ]
}
