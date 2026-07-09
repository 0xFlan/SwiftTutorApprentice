# Deep Lesson Pilot v1 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional, replayable concept-first Deep Lesson and guided Modify stage to built-in Swift Lessons 1–3 without changing existing lesson completion, custom lessons, or saved progress.

**Architecture:** Keep `Lesson` backward-compatible by adding one optional nested-content field. Migrate only compatible built-in saved lessons, version progress with additive stage events, and present the new stages as non-locking SwiftUI sheets above the existing workspace. Pure model, persistence, content, and Modify-evaluation behavior is unit-tested before UI integration.

**Tech Stack:** Swift 5.9, Swift Package Manager, SwiftUI for macOS 14, Combine-backed stores, XCTest, local JSON persistence, existing offline `NarrationSpeaker`.

**Design:** `docs/superpowers/specs/2026-07-09-deep-lesson-pilot-design.md`

---

## Chunk 1: Data Safety and Pilot Content

### Task 1: Add the test target and backward-compatible deep lesson models

**Files:**
- Modify: `Package.swift`
- Modify: `Sources/SwiftTutorApprentice/Models/Lesson.swift`
- Create: `Sources/SwiftTutorApprentice/Models/LessonDeepContent.swift`
- Create: `Tests/SwiftTutorApprenticeTests/LessonCompatibilityTests.swift`
- Create: `Tests/SwiftTutorApprenticeTests/Fixtures/legacy-lessons.json`
- Create: `Tests/SwiftTutorApprenticeTests/Fixtures/legacy-progress.json`

- [ ] **Step 1: Add a SwiftPM test target**

Replace the current `targets` array with this complete compilable edit:

```swift
targets: [
    .executableTarget(
        name: "SwiftTutorApprentice",
        path: "Sources/SwiftTutorApprentice"
    ),
    .testTarget(
        name: "SwiftTutorApprenticeTests",
        dependencies: ["SwiftTutorApprentice"],
        path: "Tests/SwiftTutorApprenticeTests",
        resources: [.copy("Fixtures")]
    )
]
```

- [ ] **Step 2: Add reusable legacy smoke fixtures**

Create `legacy-lessons.json` with this exact old array shape (no `kind` or
`deepContent`):

```json
[
  {
    "id": 1,
    "title": "My preserved Printing title",
    "goal": "My preserved goal",
    "starterCode": "print(\"Hello, Swift!\")",
    "teaches": ["print"],
    "glossaryTerms": ["String"],
    "syntaxTokens": [],
    "syntaxWhy": "My preserved syntax note",
    "expectedOutput": "Hello, Swift!",
    "successMarkers": ["print("],
    "successMessage": "My preserved success message",
    "hint": "My preserved hint"
  }
]
```

Create `legacy-progress.json`:

```json
{
  "completedLessonIDs": [2]
}
```

- [ ] **Step 3: Write failing legacy-decode and model-contract tests**

Create `LessonCompatibilityTests` with a literal legacy lesson JSON fixture
that omits both `kind` and `deepContent`. Assert that it decodes as `.code`,
has `deepContent == nil`, and preserves every legacy field. Decode a second
custom lesson using a non-built-in ID to prove the same behavior. Load the
reusable fixture with `Bundle.module.url(forResource:withExtension:subdirectory:)`.
Add a third
fixture with a valid legacy lesson plus malformed nested `deepContent` and
assert the lesson still decodes with `deepContent == nil`. Add a model
round-trip test with this wished-for shape:

```swift
let content = LessonDeepContent(
    title: "Inside print",
    introduction: "Follow one value through the line.",
    segments: [.init(
        id: "call",
        title: "Call the function",
        explanation: "A call asks a function to do its work.",
        correctCode: "print(\"Hi\")",
        wrongCode: "print\"Hi\"",
        wrongExplanation: "The input must be inside parentheses."
    )],
    microscopeTokens: [.init(
        id: "print",
        display: "print",
        role: "Function name",
        requirement: .required,
        explanation: "Names the function to call.",
        ifChanged: "A different or unknown name calls different code or fails."
    )],
    modifyTask: .init(
        id: "message",
        prompt: "Change Hi to Bye.",
        starterCode: "print(\"Hi\")",
        expectedCode: "print(\"Bye\")",
        predictionPrompt: "What will print?",
        expectedOutput: "Bye",
        successExplanation: "The string changed, so stdout changed.",
        conceptIDs: ["string-literal"]
    ),
    recallQuestions: [.init(
        id: "quotes",
        prompt: "Why are quotes needed?",
        choices: ["They mark text", "They run print"],
        correctChoiceIndex: 0,
        explanation: "Quotes delimit a String literal.",
        conceptIDs: ["string-literal"]
    )]
)
```

- [ ] **Step 4: Run the focused test and verify RED**

Run:

```bash
swift test --filter LessonCompatibilityTests
```

Expected: compile failure because the deep-content types and `Lesson.deepContent` do not exist.

- [ ] **Step 5: Implement the minimal nested models**

In `LessonDeepContent.swift`, add Codable/Hashable structs matching the test.
Use a string-backed `ConceptID` value type:

```swift
struct ConceptID: RawRepresentable, Hashable, Codable, ExpressibleByStringLiteral {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
    init(stringLiteral value: String) { rawValue = value }
}

enum SyntaxRequirement: String, Codable, Hashable {
    case required, convention, contextual
}
```

Each segment, token, task, and question has the exact fields exercised above.
Keep these as plain data types; content-contract assertions belong in the pilot
content tests rather than in an otherwise-unused production validator.

Add `var deepContent: LessonDeepContent? = nil` to `Lesson`, include it in
`CodingKeys`, and decode it with field-level lossy fallback:

```swift
do {
    deepContent = try c.decodeIfPresent(LessonDeepContent.self, forKey: .deepContent)
} catch {
    deepContent = nil
}
```

Do not change existing required legacy fields or their decoding. This fallback
is intentionally limited to the additive enrichment field.

- [ ] **Step 6: Run the focused test and verify GREEN**

Run `swift test --filter LessonCompatibilityTests`.

Expected: all compatibility and round-trip tests pass.

- [ ] **Step 7: Commit the model slice**

```bash
git add Package.swift Sources/SwiftTutorApprentice/Models/Lesson.swift Sources/SwiftTutorApprentice/Models/LessonDeepContent.swift Tests/SwiftTutorApprenticeTests/LessonCompatibilityTests.swift Tests/SwiftTutorApprenticeTests/Fixtures/legacy-lessons.json Tests/SwiftTutorApprenticeTests/Fixtures/legacy-progress.json
git commit -m "test: protect deep lesson compatibility"
```

### Task 2: Backfill compatible built-in lessons without overwriting edits

**Files:**
- Modify: `Sources/SwiftTutorApprentice/Services/LessonStore.swift`
- Create: `Tests/SwiftTutorApprenticeTests/LessonStoreMigrationTests.swift`

- [ ] **Step 1: Write failing isolated-store migration tests**

Use a temporary `lessons.json` per test. Write tests for:

1. A saved built-in lesson with the default ID/kind/starter code but an edited
   title and goal receives only the default `deepContent`.
2. A saved lesson with built-in ID 1 but different starter code does not receive
   stock content.
3. A missing default lesson is appended once and existing order is preserved.
4. Twenty-four default IDs remain unique.

Construct the store through the wished-for initializer:

```swift
let store = LessonStore(fileURL: fixtureURL, defaults: defaults)
```

- [ ] **Step 2: Run the focused test and verify RED**

Run `swift test --filter LessonStoreMigrationTests`.

Expected: compile failure because the injectable initializer does not exist.

- [ ] **Step 3: Add dependency injection and compatible enrichment**

Give `LessonStore` these initializers:

```swift
convenience init() {
    self.init(fileURL: Self.defaultFileURL, defaults: Curriculum.defaultLessons)
}

init(fileURL: URL, defaults: [Lesson]) {
    self.fileURL = fileURL
    self.defaults = defaults
    load()
}
```

Replace `mergeMissingDefaults()` with one merge pass that:

- copies only `deepContent` when ID, kind, and starter code match, saved content
  is nil, and default content is non-nil;
- appends IDs absent from the saved list;
- calls `save()` only if either operation changed data.

Keep all public editing behavior unchanged.

- [ ] **Step 4: Run focused and compatibility tests**

Run:

```bash
swift test --filter LessonStoreMigrationTests
swift test --filter LessonCompatibilityTests
```

Expected: both suites pass.

- [ ] **Step 5: Commit the store slice**

```bash
git add Sources/SwiftTutorApprentice/Services/LessonStore.swift Tests/SwiftTutorApprenticeTests/LessonStoreMigrationTests.swift
git commit -m "feat: safely enrich saved lessons"
```

### Task 3: Version progress and persist idempotent stage events

**Files:**
- Modify: `Sources/SwiftTutorApprentice/Services/ProgressStore.swift`
- Create: `Tests/SwiftTutorApprenticeTests/ProgressStoreMigrationTests.swift`

- [ ] **Step 1: Write failing legacy and v2 progress tests**

Use temporary fixture URLs and a fixed `Date`. Cover:

- legacy `{ "completedLessonIDs": [1, 3] }` loads both IDs;
- the checked-in `legacy-progress.json` fixture loads Lesson 2 as complete;
- recording Deep Lesson viewed writes schema version 2 and preserves IDs;
- Deep Lesson and Modify duplicates are ignored per lesson;
- recall duplicates are ignored per lesson/question and first correctness wins;
- different recall questions both persist;
- decoded recall events missing `questionID` or `wasCorrect` are dropped;
- decoded non-recall events carrying recall metadata are dropped;
- reset clears completion and events;
- reload preserves all v2 values and the injected timestamp.

Use the wished-for API:

```swift
let store = ProgressStore(fileURL: url, now: { fixedDate })
store.markDeepLessonViewed(1)
store.markModifyPassed(1)
store.recordRecallAnswer(lessonID: 1, questionID: "quotes", wasCorrect: false)
```

- [ ] **Step 2: Run the focused test and verify RED**

Run `swift test --filter ProgressStoreMigrationTests`.

Expected: compile failure because stage-event models and the test initializer do not exist.

- [ ] **Step 3: Implement the versioned schema**

Add:

```swift
enum LessonStageEventKind: String, Codable, Hashable {
    case deepLessonViewed, modifyPassed, recallAnswered
}

struct LessonStageEvent: Codable, Hashable {
    let lessonID: Int
    let kind: LessonStageEventKind
    let timestamp: Date
    let questionID: String?
    let wasCorrect: Bool?
}
```

Make `SavedProgress` decode missing `version` as 1 and missing `stageEvents` as
empty. Save `version = 2`. Publish `stageEvents` privately, expose
`hasViewedDeepLesson(_:)`, `hasPassedModify(_:)`, and the three mutation APIs,
and enforce the uniqueness keys from the design. `recordRecallAnswer` rejects
an empty question ID. On load, retain a known event only when recall events have
a nonempty `questionID` plus `wasCorrect`, and non-recall events have neither;
drop invalid records without discarding completion IDs. Add the injected file
URL and clock while keeping the zero-argument production initializer.

- [ ] **Step 4: Run focused and full tests**

Run:

```bash
swift test --filter ProgressStoreMigrationTests
swift test
```

Expected: all tests pass.

- [ ] **Step 5: Commit the progress slice**

```bash
git add Sources/SwiftTutorApprentice/Services/ProgressStore.swift Tests/SwiftTutorApprenticeTests/ProgressStoreMigrationTests.swift
git commit -m "feat: add versioned learning stage progress"
```

### Task 4: Add tested Modify evaluation

**Files:**
- Create: `Sources/SwiftTutorApprentice/Services/ModifyTaskEvaluator.swift`
- Create: `Tests/SwiftTutorApprenticeTests/ModifyTaskEvaluatorTests.swift`

- [ ] **Step 1: Write failing Modify evaluator tests**

Exercise `passed`, `codeDoesNotMatch`, `predictionDoesNotMatch`, and
`bothDoNotMatch`. Prove CRLF and one final newline normalize, surrounding
prediction whitespace normalizes, multiple final line breaks normalize,
lone-CR input normalizes, but changing a space inside a string literal fails
exact code comparison.

- [ ] **Step 2: Run the evaluator test and verify RED**

Run `swift test --filter ModifyTaskEvaluatorTests`.

Expected: compile failure because the evaluator does not exist.

- [ ] **Step 3: Implement the minimal pure evaluator**

```swift
enum ModifyTaskResult: Equatable {
    case passed
    case codeDoesNotMatch
    case predictionDoesNotMatch
    case bothDoNotMatch
}

enum ModifyTaskEvaluator {
    static func evaluate(code: String, prediction: String, task: ModifyTask) -> ModifyTaskResult
}
```

Normalize line endings and final line-break characters only for code. Trim
surrounding whitespace/newlines only for prediction. Map the two equality
booleans to the four results.

- [ ] **Step 4: Run the evaluator test and verify GREEN**

Run `swift test --filter ModifyTaskEvaluatorTests`.

Expected: all evaluator tests pass.

- [ ] **Step 5: Commit the evaluator slice**

```bash
git add Sources/SwiftTutorApprentice/Services/ModifyTaskEvaluator.swift Tests/SwiftTutorApprenticeTests/ModifyTaskEvaluatorTests.swift
git commit -m "feat: evaluate guided modify tasks"
```

### Task 5: Author and validate real pilot content

**Files:**
- Create: `Sources/SwiftTutorApprentice/Models/DeepLessonPilotContent.swift`
- Modify: `Sources/SwiftTutorApprentice/Models/Curriculum.swift`
- Create: `Tests/SwiftTutorApprenticeTests/DeepLessonPilotContentTests.swift`

- [ ] **Step 1: Write failing pilot-content contract tests**

Assert exactly 24 built-in lessons and stable IDs `1...24`. For Lessons 1–3,
assert non-nil deep content and directly verify every model contract: nonempty
stable IDs/text, at least one segment/token/question, paired wrong code plus
explanation, at least two recall choices, valid correct-choice indexes,
nonempty concept IDs, complete Modify fields, and required plus convention
microscope categories. Assert every syntax-teaching pilot segment has both a
correct and wrong example. Assert Lessons 4–24 have no deep content.

Also assert the named variants explicitly:

- Lesson 1 contains a missing-quotes variant and a different-literal variant.
- Lesson 2 contains a quoted-variable-name variant and a `let` reassignment
  variant.
- Lesson 3 contains a `let` reassignment variant.

- [ ] **Step 2: Run the content test and verify RED**

Run `swift test --filter DeepLessonPilotContentTests`.

Expected: failures because Lessons 1–3 do not yet have deep content.

- [ ] **Step 3: Author content for Lessons 1–3 only**

Create focused content constants in `DeepLessonPilotContent.swift` and attach
them to the three existing `Lesson` literals with `deepContent:`. Include:

- Lesson 1: function call, parentheses, paired quotes, string literal, stdout,
  spaces inside versus outside quotes; Modify to `print("Hello, learner!")`.
- Lesson 2: `let`, naming, assignment, stored value, quoted literal versus
  unquoted variable; Modify the stored name to `"Sam"` and predict `Sam`.
- Lesson 3: `var`, initial assignment, reassignment/mutation, integers, `let`
  compile failure; Modify the reassigned count to `5` and predict `5`.

Give every segment/token/task/question a stable namespaced ID such as
`lesson-1-quotes`.

- [ ] **Step 4: Run content and full tests**

Run:

```bash
swift test --filter DeepLessonPilotContentTests
swift test
```

Expected: all tests pass.

- [ ] **Step 5: Commit the content slice**

```bash
git add Sources/SwiftTutorApprentice/Models/DeepLessonPilotContent.swift Sources/SwiftTutorApprentice/Models/Curriculum.swift Tests/SwiftTutorApprenticeTests/DeepLessonPilotContentTests.swift
git commit -m "feat: add deep content for first three lessons"
```

## Chunk 2: Learning Views and Workspace Integration

### Task 6: Build the Syntax Microscope and Deep Lesson sheet

**Files:**
- Create: `Sources/SwiftTutorApprentice/Views/SyntaxMicroscopeView.swift`
- Create: `Sources/SwiftTutorApprentice/Views/DeepLessonView.swift`

- [ ] **Step 1: Build `SyntaxMicroscopeView` from model data**

Render one accessible card per token. Show `display` in monospaced text, `role`,
a text badge for Required/Convention/Depends on context, `explanation`, and
“If you change it” text. Use text and SF Symbols in addition to tint. Set an
accessibility element/label that reads the token, role, requirement, and both
explanations in order.

- [ ] **Step 2: Build `DeepLessonView` as a replayable sheet**

Accept `lesson`, nonoptional `content`, `onViewed`, and
`onRecallAnswer(questionID:wasCorrect:)` closures. The sheet must include:

- title, introduction, and a “Skip to workspace” dismiss action;
- segment cards with correct/wrong examples and explanations;
- embedded `SyntaxMicroscopeView`;
- multiple-choice recall cards that lock the first choice and reveal the
  explanation; the first choice invokes `onRecallAnswer` exactly once with
  correctness computed from `correctChoiceIndex`;
- a final “Continue to practice” dismiss action.

Call `onViewed` once on appearance. Put initial accessibility focus on the
sheet heading and ensure every action is keyboard reachable.

- [ ] **Step 3: Compile the new standalone views**

Run `swift build`.

Expected: build succeeds with no errors or new warnings.

- [ ] **Step 4: Commit the teaching-view slice**

```bash
git add Sources/SwiftTutorApprentice/Views/SyntaxMicroscopeView.swift Sources/SwiftTutorApprentice/Views/DeepLessonView.swift
git commit -m "feat: add concept-first deep lesson view"
```

### Task 7: Build Modify, the stage stepper, and non-destructive integration

**Files:**
- Create: `Sources/SwiftTutorApprentice/Views/ModifyTaskView.swift`
- Create: `Sources/SwiftTutorApprentice/Views/LessonStageStepper.swift`
- Modify: `Sources/SwiftTutorApprentice/Views/LessonWorkspace.swift`

- [ ] **Step 1: Build `ModifyTaskView` around the tested evaluator**

Accept the task, existing editor code, `onPassed`, and
`onReplaceEditor(code:prediction:)` closures. Keep local editable code and
prediction state, initialized to `task.starterCode` and an empty prediction.
“Check my change” calls the evaluator and renders a distinct message for all
four results. After pass, show `task.successExplanation` and “Replace editor
with this code.” If existing editor code is nonempty and differs, present a
confirmation alert. Dismiss only after confirmed replacement; failed checks
never dismiss or mutate progress.

- [ ] **Step 2: Build `LessonStageStepper`**

Accept three Bool completion values plus `onOpenDeepLesson` and
`onOpenModify`. Render Deep Lesson → Modify → Practice & Run in one compact row,
with text status and check/circle symbols. Both enriched stages are always
clickable; Practice & Run is labeled as the current workspace, not a lock.

- [ ] **Step 3: Integrate sheets into `LessonWorkspace`**

Add `showingDeepLesson` and `showingModify` state. For lessons with deep
content, put the stepper directly below the navigation bar and connect:

```swift
deepLessonComplete: progress.hasViewedDeepLesson(model.selectedLessonID)
modifyComplete: progress.hasPassedModify(model.selectedLessonID)
practiceComplete: progress.isComplete(model.selectedLessonID)
```

Auto-present Deep Lesson in `onAppear` and after `selectedLessonID` changes only
when content exists, no viewed event exists, and
`settings.hasSeenWelcome == true`. Also observe the transition of
`settings.hasSeenWelcome` to true so finishing first-run onboarding opens the
Deep Lesson after the Welcome sheet has dismissed. This establishes
welcome-first sequencing and prevents competing sheets. Do not reactively
auto-present when reset clears progress.

The Deep Lesson callbacks record view/recall events. Modify pass records its
event. Confirmed editor replacement assigns code and prediction to `model` and
sets `model.runResult = nil`; it does not call `markComplete`.

- [ ] **Step 4: Build and run all tests**

Run:

```bash
swift test
swift build
```

Expected: all tests and build pass without new warnings.

- [ ] **Step 5: Commit the integration slice**

```bash
git add Sources/SwiftTutorApprentice/Views/ModifyTaskView.swift Sources/SwiftTutorApprentice/Views/LessonStageStepper.swift Sources/SwiftTutorApprentice/Views/LessonWorkspace.swift
git commit -m "feat: add guided deep lesson stages"
```

### Task 8: Document and verify the complete pilot

**Files:**
- Modify: `README.md`
- Modify: `docs/learning-evidence.md`

- [ ] **Step 1: Update user-facing documentation**

Add a concise README section describing Deep Lessons for Lessons 1–3, replay,
required-versus-convention Syntax Microscope labels, guided Modify, preserved
workspace, and storage compatibility. Mark the roadmap's
explicit Modify stage as implemented for the pilot without claiming a full
review engine or multi-track platform.

- [ ] **Step 2: Run the complete automated gate**

Run:

```bash
swift test
swift build
```

Expected: all tests pass and the executable builds.

- [ ] **Step 3: Build the `.app` bundle**

Run:

```bash
./Scripts/build-app.sh
```

Expected: the release bundle is assembled at
`dist/SwiftTutor Apprentice.app`.

- [ ] **Step 4: Back up local state and install disposable legacy fixtures**

Quit the app, create a deterministic backup directory, back up Application
Support plus the app's `UserDefaults` domain, then copy the checked-in fixtures:

```bash
osascript -e 'tell application id "com.local.swifttutorapprentice" to quit' 2>/dev/null || true
BACKUP_ROOT="$PWD/.tmp/deep-lesson-smoke-backup"
DATA_DIR="$HOME/Library/Application Support/SwiftTutorApprentice"
WORKSPACE_DIR="$HOME/Developer/SwiftTutorApprentice/Workspace"
test ! -e "$BACKUP_ROOT"
mkdir -p "$BACKUP_ROOT"
if [[ -d "$DATA_DIR" ]]; then cp -R "$DATA_DIR" "$BACKUP_ROOT/data"; touch "$BACKUP_ROOT/had-data"; fi
if [[ -d "$WORKSPACE_DIR" ]]; then cp -R "$WORKSPACE_DIR" "$BACKUP_ROOT/workspace"; touch "$BACKUP_ROOT/had-workspace"; fi
if defaults export com.local.swifttutorapprentice "$BACKUP_ROOT/preferences.plist" >/dev/null 2>&1; then touch "$BACKUP_ROOT/had-preferences"; fi
rm -rf "$DATA_DIR"
mkdir -p "$DATA_DIR"
cp Tests/SwiftTutorApprenticeTests/Fixtures/legacy-lessons.json "$DATA_DIR/lessons.json"
cp Tests/SwiftTutorApprenticeTests/Fixtures/legacy-progress.json "$DATA_DIR/progress.json"
defaults write com.local.swifttutorapprentice hasSeenWelcome -bool true
open "dist/SwiftTutor Apprentice.app"
```

Expected: the fixture title appears, Lesson 2 is still complete, Lessons 1–3
have new stages, and the Lesson 1 Deep Lesson opens before the workspace.

- [ ] **Step 5: Perform the manual migration and UI smoke test**

1. Confirm all 24 lesson IDs and prior completed lessons remain visible.
2. Confirm an edited built-in title survives compatible enrichment.
3. Dismiss Lesson 1 Deep Lesson, replay it, inspect Required and Convention
   tokens, answer recall, fail and pass Modify, confirm editor
   replacement, and Run the modified code.
4. Navigate Lessons 2–3 and repeat the Modify pass path.
5. Navigate Lesson 4 and confirm the unchanged legacy workspace with no
   stepper or auto-sheet.
6. Quit/relaunch and confirm a viewed Deep Lesson does not auto-open while
   completion and stage progress persist.
7. Verify keyboard focus/traversal and status text independent of color.
8. Quit, run `defaults write com.local.swifttutorapprentice hasSeenWelcome -bool
   false`, relaunch, verify Welcome appears first, then press Start learning and
   verify Deep Lesson appears after Welcome dismisses.
9. Use Reset Progress, verify no sheet interrupts the current workspace, then
   navigate to Lesson 2 and back to Lesson 1 and verify its Deep Lesson
   auto-opens.

Expected: every acceptance criterion in the design passes.

- [ ] **Step 6: Restore the user's original state**

Quit the app and restore both persistence surfaces. Run this even if a smoke
step failed; do not continue until it succeeds:

```bash
osascript -e 'tell application id "com.local.swifttutorapprentice" to quit' 2>/dev/null || true
BACKUP_ROOT="$PWD/.tmp/deep-lesson-smoke-backup"
DATA_DIR="$HOME/Library/Application Support/SwiftTutorApprentice"
WORKSPACE_DIR="$HOME/Developer/SwiftTutorApprentice/Workspace"
rm -rf "$DATA_DIR"
if [[ -f "$BACKUP_ROOT/had-data" ]]; then cp -R "$BACKUP_ROOT/data" "$DATA_DIR"; fi
rm -rf "$WORKSPACE_DIR"
if [[ -f "$BACKUP_ROOT/had-workspace" ]]; then cp -R "$BACKUP_ROOT/workspace" "$WORKSPACE_DIR"; fi
defaults delete com.local.swifttutorapprentice >/dev/null 2>&1 || true
if [[ -f "$BACKUP_ROOT/had-preferences" ]]; then defaults import com.local.swifttutorapprentice "$BACKUP_ROOT/preferences.plist" >/dev/null; fi
rm -rf "$BACKUP_ROOT"
```

Expected: original files/preferences are restored and the backup directory is
gone.

- [ ] **Step 7: Review the diff and repository status**

Run:

```bash
git add -N docs/superpowers/plans/2026-07-09-deep-lesson-pilot.md
git diff 1209a45 --check
git diff --cached --check
git status --short
git log -9 --oneline
```

Expected: no whitespace errors, only intended files, and one focused commit per
slice plus the design/plan documentation commits.

- [ ] **Step 8: Commit documentation**

```bash
git add README.md docs/learning-evidence.md
git commit -m "docs: explain deep lesson pilot"
```
