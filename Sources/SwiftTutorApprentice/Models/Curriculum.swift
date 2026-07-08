// Curriculum.swift
// ------------------------------------------------------------
// The DEFAULT course content, defined in code. On first launch,
// the LessonStore copies these into an editable JSON file; from
// then on the app reads/writes that JSON, and you can add or edit
// lessons entirely inside the app. "Restore default lessons" in
// the lesson editor brings this set back.
//
// The lessons build on each other, from print all the way to
// your own functions and structs.
// ------------------------------------------------------------

import Foundation

enum Curriculum {

    /// The built-in starting curriculum, in order. The LessonStore seeds
    /// from this and can restore it on demand.
    static let defaultLessons: [Lesson] = [
        lesson1, lesson2, lesson3, lesson4, lesson5, lesson6, lesson7,
        lesson8, lesson9, lesson10, lesson11, lesson12, lesson13,
        lesson14, lesson15, lesson16, lesson17
    ]

    /// Convenience: find a default lesson by its id.
    static func defaultLesson(id: Int) -> Lesson? {
        defaultLessons.first { $0.id == id }
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

    // MARK: - Lesson 8: Making Decisions with else

    static let lesson8 = Lesson(
        id: 8,
        title: "Choosing Between Two Paths (else)",
        goal: "Run one block when a condition is true and a different block when it's false.",
        starterCode: "let hour = 15\nif hour < 12 {\n    print(\"Good morning\")\n} else {\n    print(\"Good afternoon\")\n}",
        teaches: ["else", "two-way choice", "condition", "braces"],
        glossaryTerms: ["if", "else", "condition", "Bool", "braces"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "if", explanation: "Checks the condition. If true, its braces run."),
            SyntaxToken(id: 1, display: "hour < 12", explanation: "The condition — a comparison that is true or false."),
            SyntaxToken(id: 2, display: "}", explanation: "Closes the if block."),
            SyntaxToken(id: 3, display: "else", explanation: "Introduces the code to run when the if condition was FALSE."),
            SyntaxToken(id: 4, display: "{", explanation: "Opens the else block.")
        ],
        syntaxWhy: """
        Plain if runs code only when the condition is true. Adding else gives Swift \
        a second path: exactly one of the two blocks always runs.

        Here hour is 15, so hour < 12 is false — Swift skips the first block and \
        runs the else block instead.
        """,
        expectedOutput: "Good afternoon",
        successMarkers: ["if", "else", "print("],
        successMessage: """
        You gave your program a fork in the road. Because hour < 12 was false, Swift \
        ran the else block.
        """,
        hint: """
        Add an else block after the if to handle the "false" case:
        if hour < 12 {
            print("Good morning")
        } else {
            print("Good afternoon")
        }
        """
    )

    // MARK: - Lesson 9: Decimal Numbers (Double)

    static let lesson9 = Lesson(
        id: 9,
        title: "Decimal Numbers (Double)",
        goal: "Work with numbers that have a decimal point, not just whole numbers.",
        starterCode: "let price = 1.5 + 2.0\nprint(price)",
        teaches: ["Double", "decimal point", "operator", "expression"],
        glossaryTerms: ["Double", "Int", "operator", "expression", "value"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "let", explanation: "Makes a constant."),
            SyntaxToken(id: 1, display: "price", explanation: "The name for the result."),
            SyntaxToken(id: 2, display: "=", explanation: "Assignment. Stores the result into price."),
            SyntaxToken(id: 3, display: "1.5", explanation: "A Double: a number with a decimal point."),
            SyntaxToken(id: 4, display: "+", explanation: "The addition operator."),
            SyntaxToken(id: 5, display: "2.0", explanation: "Another Double. The .0 makes it a decimal number, not an Int.")
        ],
        syntaxWhy: """
        An Int is a whole number (3). A Double can have a fractional part (1.5, \
        2.0, 3.14). The decimal point is what tells Swift a number is a Double.

        1.5 + 2.0 gives 3.5. If you'd written 1 + 2 (no decimals), those would be \
        Int values and the answer would be the Int 3.
        """,
        expectedOutput: "3.5",
        successMarkers: ["let price", "+", "print(price)"],
        successMessage: """
        You added two Double values. The decimal points mean Swift kept the \
        fractional part, giving 3.5.
        """,
        hint: """
        Use numbers with decimal points so they're Doubles:
        let price = 1.5 + 2.0
        print(price)
        """
    )

    // MARK: - Lesson 10: True / False Logic

    static let lesson10 = Lesson(
        id: 10,
        title: "True / False Logic",
        goal: "Combine true/false values with the AND operator.",
        starterCode: "let isSunny = true\nlet isWarm = false\nprint(isSunny && isWarm)",
        teaches: ["Bool", "&& (and)", "combining conditions"],
        glossaryTerms: ["Bool", "operator", "condition", "value"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "isSunny", explanation: "A Bool value: true."),
            SyntaxToken(id: 1, display: "&&", explanation: "The AND operator. The whole thing is true only if BOTH sides are true."),
            SyntaxToken(id: 2, display: "isWarm", explanation: "A Bool value: false.")
        ],
        syntaxWhy: """
        && means "and". isSunny && isWarm is true only when isSunny AND isWarm are \
        both true. Here one of them is false, so the result is false.

        Related operators: || means "or" (true if EITHER side is true), and ! means \
        "not" (it flips true to false).
        """,
        expectedOutput: "false",
        successMarkers: ["true", "false", "&&"],
        successMessage: """
        You combined two Bool values with &&. Because one of them was false, the AND \
        result is false.
        """,
        hint: """
        Make two Bool values and combine them with &&:
        let isSunny = true
        let isWarm = false
        print(isSunny && isWarm)
        """
    )

    // MARK: - Lesson 11: Lists of Values (Arrays)

    static let lesson11 = Lesson(
        id: 11,
        title: "Lists of Values (Arrays)",
        goal: "Store several values in an array and read one back by its position.",
        starterCode: "let names = [\"Alex\", \"Sam\", \"Jo\"]\nprint(names[0])",
        teaches: ["array", "index", "reading an item"],
        glossaryTerms: ["array", "index", "String", "value"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "names", explanation: "The array — a single value that holds an ordered list."),
            SyntaxToken(id: 1, display: "[", explanation: "Starts a subscript: asking the array for one item by position."),
            SyntaxToken(id: 2, display: "0", explanation: "The index. Swift counts from 0, so 0 is the FIRST item."),
            SyntaxToken(id: 3, display: "]", explanation: "Ends the subscript.")
        ],
        syntaxWhy: """
        An array holds many values in order, written inside [ ] and separated by \
        commas. names[0] reads one item by its index.

        The big surprise for beginners: indexes start at 0, not 1. So names[0] is \
        "Alex", names[1] is "Sam", and names[2] is "Jo".
        """,
        expectedOutput: "Alex",
        successMarkers: ["let names", "names[0]"],
        successMessage: """
        You made an array of three names and read the first one with names[0]. \
        Remember: index 0 is the first item.
        """,
        hint: """
        Make an array with [ ], then read the first item with index 0:
        let names = ["Alex", "Sam", "Jo"]
        print(names[0])
        """
    )

    // MARK: - Lesson 12: Repeating with a Loop

    static let lesson12 = Lesson(
        id: 12,
        title: "Repeating with a Loop",
        goal: "Run the same code once for each item in an array using a for-in loop.",
        starterCode: "let names = [\"Alex\", \"Sam\"]\nfor name in names {\n    print(name)\n}",
        teaches: ["loop", "for-in", "iteration", "array"],
        glossaryTerms: ["loop", "array", "braces", "value"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "for", explanation: "Starts a loop that repeats once per item."),
            SyntaxToken(id: 1, display: "name", explanation: "A temporary name that holds the CURRENT item on each pass through the loop."),
            SyntaxToken(id: 2, display: "in", explanation: "Connects the loop variable to the collection being looped over."),
            SyntaxToken(id: 3, display: "names", explanation: "The array to loop over."),
            SyntaxToken(id: 4, display: "{", explanation: "Opens the body — the code that runs each time.")
        ],
        syntaxWhy: """
        A for-in loop runs its body once for every item in a collection. Each time \
        around, name holds the next item.

        So this prints Alex, then Sam — two lines, because the array has two items. \
        Loops let you avoid writing the same print twice.
        """,
        expectedOutput: "Alex\nSam",
        successMarkers: ["for", "in", "print(name)"],
        successMessage: """
        You wrote a loop. Swift ran the print once for each name in the array, \
        producing one line per item.
        """,
        hint: """
        Loop over the array with for-in and print each item:
        for name in names {
            print(name)
        }
        """
    )

    // MARK: - Lesson 13: Values That Might Be Missing (Optionals)

    static let lesson13 = Lesson(
        id: 13,
        title: "Values That Might Be Missing (Optionals)",
        goal: "Handle a value that may or may not exist, safely, with if let.",
        starterCode: "let maybeName: String? = \"Alex\"\nif let name = maybeName {\n    print(name)\n}",
        teaches: ["optional", "String?", "if let", "nil"],
        glossaryTerms: ["optional", "String", "if", "value"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "maybeName", explanation: "The name of our possibly-missing value."),
            SyntaxToken(id: 1, display: ":", explanation: "A type annotation: we're about to say what type maybeName is."),
            SyntaxToken(id: 2, display: "String?", explanation: "An OPTIONAL String. The ? means it holds either a String or nothing (nil)."),
            SyntaxToken(id: 3, display: "if let name = maybeName", explanation: "Optional binding: IF there is a value, put it in name and run the block."),
            SyntaxToken(id: 4, display: "{", explanation: "Opens the block that only runs when a value was present.")
        ],
        syntaxWhy: """
        A normal String always has text. An optional String (String?) might have \
        text, or might be nil (nothing). Swift makes you deal with the "nothing" \
        case on purpose — that's how it prevents a huge class of crashes.

        if let safely unwraps it: if maybeName has a value, name gets it and the \
        block runs; if it's nil, Swift skips the block.
        """,
        expectedOutput: "Alex",
        successMarkers: ["String?", "if let", "print(name)"],
        successMessage: """
        You handled an optional safely. Because maybeName held "Alex" (not nil), the \
        if let unwrapped it and printed the value.
        """,
        hint: """
        Mark the type optional with ?, then unwrap it with if let:
        let maybeName: String? = "Alex"
        if let name = maybeName {
            print(name)
        }
        """
    )

    // MARK: - Lesson 14: Looking Things Up (Dictionaries)

    static let lesson14 = Lesson(
        id: 14,
        title: "Looking Things Up (Dictionaries)",
        goal: "Store values under named keys and look one up.",
        starterCode: "let ages = [\"Alex\": 30, \"Sam\": 25]\nprint(ages[\"Alex\", default: 0])",
        teaches: ["dictionary", "key and value", "lookup"],
        glossaryTerms: ["dictionary", "array", "Int", "value"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "[", explanation: "Starts a dictionary literal."),
            SyntaxToken(id: 1, display: "\"Alex\"", explanation: "A key — the label you look values up by."),
            SyntaxToken(id: 2, display: ":", explanation: "Pairs a key with its value."),
            SyntaxToken(id: 3, display: "30", explanation: "The value stored under the key \"Alex\"."),
            SyntaxToken(id: 4, display: "default: 0", explanation: "What to use if the key isn't found, so the lookup always returns a value.")
        ],
        syntaxWhy: """
        An array finds items by position (0, 1, 2). A dictionary finds them by a \
        KEY you choose — here, a person's name. Each entry is a key: value pair.

        ages["Alex"] could be missing, so it's normally optional. Adding \
        , default: 0 says "if Alex isn't there, give me 0 instead", so we get a \
        plain Int back.
        """,
        expectedOutput: "30",
        successMarkers: ["ages", "default:", "print("],
        successMessage: """
        You looked up a value by its key. "Alex" maps to 30, so that's what printed.
        """,
        hint: """
        Make a dictionary of key: value pairs, then look one up:
        let ages = ["Alex": 30, "Sam": 25]
        print(ages["Alex", default: 0])
        """
    )

    // MARK: - Lesson 15: Grouping Data with a Struct

    static let lesson15 = Lesson(
        id: 15,
        title: "Grouping Data with a Struct",
        goal: "Create your own type that bundles related values together.",
        starterCode: "struct Dog {\n    let name: String\n}\nlet rex = Dog(name: \"Rex\")\nprint(rex.name)",
        teaches: ["struct", "property", "instance", "dot syntax"],
        glossaryTerms: ["struct", "property", "String", "value"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "struct", explanation: "Defines a new type that bundles related values together."),
            SyntaxToken(id: 1, display: "Dog", explanation: "The name of your new type. Type names are Capitalized by convention."),
            SyntaxToken(id: 2, display: "let name: String", explanation: "A property: a named value that every Dog will have."),
            SyntaxToken(id: 3, display: "Dog(name: \"Rex\")", explanation: "Creates an instance — one actual Dog — with its name set."),
            SyntaxToken(id: 4, display: "rex.name", explanation: "Dot syntax: reach into rex and read its name property.")
        ],
        syntaxWhy: """
        A struct lets you invent your own type. String, Int, and Bool are built in; \
        a struct groups several of those into one meaningful thing (a Dog with a \
        name, later maybe an age and breed too).

        struct Dog { ... } is the blueprint. Dog(name: "Rex") builds one from it. \
        rex.name reads a property off that specific dog. Structs are everywhere in \
        SwiftUI — even a View is a struct.
        """,
        expectedOutput: "Rex",
        successMarkers: ["struct", "Dog(name:", "rex.name"],
        successMessage: """
        You defined your own type with struct, created an instance, and read its \
        property with dot syntax. This is the foundation of modeling data in Swift.
        """,
        hint: """
        Define a struct with a property, make one, then read the property:
        struct Dog {
            let name: String
        }
        let rex = Dog(name: "Rex")
        print(rex.name)
        """
    )

    // MARK: - Lesson 16: Functions with Input (Parameters)

    static let lesson16 = Lesson(
        id: 16,
        title: "Functions with Input (Parameters)",
        goal: "Write a function that takes an input and uses it.",
        starterCode: "func greet(name: String) {\n    print(\"Hi, \\(name)!\")\n}\ngreet(name: \"Alex\")",
        teaches: ["parameter", "argument", "passing input"],
        glossaryTerms: ["function", "parameter", "function call", "string interpolation"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "func greet", explanation: "Defines a function named greet."),
            SyntaxToken(id: 1, display: "(name: String)", explanation: "A parameter: greet needs one input called name, which must be a String."),
            SyntaxToken(id: 2, display: "{ ... }", explanation: "The body, which can use name like any value."),
            SyntaxToken(id: 3, display: "greet(name: \"Alex\")", explanation: "Calls greet and supplies the argument \"Alex\" for the name parameter.")
        ],
        syntaxWhy: """
        A parameter is an input a function accepts. greet(name: String) says "to \
        call me, give me a String called name". Inside, name holds whatever you \
        passed in.

        When calling, you write the label: greet(name: "Alex"). Now the same \
        function can greet anyone — that reuse is the whole point of parameters.
        """,
        expectedOutput: "Hi, Alex!",
        successMarkers: ["func greet", "name: String", "greet(name:"],
        successMessage: """
        You gave a function an input. greet used the name parameter you passed in to \
        build its message.
        """,
        hint: """
        Add a parameter in the parentheses, then pass a value when you call:
        func greet(name: String) {
            print("Hi, \\(name)!")
        }
        greet(name: "Alex")
        """
    )

    // MARK: - Lesson 17: Functions That Give Back a Value (return)

    static let lesson17 = Lesson(
        id: 17,
        title: "Functions That Give Back a Value",
        goal: "Write a function that computes a result and returns it to the caller.",
        starterCode: "func double(_ number: Int) -> Int {\n    return number * 2\n}\nprint(double(5))",
        teaches: ["return", "return type", "->", "reusing results"],
        glossaryTerms: ["function", "parameter", "return", "Int"],
        syntaxTokens: [
            SyntaxToken(id: 0, display: "func double", explanation: "Defines a function named double."),
            SyntaxToken(id: 1, display: "(_ number: Int)", explanation: "One parameter, number. The _ means you don't write a label when calling."),
            SyntaxToken(id: 2, display: "->", explanation: "Introduces the return type: what kind of value this function hands back."),
            SyntaxToken(id: 3, display: "Int", explanation: "The type of value double gives back — a whole number."),
            SyntaxToken(id: 4, display: "return", explanation: "Sends a value back to whoever called the function.")
        ],
        syntaxWhy: """
        Some functions just DO something (print). Others compute a value and give \
        it back — that's what -> ReturnType and return are for.

        double(5) runs the body, hits return number * 2, and hands back 10. That 10 \
        replaces double(5) right where it was called, so print(double(5)) prints 10. \
        Returning values is how you build big programs out of small, reusable pieces.
        """,
        expectedOutput: "10",
        successMarkers: ["->", "return", "double("],
        successMessage: """
        You wrote a function that returns a value. double(5) computed 10 and handed \
        it back, so print showed 10.
        """,
        hint: """
        Declare a return type with ->, then send a value back with return:
        func double(_ number: Int) -> Int {
            return number * 2
        }
        print(double(5))
        """
    )
}
