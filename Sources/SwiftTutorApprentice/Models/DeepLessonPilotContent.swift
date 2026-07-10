// DeepLessonPilotContent.swift
// ------------------------------------------------------------
// Beginner-first Deep Lesson content for the first three built-in
// lessons. Keeping the pilot here makes its scope easy to see.
// ------------------------------------------------------------

import Foundation

enum DeepLessonPilotContent {
    static let lesson1 = LessonDeepContent(
        title: "How a print Call Becomes Output",
        introduction: "A print call gives Swift one value to show. Standard output is the program's normal output stream; this app captures that stream and shows it in the console.",
        segments: [
            DeepLessonSegment(
                id: "lesson-1-print-call",
                title: "Call a function with an input",
                explanation: "print is a function: a named action Swift already knows. Writing its name followed by paired parentheses calls that action, and the value between the parentheses is the input it sends to standard output.",
                correctCode: "print(\"Hello, Swift!\")",
                wrongCode: "print \"Hello, Swift!\"",
                wrongExplanation: "Without the paired parentheses, Swift cannot read this as a normal function call with an input."
            ),
            DeepLessonSegment(
                id: "lesson-1-missing-quotes",
                title: "Mark text with paired quotation marks",
                explanation: "Paired quotation marks make a String literal: text written directly in the code. They tell Swift where the text begins and ends; they are not part of the printed message.",
                correctCode: "print(\"Hello, Swift!\")",
                wrongCode: "print(Hello, Swift!)",
                wrongExplanation: "Without quotation marks, Swift tries to understand Hello and Swift as code instead of one piece of text."
            ),
            DeepLessonSegment(
                id: "lesson-1-different-literal",
                title: "The literal is the data",
                explanation: "The characters inside the quotation marks are the value you give print. Changing those characters is valid Swift, but it changes the message the program sends to standard output.",
                correctCode: "print(\"Hello, Swift!\")",
                wrongCode: "print(\"Goodbye, Swift!\")",
                wrongExplanation: "This call is valid, but its different String literal produces different output: Goodbye, Swift!"
            ),
            DeepLessonSegment(
                id: "lesson-1-space-location",
                title: "Know which spaces are data",
                explanation: "A space inside the quotation marks belongs to the String and appears in the output. In this exact call, optional spaces immediately inside print's parentheses only change formatting. Elsewhere, some whitespace separates tokens, and operator whitespace can matter to how Swift reads code.",
                correctCode: "print(\"Hello, Swift!\")",
                wrongCode: "print(\"Hello,Swift!\")",
                wrongExplanation: "Removing the space inside the String changes the data, so the output becomes Hello,Swift!"
            )
        ],
        microscopeTokens: [
            SyntaxMicroscopeToken(
                id: "lesson-1-token-print",
                display: "print",
                role: "Names the standard-output function",
                requirement: .required,
                explanation: "This function takes the value you provide and writes a readable version to standard output.",
                ifChanged: "A different or unknown name would call a different action or cause a compile-time error."
            ),
            SyntaxMicroscopeToken(
                id: "lesson-1-token-parentheses",
                display: "( ... )",
                role: "Hold the function input",
                requirement: .required,
                explanation: "The opening and closing parentheses work as a pair around the value passed to print.",
                ifChanged: "Removing either parenthesis leaves the function call incomplete, so Swift cannot compile it."
            ),
            SyntaxMicroscopeToken(
                id: "lesson-1-token-quotation-marks",
                display: "\" ... \"",
                role: "Mark the boundaries of a String literal",
                requirement: .required,
                explanation: "The paired quotation marks tell Swift to treat the characters between them as text data.",
                ifChanged: "Removing one or both marks makes the String incomplete or makes Swift read the words as code."
            ),
            SyntaxMicroscopeToken(
                id: "lesson-1-token-literal-contents",
                display: "Hello, Swift!",
                role: "Provide the text value",
                requirement: .contextual,
                explanation: "These characters, including the space after the comma, are the data that print receives.",
                ifChanged: "The new characters become the new output because they form a different String value."
            ),
            SyntaxMicroscopeToken(
                id: "lesson-1-token-outer-spacing",
                display: "print( \"Hello, Swift!\" )",
                role: "Space this example inside its parentheses",
                requirement: .convention,
                explanation: "The optional spaces immediately inside print's parentheses are a formatting choice; common Swift style omits them here.",
                ifChanged: "Adding or removing these particular spaces does not change the String or the output. Other whitespace can separate tokens or affect how an operator is read."
            )
        ],
        modifyTask: ModifyTask(
            id: "lesson-1-modify-message",
            prompt: "Change only the text inside the quotation marks so the program greets a learner.",
            starterCode: "print(\"Hello, Swift!\")",
            expectedCode: "print(\"Hello, learner!\")",
            predictionPrompt: "What exact text will this call send to standard output?",
            expectedOutput: "Hello, learner!",
            successExplanation: "You kept the print call and its required punctuation, then changed the String data that becomes the output.",
            conceptIDs: [
                "lesson-1-print-function-call",
                "lesson-1-string-literal"
            ]
        ),
        recallQuestions: [
            RecallQuestion(
                id: "lesson-1-recall-quotation-marks",
                prompt: "Why does Hello, Swift! need quotation marks in this call?",
                choices: [
                    "They make print run twice",
                    "They tell Swift the characters form a String literal",
                    "They add quotation marks to the output"
                ],
                correctChoiceIndex: 1,
                explanation: "Quotation marks bound text written directly in code. print receives the String between them, not the marks themselves.",
                conceptIDs: ["lesson-1-string-literal"]
            ),
            RecallQuestion(
                id: "lesson-1-recall-spaces",
                prompt: "Which space changes the printed data if you remove it?",
                choices: [
                    "A space inside the quotation marks",
                    "An optional space immediately inside print's parentheses"
                ],
                correctChoiceIndex: 0,
                explanation: "Characters inside a String are data. In this call, spaces just inside the parentheses are optional formatting; other whitespace may separate tokens, and operator whitespace can matter.",
                conceptIDs: ["lesson-1-string-data-versus-style"]
            )
        ]
    )

    static let lesson2 = LessonDeepContent(
        title: "Give a String a Constant Name",
        introduction: "A constant lets you choose a useful name for a value and use that name later. We will trace how let, assignment, and print connect the name to its String.",
        segments: [
            DeepLessonSegment(
                id: "lesson-2-let-binding",
                title: "Create a constant binding",
                explanation: "let creates a constant binding: a chosen name connected to one value. In let name = \"Alex\", assignment stores the right-hand value \"Alex\" under the left-hand name name.",
                correctCode: "let name = \"Alex\"",
                wrongCode: "name = \"Alex\"",
                wrongExplanation: "This tries to assign through name before let or var has created that name, so Swift cannot find the binding."
            ),
            DeepLessonSegment(
                id: "lesson-2-string-value",
                title: "Store text, not an unknown name",
                explanation: "The quotation marks make \"Alex\" a String literal. name is a name you chose for the binding; Alex is the text value stored there.",
                correctCode: "let name = \"Alex\"",
                wrongCode: "let name = Alex",
                wrongExplanation: "Without quotation marks, Swift looks for another binding named Alex instead of storing the text Alex."
            ),
            DeepLessonSegment(
                id: "lesson-2-quoted-name",
                title: "Use the binding, not its spelling",
                explanation: "print(name) looks up the value stored under name and prints Alex. print(\"name\") skips that lookup because quotation marks create the literal text name.",
                correctCode: "let name = \"Alex\"\nprint(name)",
                wrongCode: "let name = \"Alex\"\nprint(\"name\")",
                wrongExplanation: "The quoted word is a new String literal, so this prints name instead of the value Alex stored in the binding."
            ),
            DeepLessonSegment(
                id: "lesson-2-let-reassignment",
                title: "Keep a let value constant",
                explanation: "Use let when the binding should keep its first value. This promise helps Swift catch an accidental change before the program can run.",
                correctCode: "let name = \"Alex\"\nprint(name)",
                wrongCode: "let name = \"Alex\"\nname = \"Sam\"",
                wrongExplanation: "A let binding cannot receive a second value. Swift reports the reassignment as a compile-time error."
            )
        ],
        microscopeTokens: [
            SyntaxMicroscopeToken(
                id: "lesson-2-token-let",
                display: "let",
                role: "Create a constant binding",
                requirement: .required,
                explanation: "let introduces a name whose first assigned value cannot be replaced later.",
                ifChanged: "Changing let to var would allow later reassignment and communicate a different intent."
            ),
            SyntaxMicroscopeToken(
                id: "lesson-2-token-name",
                display: "name",
                role: "Name the stored value",
                requirement: .contextual,
                explanation: "You choose this identifier so later code can refer to the stored String clearly.",
                ifChanged: "Another valid identifier works, but every later use must use that same chosen name."
            ),
            SyntaxMicroscopeToken(
                id: "lesson-2-token-assignment",
                display: "=",
                role: "Assign the right-hand value to the left-hand name",
                requirement: .required,
                explanation: "The assignment operator connects name on its left to the String value on its right.",
                ifChanged: "Removing it leaves Swift without the assignment that gives the new binding its value."
            ),
            SyntaxMicroscopeToken(
                id: "lesson-2-token-string",
                display: "\"Alex\"",
                role: "Provide the String value",
                requirement: .contextual,
                explanation: "The paired quotation marks make Alex text written directly in the program.",
                ifChanged: "Removing the marks makes Swift search for an identifier named Alex instead of creating a String."
            ),
            SyntaxMicroscopeToken(
                id: "lesson-2-token-assignment-spacing",
                display: "name = \"Alex\"",
                role: "Separate both sides of assignment visually",
                requirement: .convention,
                explanation: "Swift style puts one space on each side of = so the left name and right value are easy to scan.",
                ifChanged: "Removing those spaces does not change this assignment, but it makes the code less consistent with common Swift style."
            )
        ],
        modifyTask: ModifyTask(
            id: "lesson-2-modify-stored-name",
            prompt: "Change the String assigned to name from Alex to Sam, then keep printing the binding without quotation marks.",
            starterCode: "let name = \"Alex\"\nprint(name)",
            expectedCode: "let name = \"Sam\"\nprint(name)",
            predictionPrompt: "What value will print(name) send to standard output?",
            expectedOutput: "Sam",
            successExplanation: "The assignment now stores \"Sam\" under name, and print(name) reads and prints that stored value.",
            conceptIDs: [
                "lesson-2-constant-binding",
                "lesson-2-assignment-direction",
                "lesson-2-name-versus-literal"
            ]
        ),
        recallQuestions: [
            RecallQuestion(
                id: "lesson-2-recall-assignment",
                prompt: "In let name = \"Alex\", what does assignment do?",
                choices: [
                    "Stores the word name inside Alex",
                    "Prints both sides immediately",
                    "Stores the right-hand String under the left-hand name"
                ],
                correctChoiceIndex: 2,
                explanation: "Assignment takes the value on the right and connects it to the binding named on the left.",
                conceptIDs: ["lesson-2-assignment-direction"]
            ),
            RecallQuestion(
                id: "lesson-2-recall-quoted-name",
                prompt: "What does print(\"name\") print?",
                choices: [
                    "The value stored under name",
                    "The literal word name"
                ],
                correctChoiceIndex: 1,
                explanation: "Quotation marks make name a String literal. Without them, print(name) looks up the binding's value.",
                conceptIDs: ["lesson-2-name-versus-literal"]
            )
        ]
    )

    static let lesson3 = LessonDeepContent(
        title: "Change a Value with var",
        introduction: "Some named values need to change while a program runs. A var binding makes that intention explicit, so a later assignment can replace its current value.",
        segments: [
            DeepLessonSegment(
                id: "lesson-3-var-binding",
                title: "Create a mutable binding",
                explanation: "var creates a mutable binding: a chosen name with a value that later code may replace. The first assignment gives count its initial value of 1.",
                correctCode: "var count = 1",
                wrongCode: "count = 1",
                wrongExplanation: "Assignment cannot use count until let or var first declares that binding."
            ),
            DeepLessonSegment(
                id: "lesson-3-reassignment",
                title: "Replace the current value",
                explanation: "After var count = 1 creates the binding, count = 2 is reassignment. It stores a new value under the existing name; mutation works because var declared that the binding may change.",
                correctCode: "var count = 1\ncount = 2\nprint(count)",
                wrongCode: "var count = 1\nvar count = 2\nprint(count)",
                wrongExplanation: "The second line should reassign the existing count, not try to declare another local binding with the same name."
            ),
            DeepLessonSegment(
                id: "lesson-3-integer-literal",
                title: "Keep a number numeric",
                explanation: "The unquoted literal 1 is an Int, a whole-number value. Quotation marks would create the String \"1\" instead, which is text and cannot later receive the Int 2.",
                correctCode: "var count = 1\ncount = 2",
                wrongCode: "var count = \"1\"\ncount = 2",
                wrongExplanation: "The first assignment makes count a String binding, so assigning the Int 2 later causes a compile-time type error."
            ),
            DeepLessonSegment(
                id: "lesson-3-let-reassignment",
                title: "Choose var only when change is needed",
                explanation: "let protects a binding from later changes; var permits them. Swift checks that rule while compiling, before a program with an invalid reassignment can run.",
                correctCode: "var count = 1\ncount = 2\nprint(count)",
                wrongCode: "let count = 1\ncount = 2\nprint(count)",
                wrongExplanation: "The second assignment tries to change a let binding, so Swift stops with a compile-time error."
            )
        ],
        microscopeTokens: [
            SyntaxMicroscopeToken(
                id: "lesson-3-token-var",
                display: "var",
                role: "Create a mutable binding",
                requirement: .required,
                explanation: "var tells Swift and the reader that this binding's value is allowed to change.",
                ifChanged: "Changing var to let would make count constant and reject the later reassignment."
            ),
            SyntaxMicroscopeToken(
                id: "lesson-3-token-count",
                display: "count",
                role: "Name the current value",
                requirement: .contextual,
                explanation: "Both assignment lines use the same name, so the second one updates the binding created by the first.",
                ifChanged: "Using a different name on the second line would target a different binding rather than update count."
            ),
            SyntaxMicroscopeToken(
                id: "lesson-3-token-assignment",
                display: "=",
                role: "Store a value under count",
                requirement: .required,
                explanation: "The first = supplies the initial value; the second = replaces it with a new value.",
                ifChanged: "Without assignment, neither the initial value nor the later update is expressed."
            ),
            SyntaxMicroscopeToken(
                id: "lesson-3-token-int-literal",
                display: "1",
                role: "Provide an Int literal",
                requirement: .contextual,
                explanation: "A whole number without quotation marks is an Int value that can be used as a number.",
                ifChanged: "Adding quotation marks produces String text instead of an Int and changes what values count can hold."
            ),
            SyntaxMicroscopeToken(
                id: "lesson-3-token-assignment-spacing",
                display: "count = 2",
                role: "Make reassignment easy to read",
                requirement: .convention,
                explanation: "One space on each side of = is conventional Swift formatting that separates the name from its new value.",
                ifChanged: "Removing these spaces does not change this assignment, but the conventional spacing is easier to scan."
            )
        ],
        modifyTask: ModifyTask(
            id: "lesson-3-modify-count",
            prompt: "Keep count as a var, but change its reassigned value from 2 to 5.",
            starterCode: "var count = 1\ncount = 2\nprint(count)",
            expectedCode: "var count = 1\ncount = 5\nprint(count)",
            predictionPrompt: "What value will print(count) send to standard output after reassignment?",
            expectedOutput: "5",
            successExplanation: "The initial assignment stores 1, then the allowed var reassignment replaces it with 5 before print reads the current value.",
            conceptIDs: [
                "lesson-3-mutable-binding",
                "lesson-3-reassignment",
                "lesson-3-int-literal"
            ]
        ),
        recallQuestions: [
            RecallQuestion(
                id: "lesson-3-recall-var",
                prompt: "Why does count = 2 work after var count = 1?",
                choices: [
                    "Every number can change even when stored with let",
                    "var allows the existing binding to receive a new value",
                    "print changes count automatically"
                ],
                correctChoiceIndex: 1,
                explanation: "var declares count as mutable, so a later assignment may replace its current value.",
                conceptIDs: [
                    "lesson-3-mutable-binding",
                    "lesson-3-reassignment"
                ]
            ),
            RecallQuestion(
                id: "lesson-3-recall-int-literal",
                prompt: "What value does the unquoted code 1 create?",
                choices: [
                    "An Int whole-number value",
                    "A String containing the character 1"
                ],
                correctChoiceIndex: 0,
                explanation: "Without quotation marks, 1 is an Int literal. \"1\" would be a String literal instead.",
                conceptIDs: ["lesson-3-int-literal"]
            )
        ]
    )
}
