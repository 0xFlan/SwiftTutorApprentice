// GlossaryEntry.swift
// ------------------------------------------------------------
// The glossary is how the app teaches vocabulary. Each entry has:
//   - term:  the word being defined (e.g. "String")
//   - short: a one-line definition shown as a hover tooltip
//   - deep:  a fuller explanation shown when the term is clicked
//
// Everything is stored in a plain Swift dictionary so it is easy
// to read and easy to extend. Each lesson chooses which terms to
// show via its `glossaryTerms` list.
//
// TODO: Move glossary content into data files loaded at runtime.
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

    /// All known entries, keyed by the lowercased term so lookups are
    /// case-insensitive.
    static let entries: [String: GlossaryEntry] = buildEntries()

    /// Look up an entry by term (case-insensitive). Returns nil if unknown.
    static func entry(for term: String) -> GlossaryEntry? {
        entries[term.lowercased()]
    }

    private static func buildEntries() -> [String: GlossaryEntry] {
        var byTerm: [String: GlossaryEntry] = [:]
        for entry in all {
            byTerm[entry.term.lowercased()] = entry
        }
        return byTerm
    }

    private static let all: [GlossaryEntry] = [

        // MARK: Language + tooling

        GlossaryEntry(
            term: "Swift",
            short: "Apple's modern programming language.",
            deep: """
            Swift is the programming language Apple created for building apps on \
            macOS, iOS, iPadOS, watchOS, tvOS, and visionOS.

            It is designed to be safe (it catches many mistakes before your app \
            runs), fast, and readable. The code you write here is the same \
            language used to build real Apple apps.
            """
        ),
        GlossaryEntry(
            term: "compiler",
            short: "Turns your Swift code into a runnable program.",
            deep: """
            The compiler reads your Swift source code, checks it for mistakes, and \
            translates it into instructions the computer can run.

            If it finds an error — a missing quote, a typo in a name — it refuses \
            to build and tells you what is wrong. Learning to read those messages \
            is a core skill.
            """
        ),

        // MARK: Values and types

        GlossaryEntry(
            term: "value",
            short: "A single piece of data, like a number or some text.",
            deep: """
            A value is one concrete piece of data your program works with: the \
            number 5, the text "Alex", the answer true.

            Programming is mostly creating values, storing them under names, \
            transforming them, and showing them.
            """
        ),
        GlossaryEntry(
            term: "type",
            short: "What kind of value something is (text, number, true/false…).",
            deep: """
            Every value in Swift has a type — a category that says what it is and \
            what you can do with it.

            "Alex" is a String (text). 5 is an Int (whole number). true is a Bool. \
            Types are how Swift stops you from doing nonsense like subtracting text \
            from a number.
            """
        ),
        GlossaryEntry(
            term: "String",
            short: "A String is text.",
            deep: """
            A String stores text, like "Hello", "Alex", or "iPhone". Swift treats \
            anything inside quotation marks as text.

            "34" is a String, but 34 is an Int (a whole number). The difference \
            matters: you can do math with an Int, but a String is just characters.
            """
        ),
        GlossaryEntry(
            term: "Int",
            short: "A whole number, like 3 or -12.",
            deep: """
            An Int is a whole number: 0, 1, 42, -7. No decimal point, no quotation \
            marks.

            You can do math with Int values (+, -, *, /). Because 5 is an Int and \
            "5" is a String, Swift treats them very differently — one is a number, \
            the other is text.
            """
        ),
        GlossaryEntry(
            term: "Bool",
            short: "A true/false value.",
            deep: """
            A Bool (short for "Boolean") is a value that is either true or false — \
            nothing else.

            Comparisons produce Bool values: hour < 12 is true or false. if \
            statements use a Bool to decide whether to run a block of code.
            """
        ),

        // MARK: Names and storage

        GlossaryEntry(
            term: "constant",
            short: "A named value that cannot change (made with let).",
            deep: """
            A constant is a name for a value that will not change after you set it. \
            You create one with the keyword let.

            let name = "Alex" makes a constant. Trying to change it later is an \
            error. Prefer constants when a value shouldn't change — it makes your \
            intent clear and prevents accidental edits.
            """
        ),
        GlossaryEntry(
            term: "variable",
            short: "A named value that CAN change (made with var).",
            deep: """
            A variable is a name for a value that you can change later. You create \
            one with the keyword var.

            var count = 1 makes a variable; count = 2 then replaces the value. Use \
            a variable only when the value genuinely needs to change.
            """
        ),
        GlossaryEntry(
            term: "let",
            short: "Keyword that creates a constant (unchangeable).",
            deep: """
            let creates a constant — a name whose value cannot change once set.

            let name = "Alex"

            If you try to reassign it later, Swift refuses to build. Reach for let \
            by default; switch to var only when you actually need to change the value.
            """
        ),
        GlossaryEntry(
            term: "var",
            short: "Keyword that creates a variable (changeable).",
            deep: """
            var creates a variable — a name whose value can change later.

            var count = 1
            count = 2   // allowed, because count is a var

            The same reassignment on a let would be an error.
            """
        ),
        GlossaryEntry(
            term: "assignment",
            short: "Using = to store a value into a name.",
            deep: """
            Assignment uses the = symbol to store the value on the right into the \
            name on the left.

            let name = "Alex"   // stores "Alex" into name

            Important: = does NOT mean "equals" like in math. It means "put this \
            value into this name". (Swift uses == to test whether two things are equal.)
            """
        ),

        // MARK: Doing things with values

        GlossaryEntry(
            term: "operator",
            short: "A symbol that combines or compares values (+, -, <, ==).",
            deep: """
            An operator is a symbol that does something to values. + adds, - \
            subtracts, * multiplies. < and > compare. == tests for equality.

            2 + 3 uses the + operator to produce 5.
            """
        ),
        GlossaryEntry(
            term: "expression",
            short: "A piece of code that produces a value.",
            deep: """
            An expression is any piece of code that Swift can work out to a single \
            value.

            2 + 3 is an expression that becomes 5. "Hi" is an expression (its value \
            is that String). hour < 12 is an expression whose value is a Bool.
            """
        ),
        GlossaryEntry(
            term: "comparison",
            short: "Checking how two values relate (<, >, ==).",
            deep: """
            A comparison checks the relationship between two values and produces a \
            Bool (true or false).

            hour < 12   // "is hour less than 12?" -> true or false

            Common comparison operators: < less than, > greater than, == equal to, \
            != not equal to, <= and >=.
            """
        ),
        GlossaryEntry(
            term: "string interpolation",
            short: "Dropping a value into a String with \\(  ).",
            deep: """
            String interpolation lets you insert a value into a String using \
            \\(  ) inside the quotation marks.

            let name = "Alex"
            print("Hello, \\(name)!")   // prints Hello, Alex!

            Swift replaces \\(name) with the value stored in name. Everything else \
            between the quotes stays as literal text.
            """
        ),

        // MARK: Structure

        GlossaryEntry(
            term: "condition",
            short: "A true/false test that decides whether code runs.",
            deep: """
            A condition is an expression that produces a Bool, used to decide \
            whether a block of code should run.

            In if hour < 12 { ... }, the condition is hour < 12. If it's true, the \
            braces run; if false, they're skipped.
            """
        ),
        GlossaryEntry(
            term: "if",
            short: "Runs a block of code only when a condition is true.",
            deep: """
            if lets your program make a decision. You give it a condition; if that \
            condition is true, the code inside the following { } braces runs. If \
            it's false, Swift skips that code.

            You can add else to provide code that runs when the condition is false.
            """
        ),
        GlossaryEntry(
            term: "braces",
            short: "The { } that group a block of code together.",
            deep: """
            Braces — the { and } symbols — group lines of code into a block that \
            belongs together.

            The body of an if, a loop, or a function lives inside braces. Every { \
            needs a matching }. Swift uses them to know exactly which lines belong \
            to which piece of code.
            """
        ),

        // MARK: Functions

        GlossaryEntry(
            term: "function",
            short: "A named block of code you can run.",
            deep: """
            A function is a reusable block of code that does one job. You define it \
            with func, and you "call" (run) it by writing its name followed by \
            parentheses, like greet().

            A function can take inputs, called parameters, inside the parentheses, \
            and can give back a result. Real Apple apps are built almost entirely \
            out of functions calling other functions.
            """
        ),
        GlossaryEntry(
            term: "function call",
            short: "Running a function by writing its name and ( ).",
            deep: """
            Calling a function means running it. You write its name followed by \
            parentheses: print("Hi") or greet().

            Defining a function (with func) just describes what it does. Nothing \
            happens until you CALL it. Those are two separate steps.
            """
        ),
        GlossaryEntry(
            term: "parameter",
            short: "An input a function accepts inside its ( ).",
            deep: """
            A parameter is a named input a function accepts. It goes inside the \
            parentheses when you define the function, and you supply a value (an \
            argument) when you call it.

            func greet(name: String) { ... } declares a parameter called name. \
            greet(name: "Alex") calls it with the argument "Alex". A function with \
            empty () takes no parameters.
            """
        ),

        // MARK: Running programs

        GlossaryEntry(
            term: "console",
            short: "The text area where a program prints messages.",
            deep: """
            The console is a text area where a program writes messages for a human \
            to read.

            In Terminal, the console is the window you typed the command into. In \
            Xcode, it is the debug area at the bottom. When you call print(...), \
            the text shows up there.
            """
        ),
        GlossaryEntry(
            term: "standard output",
            short: "The normal output stream, called stdout.",
            deep: """
            Standard output — usually written as "stdout" — is the default place a \
            program sends its normal text.

            print(...) writes to standard output. Tools (including this app) can \
            capture that text. When your program works correctly, its results \
            appear on stdout.
            """
        ),
        GlossaryEntry(
            term: "standard error",
            short: "The separate error stream, called stderr.",
            deep: """
            Standard error — usually written as "stderr" — is a separate stream \
            just for error and warning messages.

            Keeping errors separate from normal output means a program's results \
            don't get tangled up with its complaints. When something goes wrong, \
            read stderr first.
            """
        ),
        GlossaryEntry(
            term: "exit code",
            short: "A number showing success (0) or failure.",
            deep: """
            When a program finishes, it hands back a single number called an exit \
            code.

            0 means success — everything ran cleanly. Any other number (like 1) \
            usually means something went wrong. Command-line tools use this number \
            to decide what to do next.
            """
        ),

        // MARK: More fundamentals

        GlossaryEntry(
            term: "else",
            short: "The code to run when an if condition is false.",
            deep: """
            else attaches to an if. It provides the code that runs when the if's \
            condition is false.

            if hour < 12 { ... } else { ... }

            Exactly one of the two blocks runs. You can also chain else if to test \
            more conditions in turn.
            """
        ),
        GlossaryEntry(
            term: "Double",
            short: "A number with a decimal point, like 1.5.",
            deep: """
            A Double holds a number that can have a fractional part: 1.5, 3.14, \
            2.0. The decimal point is what makes it a Double rather than an Int.

            Use Int for whole-number counts, and Double for measurements, prices, \
            and anything that needs fractions.
            """
        ),
        GlossaryEntry(
            term: "array",
            short: "An ordered list of values, written in [ ].",
            deep: """
            An array is a single value that holds many values in order, written \
            inside square brackets: ["Alex", "Sam", "Jo"].

            You read items by their index (position): names[0] is the first item. \
            Indexes start at 0. Arrays are one of the most-used tools in Swift.
            """
        ),
        GlossaryEntry(
            term: "index",
            short: "A position in an array. Counting starts at 0.",
            deep: """
            An index is the position of an item in an array. Swift counts from 0, \
            so the first item is at index 0, the second at index 1, and so on.

            names[0] means "the item at index 0" — the first one. Asking for an \
            index that doesn't exist (like names[99] on a short array) crashes, so \
            indexes must be valid.
            """
        ),
        GlossaryEntry(
            term: "loop",
            short: "Code that repeats, e.g. once per item with for-in.",
            deep: """
            A loop runs the same block of code multiple times. A for-in loop runs \
            once for each item in a collection:

            for name in names { print(name) }

            Each time around, the loop variable (name) holds the next item. Loops \
            save you from copy-pasting the same code over and over.
            """
        ),
        GlossaryEntry(
            term: "optional",
            short: "A value that might be there, or might be nil (nothing).",
            deep: """
            An optional can hold a value OR hold nothing (nil). You mark a type \
            optional with a ?: String? is "a String or nothing".

            Swift forces you to handle the "nothing" case, which prevents a whole \
            category of crashes. A common way to safely use one is if let:

            if let name = maybeName { /* runs only if there's a value */ }
            """
        ),
        GlossaryEntry(
            term: "dictionary",
            short: "Values stored under keys you choose, like a lookup table.",
            deep: """
            A dictionary stores key: value pairs. Instead of finding items by \
            position (like an array), you find them by a key you choose:

            let ages = ["Alex": 30, "Sam": 25]
            ages["Alex"]   // looks up 30 by the key "Alex"

            Great for "look something up by name/id" situations.
            """
        ),
        GlossaryEntry(
            term: "struct",
            short: "Your own type that groups related values together.",
            deep: """
            A struct lets you define a new type that bundles related values \
            (called properties) into one thing:

            struct Dog { let name: String }

            You then create instances from it: Dog(name: "Rex"). Structs are \
            central to Swift and SwiftUI — even a View is a struct.
            """
        ),
        GlossaryEntry(
            term: "property",
            short: "A named value that belongs to a struct or type.",
            deep: """
            A property is a value stored inside a type. In struct Dog { let name: \
            String }, name is a property — every Dog has one.

            You read a property with dot syntax: rex.name. Properties are how a \
            type remembers its data.
            """
        ),
        GlossaryEntry(
            term: "return",
            short: "Sends a value back from a function to its caller.",
            deep: """
            return hands a value back to whoever called the function, and ends the \
            function right there.

            func double(_ n: Int) -> Int { return n * 2 }

            The -> Int part declares what type comes back. double(5) becomes 10 at \
            the place it was called. Returning values lets functions compute \
            results you can use elsewhere.
            """
        )
    ]
}
