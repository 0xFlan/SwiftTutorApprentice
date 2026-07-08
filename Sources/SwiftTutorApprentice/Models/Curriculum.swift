// Curriculum.swift
// ------------------------------------------------------------
// The actual course content. Every lesson is plain data, so the
// whole app is driven by this one file: add a Lesson here and it
// shows up in the sidebar with its own terms, syntax breakdown,
// coaching, and expected output.
//
// The lessons build on each other: print -> constants -> variables
// -> string interpolation -> math -> decisions -> your own function.
// ------------------------------------------------------------

import Foundation

enum Curriculum {

    /// Every lesson, in order. The sidebar shows them like this.
    static let lessons: [Lesson] = [
        lesson1, lesson2, lesson3, lesson4, lesson5, lesson6, lesson7
    ]

    /// Convenience: find a lesson by its id.
    static func lesson(id: Int) -> Lesson? {
        lessons.first { $0.id == id }
    }

    // MARK: - Lesson 1: Printing Text

    static let lesson1 = Lesson(
        id: 1,
        title: "Printing Text in Swift",
        goal: "Learn how to display text in the console using print.",
        starterCode: "print(\"Hello, Swift!\")",
        teaches: ["print", "function call", "parentheses", "quotation marks", "String", "console output"],
        glossaryTerms: ["Swift", "String", "function", "function call", "console", "standard output", "exit code"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "print", explanation: "A Swift function that writes something to the console."),
            SyntaxToken(id: 1, display: "(", explanation: "Starts the input area for the function. Swift needs it so it knows where the function's input begins."),
            SyntaxToken(id: 2, display: "\"", explanation: "Starts a piece of text. Everything after this quotation mark is treated as literal text until the next one."),
            SyntaxToken(id: 3, display: "Hello, Swift!", explanation: "The exact text value being passed into print. This is a String."),
            SyntaxToken(id: 4, display: "\"", explanation: "Ends the text. A pair of quotation marks marks the start and end of a String."),
            SyntaxToken(id: 5, display: ")", explanation: "Ends the input area for the function.")
        ],
        syntaxWhy: """
        Swift needs the parentheses ( ) so it knows where the function's input \
        starts and ends.

        Swift needs the quotation marks " " so it knows Hello, Swift! is literal \
        text, not the name of a variable or function.
        """,
        expectedOutput: "Hello, Swift!",
        successMarkers: ["print(", "Hello, Swift!"],
        successMessage: """
        Good. This calls the print function and gives it one String: "Hello, Swift!".

        • print sends text to the console.
        • The parentheses hold the input for the function.
        • The quotation marks tell Swift this is text.
        """,
        hint: """
        For this lesson, call the print function with a String, like this:
        print("Hello, Swift!")
        """
    )

    // MARK: - Lesson 2: Storing Text in a Constant

    static let lesson2 = Lesson(
        id: 2,
        title: "Storing Text in a Constant",
        goal: "Store a value in a named constant with let, then use it.",
        starterCode: "let name = \"Alex\"\nprint(name)",
        teaches: ["let", "constant", "naming a value", "using a value", "String"],
        glossaryTerms: ["let", "constant", "value", "assignment", "String", "function call"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "let", explanation: "A keyword that creates a constant: a name whose value cannot change once set."),
            SyntaxToken(id: 1, display: "name", explanation: "The name you chose to refer to the value. You could have called it anything."),
            SyntaxToken(id: 2, display: "=", explanation: "The assignment operator. It stores the value on the right into the name on the left."),
            SyntaxToken(id: 3, display: "\"Alex\"", explanation: "A String value. The quotation marks make it text.")
        ],
        syntaxWhy: """
        let name = "Alex" creates a constant called name that holds the text "Alex".

        Notice the next line is print(name), with NO quotation marks around name. \
        That's on purpose: without quotes, Swift uses the VALUE stored in name \
        ("Alex"). With quotes, print("name") would print the literal word name.
        """,
        expectedOutput: "Alex",
        successMarkers: ["let name", "print(name)"],
        successMessage: """
        Nice. You created a constant called name that holds the String "Alex", \
        then printed the value stored inside it.
        """,
        hint: """
        Make a constant with let, give it a text value, then print the constant by \
        name (no quotation marks):
        let name = "Alex"
        print(name)
        """
    )

    // MARK: - Lesson 3: Variables You Can Change

    static let lesson3 = Lesson(
        id: 3,
        title: "Variables You Can Change",
        goal: "Use var to make a value you can change later, and see the difference from let.",
        starterCode: "var count = 1\ncount = 2\nprint(count)",
        teaches: ["var", "variable", "Int", "changing a value"],
        glossaryTerms: ["var", "variable", "constant", "Int", "assignment", "value"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "var", explanation: "A keyword that creates a variable: a name whose value CAN change later."),
            SyntaxToken(id: 1, display: "count", explanation: "The name for the value."),
            SyntaxToken(id: 2, display: "=", explanation: "The assignment operator. It stores the value on the right into count."),
            SyntaxToken(id: 3, display: "1", explanation: "An Int (a whole number). No quotation marks, so Swift treats it as a number, not text.")
        ],
        syntaxWhy: """
        let makes a constant (its value can't change). var makes a variable (its \
        value can change).

        Because we used var, the line count = 2 is allowed — it replaces the old \
        value. If count had been a let, Swift would refuse to build and show an error.

        Also note: 1 has no quotation marks, so it is the number one (an Int), not \
        the text "1".
        """,
        expectedOutput: "2",
        successMarkers: ["var count", "count = 2", "print(count)"],
        successMessage: """
        You made a variable with var, changed its value, then printed it. Because \
        it's a var (not a let), reassigning the value was allowed.
        """,
        hint: """
        Use var so the value can change:
        var count = 1
        count = 2
        print(count)
        """
    )

    // MARK: - Lesson 4: Combining Text with String Interpolation

    static let lesson4 = Lesson(
        id: 4,
        title: "Combining Text with Interpolation",
        goal: "Drop a value into a String using string interpolation.",
        starterCode: "let name = \"Alex\"\nprint(\"Hello, \\(name)!\")",
        teaches: ["string interpolation", "\\(  )", "combining text and values", "String"],
        glossaryTerms: ["string interpolation", "String", "constant", "value"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "print", explanation: "The function that writes to the console."),
            SyntaxToken(id: 1, display: "(", explanation: "Starts print's input."),
            SyntaxToken(id: 2, display: "\"", explanation: "Starts the text."),
            SyntaxToken(id: 3, display: "Hello, ", explanation: "Literal text. Swift keeps it exactly as written."),
            SyntaxToken(id: 4, display: "\\(name)", explanation: "String interpolation. Swift replaces this with the value stored in name."),
            SyntaxToken(id: 5, display: "!", explanation: "More literal text, added after the value."),
            SyntaxToken(id: 6, display: "\"", explanation: "Ends the text."),
            SyntaxToken(id: 7, display: ")", explanation: "Ends print's input.")
        ],
        syntaxWhy: """
        Inside a String, \\(something) is a little hole that Swift fills in with a \
        value. Here \\(name) becomes Alex, so the whole String becomes "Hello, Alex!".

        Everything else between the quotation marks stays as literal text. This is \
        how you build up messages from fixed text plus changing values.
        """,
        expectedOutput: "Hello, Alex!",
        successMarkers: ["let name", "\\(name)"],
        successMessage: """
        You used string interpolation. \\(name) was replaced with the value Alex, \
        producing Hello, Alex!
        """,
        hint: """
        Put \\(name) inside the quotation marks to drop the value of name into your text:
        let name = "Alex"
        print("Hello, \\(name)!")
        """
    )

    // MARK: - Lesson 5: Numbers and Simple Math

    static let lesson5 = Lesson(
        id: 5,
        title: "Numbers and Simple Math",
        goal: "Work out a value with an expression, store the result, and print it.",
        starterCode: "let total = 2 + 3\nprint(total)",
        teaches: ["Int", "operator", "expression", "doing math"],
        glossaryTerms: ["Int", "operator", "expression", "constant", "value"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "let", explanation: "Makes a constant to hold the result."),
            SyntaxToken(id: 1, display: "total", explanation: "The name for the result."),
            SyntaxToken(id: 2, display: "=", explanation: "Assignment. Stores the result on the right into total."),
            SyntaxToken(id: 3, display: "2", explanation: "An Int (a whole number)."),
            SyntaxToken(id: 4, display: "+", explanation: "The addition operator. It adds the two numbers."),
            SyntaxToken(id: 5, display: "3", explanation: "An Int.")
        ],
        syntaxWhy: """
        2 + 3 is an expression — a small calculation. Swift works it out to a single \
        value (5) first, then the = stores that value in total.

        Because the numbers have no quotation marks, they are Int values you can do \
        math with. "2" + "3" (with quotes) would be text and behave completely \
        differently.
        """,
        expectedOutput: "5",
        successMarkers: ["let total", "+", "print(total)"],
        successMessage: """
        You stored the result of the expression 2 + 3 (which is 5) in a constant, \
        then printed it.
        """,
        hint: """
        Add two numbers with +, store the result with let, then print it:
        let total = 2 + 3
        print(total)
        """
    )

    // MARK: - Lesson 6: Making Decisions with if

    static let lesson6 = Lesson(
        id: 6,
        title: "Making Decisions with if",
        goal: "Run some code only when a condition is true.",
        starterCode: "let hour = 9\nif hour < 12 {\n    print(\"Good morning\")\n}",
        teaches: ["if", "condition", "Bool", "comparison", "braces"],
        glossaryTerms: ["if", "condition", "Bool", "comparison", "braces", "Int"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "if", explanation: "Runs the code in the braces only when the condition that follows is true."),
            SyntaxToken(id: 1, display: "hour", explanation: "The value being tested."),
            SyntaxToken(id: 2, display: "<", explanation: "The \"less than\" comparison operator. It produces a Bool: true or false."),
            SyntaxToken(id: 3, display: "12", explanation: "The Int being compared against."),
            SyntaxToken(id: 4, display: "{", explanation: "Opens a block — the code that runs when the condition is true."),
            SyntaxToken(id: 5, display: "}", explanation: "Closes the block.")
        ],
        syntaxWhy: """
        if checks a condition. hour < 12 is a comparison that Swift turns into a \
        Bool — either true or false.

        If the condition is true, the code inside the { } braces runs. If it's \
        false, Swift skips it. The braces group the lines that belong to the if.
        """,
        expectedOutput: "Good morning",
        successMarkers: ["if", "<", "print("],
        successMessage: """
        You wrote an if statement. Swift checked the condition hour < 12, found it \
        true, and ran the code inside the braces.
        """,
        hint: """
        Use if with a condition, then put the code to run inside { } braces:
        let hour = 9
        if hour < 12 {
            print("Good morning")
        }
        """
    )

    // MARK: - Lesson 7: Writing Your Own Function

    static let lesson7 = Lesson(
        id: 7,
        title: "Writing Your Own Function",
        goal: "Define your own function, then call it to run its code.",
        starterCode: "func greet() {\n    print(\"Hi there\")\n}\ngreet()",
        teaches: ["func", "defining a function", "calling a function", "braces"],
        glossaryTerms: ["function", "function call", "parameter", "braces"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "func", explanation: "The keyword that DEFINES a new function."),
            SyntaxToken(id: 1, display: "greet", explanation: "The name you are giving your function."),
            SyntaxToken(id: 2, display: "()", explanation: "Where inputs (parameters) would go. Empty here means this function takes no input."),
            SyntaxToken(id: 3, display: "{", explanation: "Opens the function's body — the code it runs when called."),
            SyntaxToken(id: 4, display: "}", explanation: "Closes the function's body.")
        ],
        syntaxWhy: """
        func defines a function; it does not run it. The code inside the braces \
        only runs when you CALL the function by writing its name with parentheses: \
        greet().

        Defining and calling are two separate steps. That's why the starter has the \
        func block AND a separate greet() line at the bottom.
        """,
        expectedOutput: "Hi there",
        successMarkers: ["func", "greet", "print(", "greet()"],
        successMessage: """
        You defined your own function with func, then called it with greet(). \
        Defining set up the code; calling actually ran it.
        """,
        hint: """
        Define a function, then call it on its own line:
        func greet() {
            print("Hi there")
        }
        greet()
        """
    )
}
