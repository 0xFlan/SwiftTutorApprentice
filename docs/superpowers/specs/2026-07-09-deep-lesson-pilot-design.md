# Deep Lesson Pilot v1 Design

## Decision

Build an additive, offline teaching layer for the existing Swift curriculum and
pilot it on Lessons 1–3. The Deep Lesson appears before the current workspace,
but it can be skipped and replayed. The existing Predict, Run, coach,
walkthrough, Parsons, bug-hunt, completion, lesson editing, and navigation
behavior remains available and unchanged.

This design implements the user-approved council recommendation. It does not
add web tracks, a web runner, a course-track shell, prerequisite locking, a
spaced-review scheduler, or a product rebrand.

## Considered Approaches

### 1. Broad multi-track platform

Add Swift and web course tracks, new runners, a parser, review scheduling, and
a course shell together. This offers a larger future platform but combines
unrelated migration, execution, curriculum, and navigation risks. It is
rejected for this milestone.

### 2. Replace the workspace with a mandatory lesson wizard

Turn every lesson into a locked sequence of explanation, microscope, modify,
and run screens. This makes the recommended path obvious, but it changes the
current learning loop and creates unnecessary migration and usability risk. It
is rejected because the current workspace must remain usable.

### 3. Additive Deep Lesson layer (selected)

Attach optional deep content to a lesson, present it before practice the first
time, and expose replayable Deep Lesson and Modify stages above the existing
workspace. This is the smallest approach that teaches why the code works while
preserving all existing behavior and data.

## Architecture and Boundaries

### Lesson data

`Lesson` gains one optional `deepContent` field. The field defaults to `nil`
when decoding older lesson JSON. Its nested value types live in a separate
model file so `Lesson` remains readable. The concrete contract is:

- `ConceptID`: a string-backed, Codable stable identifier so adding a concept
  does not make older content undecodable.
- `LessonDeepContent`: nonempty `title` and `introduction`, at least one
  `segment`, at least one `microscopeToken`, exactly one `modifyTask`, and at
  least one `recallQuestion`.
- `DeepLessonSegment`: stable string `id`, nonempty `title` and `explanation`,
  optional `correctCode`, and paired optional `wrongCode` plus
  `wrongExplanation`. Pilot segments that teach syntax include both examples.
- `SyntaxMicroscopeToken`: stable string `id`, `display`, `role`,
  `requirement` (`required`, `convention`, or `contextual`), `explanation`, and
  `ifChanged` text explaining the effect of omission or alteration.
- `ModifyTask`: stable string `id`, `prompt`, `starterCode`, `expectedCode`,
  `predictionPrompt`, `expectedOutput`, `successExplanation`, and one or more
  concept IDs.
- `RecallQuestion`: stable string `id`, `prompt`, two or more `choices`, a
  valid `correctChoiceIndex`, `explanation`, and one or more concept IDs.

Only the built-in Lessons 1–3 receive values in v1. All other built-in and
custom lessons keep `deepContent == nil` and follow the current UI path.

### Lesson enrichment migration

`LessonStore` receives a file-URL initializer for isolated tests. On load it
continues to append missing default lesson IDs. It also performs a field-level
enrichment pass. A saved lesson is compatible with built-in enrichment only
when all of these are true: its ID matches a built-in lesson, its `kind`
matches, its `starterCode` exactly matches that built-in lesson, it has no deep
content, and the built-in lesson has deep content. The store then copies only
`deepContent`. Matching the code prevents stock explanations from being
attached to a heavily edited lesson or a custom lesson that happens to reuse a
built-in ID. Edits to title, goal, syntax tokens, output, coaching text, and
order remain untouched when the starter code still matches.

The merged result is saved only when something actually changed. A malformed
or empty file keeps the existing behavior of restoring defaults.

### Versioned progress

The progress JSON becomes versioned while retaining `completedLessonIDs` at
the top level. Missing `version` and `stageEvents` fields decode as legacy
version 1 with no stage events. The current schema version is 2.

Stage events are additive records containing a lesson ID, event kind,
timestamp, optional `questionID`, and optional `wasCorrect`. Supported kinds
are:

- Deep Lesson viewed
- Modify task passed
- Recall question answered

Deep Lesson viewed and Modify passed are idempotent on `(lessonID, kind)`.
Recall answers are idempotent on `(lessonID, recallAnswered, questionID)` and
store the correctness of the first submitted answer. Recall events require
both recall metadata fields; other event kinds store neither. Duplicate writes
are ignored. Loading a legacy file does not rewrite it immediately; the first
subsequent progress change writes schema version 2 with preserved completion
IDs and all in-memory events. Reset clears completion and all stage events.
Existing completion behavior is unchanged: only a clean run with exact
expected output (or the current concept lesson action) completes a lesson.

Both stores use their current Application Support URLs in production and
injected temporary URLs in tests. `ProgressStore` also accepts an injected
clock, defaulting to `Date.init`, so event timestamps are deterministic in
tests.

### Learning views

`LessonStageStepper` shows the non-locking recommended path:

1. Deep Lesson
2. Modify
3. Practice & Run

It shows Deep Lesson complete when a viewed event exists, Modify complete when
a passed event exists, and Practice & Run complete only when the legacy lesson
completion ID exists. It provides replay buttons and never blocks a later
stage.

`DeepLessonView` is a scrollable, concept-first sheet. It shows the lesson
introduction, narrated segments, correct examples, wrong variants, a
`SyntaxMicroscopeView`, and recall questions. Opening it records the viewed
event. Dismissing it leaves the normal workspace intact.

`SyntaxMicroscopeView` renders richer tokens and explicitly labels whether a
piece is required by Swift, conventional style, or dependent on context. Each
token explains both its role and what changes when it is omitted or altered.

`ModifyTaskView` starts with working code, asks the learner to predict the new
output, and guides one small change. Here “output” means the learner's
prediction, not executed output; real execution remains in the existing
workspace. A pure evaluator normalizes CRLF/CR line endings to LF and removes
only final line-break characters from code before exact, case-sensitive
comparison. It does not trim spaces, so spaces inside string literals remain
semantic. Predictions are compared exactly after trimming only surrounding
whitespace and line breaks. The evaluator returns `codeDoesNotMatch`,
`predictionDoesNotMatch`, `bothDoNotMatch`, or `passed`, and the view maps each
result to a targeted retry message. Passing records the Modify event and offers
to place the result in the existing editor for a real Run. Failure preserves
the learner's work and does not change completion.

`LessonWorkspace` owns only sheet presentation and connects these views to the
current lesson, editor, and progress store. On initial launch or lesson
selection, an enriched lesson with no viewed event opens automatically. Replay
is always explicit and never auto-opens a second sheet. Resetting progress does
not interrupt the current workspace; the Deep Lesson will auto-open on the next
selection or app launch. The learner can dismiss the sheet immediately and can
replay it later from the stepper.

The Modify sheet's final action is explicitly labeled “Replace editor with
this code.” If the editor contains different nonempty code, the learner must
confirm the replacement. On confirmation, the workspace receives the modified
code and the learner's prediction, clears the stale run result, and leaves
legacy completion untouched until the learner presses Run.

## Pilot Content

### Lesson 1: Printing Text

Explain the `print` function call, paired parentheses, paired quotation marks,
the string literal, standard output, and why spaces inside quotes are data while
spaces outside are mostly style. Wrong variants demonstrate missing quotes and
printing a different literal. Modify asks the learner to change the message and
predict the new output.

### Lesson 2: Constants

Explain `let`, the chosen name, assignment, the stored string value, and the
difference between `print(name)` and `print("name")`. Wrong variants demonstrate
quoting the variable name and trying to reassign a constant. Modify asks the
learner to change the stored name and predict the output.

### Lesson 3: Variables

Explain `var`, initial assignment, reassignment, mutation, integer literals,
and the compile-time difference between `let` and `var`. Wrong variants show
reassignment after `let`. Modify asks the learner to change the later assigned
value and predict the final output.

## Error Handling and Accessibility

- Unknown or absent deep content never prevents a lesson from loading.
- Invalid saved JSON follows the current default-seeding behavior.
- Failed Modify checks preserve the learner's code and prediction.
- Stage events are not lesson completion and cannot accidentally mark a lesson
  complete.
- Buttons have text labels and system images; status is communicated by text
  and symbols, not color alone.
- All teaching content remains local and requires no network access.

## Testing and Verification

Automated tests cover:

- a new SwiftPM test target and isolated temporary fixture directories;
- legacy lesson JSON without `kind` or `deepContent`;
- old custom lessons without new fields;
- 24 stable built-in IDs;
- backfilling only deep content when starter code is compatible while
  preserving edited legacy fields;
- refusing enrichment when a built-in ID has different starter code;
- appending missing defaults without duplicating IDs;
- legacy progress preserving completed IDs;
- version 2 progress event schema, timestamp injection, promotion, validation,
  persistence, and idempotency keys;
- reset behavior;
- Modify evaluation success, all three failure categories, line-ending
  normalization, and semantic whitespace preservation;
- complete Deep Lesson content and required/convention microscope categories
  for Lessons 1–3.

Verification includes `swift test`, `swift build`, and a macOS app smoke test:
launch, navigate Lessons 1–3, dismiss and replay Deep Lesson, inspect required
versus convention tokens, fail and pass Modify, send modified code to the
editor (including the replacement confirmation), Run it, navigate to an
unenriched lesson, and relaunch against legacy lesson/progress fixtures to
confirm preservation. The smoke test also checks initial keyboard focus,
keyboard traversal, readable microscope accessibility labels, and status text
that does not rely on color alone.

## Acceptance Criteria

- All 24 built-in Swift lessons load with unchanged IDs.
- Existing completed lesson IDs remain complete.
- Old custom lessons decode and remain usable.
- Saved built-in lesson edits are not overwritten by enrichment.
- Lessons 1–3 have concept-first Deep Lessons, syntax semantics, wrong
  variants, recall prompts, and working Modify tasks.
- Deep Lesson can be skipped, opened automatically only before first view, and
  replayed later.
- Syntax Microscope distinguishes required syntax from convention.
- Existing completion behavior and workspace remain unchanged.
- The app is fully offline by default.
- Automated tests and `swift build` pass, and the manual smoke path succeeds.
