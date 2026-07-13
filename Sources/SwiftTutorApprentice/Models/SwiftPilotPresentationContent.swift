import Foundation

enum SwiftPilotPresentationContent {
    static let lesson1: LessonPresentation = {
        let narrations = DeepLessonPilotContent.lesson1.segments.map(\.explanation)
        let empty = PresentationVisualState(
            code: nil,
            codeTokens: [],
            values: [],
            output: nil,
            outputTargetID: nil,
            description: "An empty execution lane waits for the first Swift statement."
        )
        let call = PresentationVisualState(
            code: "print(\"Hello, Swift!\")",
            codeTokens: printHelloTokens,
            values: [],
            output: nil,
            outputTargetID: nil,
            description: "A complete print call appears with its function name, parentheses, and String literal."
        )
        let literalReady = PresentationVisualState(
            code: "print(\"Hello, Swift!\")",
            codeTokens: printHelloTokens,
            values: [
                PresentationValue(id: "message-value", name: "String input", value: "Hello, Swift!")
            ],
            output: nil,
            outputTargetID: nil,
            description: "The quoted characters are identified as the String value passed into print."
        )
        let ready = PresentationVisualState(
            code: "print(\"Hello, Swift!\")",
            codeTokens: printHelloTokens,
            values: [
                PresentationValue(id: "execution-state", name: "print call", value: "ready")
            ],
            output: nil,
            outputTargetID: nil,
            description: "The print call is ready to execute with its String input."
        )
        let executing = PresentationVisualState(
            code: "print(\"Hello, Swift!\")",
            codeTokens: printHelloTokens,
            values: [
                PresentationValue(id: "execution-state", name: "print call", value: "executing")
            ],
            output: nil,
            outputTargetID: nil,
            description: "The print call is active and is sending the String to standard output."
        )
        let output = PresentationVisualState(
            code: "print(\"Hello, Swift!\")",
            codeTokens: printHelloTokens,
            values: [
                PresentationValue(id: "execution-state", name: "print call", value: "finished")
            ],
            output: "Hello, Swift!",
            outputTargetID: "stdout",
            description: "Standard output contains Hello, Swift! without the source-code quotation marks."
        )

        let scenes = [
            PresentationScene(
                id: "print-call",
                title: "Build the call",
                caption: "A function call gives print one String input.",
                narration: narrations[0],
                staticDescription: "The empty lane gains the complete print call.",
                visualKind: .codeExecution,
                focusTargets: [PresentationFocusTarget(kind: .codeToken, id: "print-function")],
                before: empty,
                after: call
            ),
            PresentationScene(
                id: "string-literal",
                title: "Read the String literal",
                caption: "Quotation marks identify text in the source code.",
                narration: narrations[1],
                staticDescription: "The String token is focused and its inner characters become a named input value.",
                visualKind: .valueBinding,
                focusTargets: [PresentationFocusTarget(kind: .codeToken, id: "string-literal")],
                before: call,
                after: literalReady
            ),
            PresentationScene(
                id: "execution",
                title: "Execute print",
                caption: "The call moves from ready to executing.",
                narration: narrations[2],
                staticDescription: "The print function changes from a ready state to an executing state.",
                visualKind: .codeExecution,
                focusTargets: [
                    PresentationFocusTarget(kind: .codeToken, id: "print-function"),
                    PresentationFocusTarget(kind: .value, id: "execution-state")
                ],
                before: ready,
                after: executing
            ),
            PresentationScene(
                id: "output",
                title: "See standard output",
                caption: "The String data arrives in the console.",
                narration: narrations[3],
                staticDescription: "The active call finishes and stdout displays Hello, Swift!.",
                visualKind: .outputFlow,
                focusTargets: [PresentationFocusTarget(kind: .output, id: "stdout")],
                before: executing,
                after: output
            )
        ]

        let concepts: [ConceptID] = [
            "swift.lesson-1.print-call",
            "swift.lesson-1.string-literal",
            "swift.lesson-1.standard-output"
        ]
        return LessonPresentation(
            id: "swift-1-print-output",
            title: "Watch print Become Output",
            posterDescription: "Follow a String literal from an empty execution lane into standard output.",
            posterState: empty,
            scenes: scenes,
            transcript: narrations.joined(separator: "\n\n"),
            narrationLocale: "en-US",
            finalRecallQuestionID: "lesson-1-recall-quotation-marks",
            aiCodeExercise: AICodeReviewExercise(
                id: "swift-1-review-print-output",
                prompt: "Review these claims about the generated print call and its output.",
                generatedCode: "print(\"Hello, Swift!\")",
                claims: [
                    AICodeClaim(
                        id: "swift-1-claim-output",
                        text: "The call sends Hello, Swift! to standard output.",
                        isCorrect: true,
                        explanation: "The characters inside the String literal are the value print writes to standard output."
                    ),
                    AICodeClaim(
                        id: "swift-1-claim-quotes",
                        text: "The quotation marks appear in the printed output.",
                        isCorrect: false,
                        explanation: "The quotation marks delimit the String literal in source code; print receives the characters between them, so the marks are not output."
                    )
                ],
                conceptIDs: concepts
            ),
            conceptIDs: concepts,
            objectiveMappings: [],
            provenance: .init(source: .bundled, revision: 1)
        )
    }()

    static let lesson2: LessonPresentation = {
        let narrations = DeepLessonPilotContent.lesson2.segments.map(\.explanation)
        let empty = PresentationVisualState(
            code: nil,
            codeTokens: [],
            values: [],
            output: nil,
            outputTargetID: nil,
            description: "An empty binding lane waits for a constant declaration."
        )
        let binding = PresentationVisualState(
            code: "let name = \"Alex\"",
            codeTokens: nameBindingTokens,
            values: [],
            output: nil,
            outputTargetID: nil,
            description: "The source declares a constant named name and assigns the String Alex."
        )
        let stored = PresentationVisualState(
            code: "let name = \"Alex\"",
            codeTokens: nameBindingTokens,
            values: [PresentationValue(id: "name-value", name: "name", value: "Alex")],
            output: nil,
            outputTargetID: nil,
            description: "The binding table connects the identifier name to the stored String value Alex."
        )
        let lookup = PresentationVisualState(
            code: "let name = \"Alex\"\nprint(name)",
            codeTokens: nameProgramTokens,
            values: [PresentationValue(id: "name-value", name: "name lookup", value: "Alex")],
            output: nil,
            outputTargetID: nil,
            description: "print(name) resolves the identifier name to its stored String value Alex."
        )
        let output = PresentationVisualState(
            code: "let name = \"Alex\"\nprint(name)",
            codeTokens: nameProgramTokens,
            values: [PresentationValue(id: "name-value", name: "resolved name", value: "Alex")],
            output: "Alex",
            outputTargetID: "stdout",
            description: "The resolved String value Alex appears in standard output."
        )
        let scenes = [
            PresentationScene(
                id: "let-binding",
                title: "Create the binding",
                caption: "let introduces one constant name and its first value.",
                narration: narrations[0],
                staticDescription: "The empty lane gains the declaration let name = \"Alex\".",
                visualKind: .valueBinding,
                focusTargets: [PresentationFocusTarget(kind: .codeToken, id: "let-keyword")],
                before: empty,
                after: binding
            ),
            PresentationScene(
                id: "stored-value",
                title: "Store Alex under name",
                caption: "The right-hand String becomes the value of the left-hand name.",
                narration: narrations[1],
                staticDescription: "A binding table adds name = Alex beside the declaration.",
                visualKind: .valueBinding,
                focusTargets: [PresentationFocusTarget(kind: .value, id: "name-value")],
                before: binding,
                after: stored
            ),
            PresentationScene(
                id: "name-lookup",
                title: "Look up name",
                caption: "print(name) reads the binding instead of printing its spelling.",
                narration: narrations[2],
                staticDescription: "A second line, print(name), highlights the identifier reference and resolves it to Alex.",
                visualKind: .valueBinding,
                focusTargets: [PresentationFocusTarget(kind: .codeToken, id: "name-reference")],
                before: stored,
                after: lookup
            ),
            PresentationScene(
                id: "output",
                title: "Print the stored value",
                caption: "The lookup result flows to standard output.",
                narration: narrations[3],
                staticDescription: "The resolved value Alex moves from the name binding to stdout.",
                visualKind: .outputFlow,
                focusTargets: [PresentationFocusTarget(kind: .output, id: "stdout")],
                before: lookup,
                after: output
            )
        ]
        let concepts: [ConceptID] = [
            "swift.lesson-2.constant-binding",
            "swift.lesson-2.assignment-direction",
            "swift.lesson-2.name-lookup"
        ]
        return LessonPresentation(
            id: "swift-2-constant-binding",
            title: "Watch a Constant Store and Reveal a Value",
            posterDescription: "Follow Alex from a String literal into a constant binding, a name lookup, and standard output.",
            posterState: empty,
            scenes: scenes,
            transcript: narrations.joined(separator: "\n\n"),
            narrationLocale: "en-US",
            finalRecallQuestionID: "lesson-2-recall-quoted-name",
            aiCodeExercise: AICodeReviewExercise(
                id: "swift-2-review-name-lookup",
                prompt: "Review these claims about a generated constant and print call.",
                generatedCode: "let name = \"Alex\"\nprint(name)",
                claims: [
                    AICodeClaim(
                        id: "swift-2-claim-lookup",
                        text: "`print(name)` reads and prints the String stored under `name`.",
                        isCorrect: true,
                        explanation: "Without quotation marks, name is an identifier, so Swift looks up its stored value Alex before print writes it."
                    ),
                    AICodeClaim(
                        id: "swift-2-claim-quoted-name",
                        text: "`print(\"name\")` reads the value stored in `name`.",
                        isCorrect: false,
                        explanation: "Quotation marks create the literal String name, so this code prints the word name instead of looking up the binding's value Alex."
                    )
                ],
                conceptIDs: concepts
            ),
            conceptIDs: concepts,
            objectiveMappings: [],
            provenance: .init(source: .bundled, revision: 1)
        )
    }()

    static let lesson3: LessonPresentation = {
        let deepNarrations = DeepLessonPilotContent.lesson3.segments.map(\.explanation)
        let narrations = [deepNarrations[0], deepNarrations[2], deepNarrations[1], deepNarrations[3]]
        let empty = PresentationVisualState(
            code: nil,
            codeTokens: [],
            values: [],
            output: nil,
            outputTargetID: nil,
            description: "An empty mutation lane waits for a variable declaration."
        )
        let binding = PresentationVisualState(
            code: "var count = 1",
            codeTokens: countBindingTokens,
            values: [],
            output: nil,
            outputTargetID: nil,
            description: "The source declares a mutable binding named count with the Int literal 1."
        )
        let firstValue = PresentationVisualState(
            code: "var count = 1",
            codeTokens: countBindingTokens,
            values: [PresentationValue(id: "count-value", name: "count", value: "1")],
            output: nil,
            outputTargetID: nil,
            description: "The variable table shows count holding its first Int value, 1."
        )
        let reassigned = PresentationVisualState(
            code: "var count = 1\ncount = 2",
            codeTokens: countReassignmentTokens,
            values: [PresentationValue(id: "count-value", name: "count", value: "2")],
            output: nil,
            outputTargetID: nil,
            description: "A second assignment replaces count's value 1 with the Int value 2."
        )
        let output = PresentationVisualState(
            code: "var count = 1\ncount = 2\nprint(count)",
            codeTokens: countProgramTokens,
            values: [PresentationValue(id: "count-value", name: "current count", value: "2")],
            output: "2",
            outputTargetID: "stdout",
            description: "print reads count's current value after reassignment, and stdout displays 2."
        )
        let scenes = [
            PresentationScene(
                id: "var-binding",
                title: "Create a mutable binding",
                caption: "var declares that count may receive another value later.",
                narration: narrations[0],
                staticDescription: "The empty lane gains the declaration var count = 1.",
                visualKind: .valueBinding,
                focusTargets: [PresentationFocusTarget(kind: .codeToken, id: "var-keyword")],
                before: empty,
                after: binding
            ),
            PresentationScene(
                id: "first-value",
                title: "Store the first Int",
                caption: "The unquoted literal 1 becomes count's numeric value.",
                narration: narrations[1],
                staticDescription: "The variable table adds count = 1 beside the declaration.",
                visualKind: .valueBinding,
                focusTargets: [PresentationFocusTarget(kind: .value, id: "count-value")],
                before: binding,
                after: firstValue
            ),
            PresentationScene(
                id: "reassignment",
                title: "Replace 1 with 2",
                caption: "A later assignment mutates the existing var binding.",
                narration: narrations[2],
                staticDescription: "The second assignment appears and the variable table changes count from 1 to 2.",
                visualKind: .collectionChange,
                focusTargets: [
                    PresentationFocusTarget(kind: .codeToken, id: "reassigned-value"),
                    PresentationFocusTarget(kind: .value, id: "count-value")
                ],
                before: firstValue,
                after: reassigned
            ),
            PresentationScene(
                id: "output",
                title: "Print the current value",
                caption: "print observes count after its mutation.",
                narration: narrations[3],
                staticDescription: "A print line appears and stdout shows the current value 2.",
                visualKind: .outputFlow,
                focusTargets: [PresentationFocusTarget(kind: .output, id: "stdout")],
                before: reassigned,
                after: output
            )
        ]
        let concepts: [ConceptID] = [
            "swift.lesson-3.mutable-binding",
            "swift.lesson-3.integer-literal",
            "swift.lesson-3.reassignment"
        ]
        return LessonPresentation(
            id: "swift-3-variable-mutation",
            title: "Watch a Variable Change",
            posterDescription: "Follow count from its first Int value through reassignment and into standard output.",
            posterState: empty,
            scenes: scenes,
            transcript: narrations.joined(separator: "\n\n"),
            narrationLocale: "en-US",
            finalRecallQuestionID: "lesson-3-recall-var",
            aiCodeExercise: AICodeReviewExercise(
                id: "swift-3-review-reassignment",
                prompt: "Review these claims about generated Swift variable code.",
                generatedCode: "var count = 1\ncount = 2\nprint(count)",
                claims: [
                    AICodeClaim(
                        id: "swift-3-claim-var",
                        text: "`var` allows the later assignment to replace count's current value.",
                        isCorrect: true,
                        explanation: "var creates a mutable binding, so count = 2 may replace the initial Int value 1 before print reads it."
                    ),
                    AICodeClaim(
                        id: "swift-3-claim-let",
                        text: "Changing `var` to `let` still permits reassignment.",
                        isCorrect: false,
                        explanation: "let creates a constant binding; Swift rejects count = 2 because a let value cannot be replaced after its first assignment."
                    )
                ],
                conceptIDs: concepts
            ),
            conceptIDs: concepts,
            objectiveMappings: [],
            provenance: .init(source: .bundled, revision: 1)
        )
    }()

    private static let printHelloTokens = [
        PresentationCodeToken(id: "print-function", text: "print"),
        PresentationCodeToken(id: "open-paren", text: "("),
        PresentationCodeToken(id: "string-literal", text: "\"Hello, Swift!\""),
        PresentationCodeToken(id: "close-paren", text: ")")
    ]

    private static let nameBindingTokens = [
        PresentationCodeToken(id: "let-keyword", text: "let"),
        PresentationCodeToken(id: "binding-space-1", text: " "),
        PresentationCodeToken(id: "name-declaration", text: "name"),
        PresentationCodeToken(id: "binding-space-2", text: " "),
        PresentationCodeToken(id: "assignment", text: "="),
        PresentationCodeToken(id: "binding-space-3", text: " "),
        PresentationCodeToken(id: "alex-literal", text: "\"Alex\"")
    ]

    private static let nameProgramTokens = nameBindingTokens + [
        PresentationCodeToken(id: "line-break", text: "\n"),
        PresentationCodeToken(id: "print-function", text: "print"),
        PresentationCodeToken(id: "open-paren", text: "("),
        PresentationCodeToken(id: "name-reference", text: "name"),
        PresentationCodeToken(id: "close-paren", text: ")")
    ]

    private static let countBindingTokens = [
        PresentationCodeToken(id: "var-keyword", text: "var"),
        PresentationCodeToken(id: "binding-space-1", text: " "),
        PresentationCodeToken(id: "count-declaration", text: "count"),
        PresentationCodeToken(id: "binding-space-2", text: " "),
        PresentationCodeToken(id: "initial-assignment", text: "="),
        PresentationCodeToken(id: "binding-space-3", text: " "),
        PresentationCodeToken(id: "initial-value", text: "1")
    ]

    private static let countReassignmentTokens = countBindingTokens + [
        PresentationCodeToken(id: "reassignment-line-break", text: "\n"),
        PresentationCodeToken(id: "count-reference", text: "count"),
        PresentationCodeToken(id: "reassignment-space-1", text: " "),
        PresentationCodeToken(id: "reassignment-operator", text: "="),
        PresentationCodeToken(id: "reassignment-space-2", text: " "),
        PresentationCodeToken(id: "reassigned-value", text: "2")
    ]

    private static let countProgramTokens = countReassignmentTokens + [
        PresentationCodeToken(id: "print-line-break", text: "\n"),
        PresentationCodeToken(id: "print-function", text: "print"),
        PresentationCodeToken(id: "open-paren", text: "("),
        PresentationCodeToken(id: "printed-count-reference", text: "count"),
        PresentationCodeToken(id: "close-paren", text: ")")
    ]
}
