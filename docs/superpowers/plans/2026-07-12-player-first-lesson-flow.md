# Player-First Lesson Flow Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every authored Swift lesson start with a stable full-width 16:9 animated player, place the lesson and coding workspace below it in one outer scroll, and remove the legacy narrated walkthrough that moves and locks the workspace.

**Architecture:** `LessonWorkspace` becomes one bounded vertical lesson document containing the player, canonical lesson header, learning stages, and a fixed-usable-height practice workspace. `LessonPresentationPlayer` owns one invariant 16:9 media boundary and keeps all poster, scene, transcript, status, narration, and focus transitions inside it. The obsolete `AppModel` walkthrough narrator/auto-typing path is removed so presentation playback is the sole narrated lesson system.

**Tech Stack:** Swift 6, SwiftUI and AppKit on macOS, AVFoundation offline speech, Swift Package Manager, XCTest hosted SwiftUI/AppKit layout tests, existing runtime view markers and smoke scripts.

**Design:** `docs/superpowers/specs/2026-07-12-player-first-lesson-flow-design.md`

**Required skills during execution:** `@subagent-driven-development`, `@test-driven-development`, `@systematic-debugging` for unexpected failures, `@verification-before-completion`, and browser/real-app tooling for visible verification.

---

## Chunk 1: Production Structure and Focused Test-First Changes

### File responsibility map

- `Sources/SwiftTutorApprentice/AppModel.swift`: remove the second narrated Walkthrough task, state, speaker, initializer dependency, editor mutation, and cancellation branches; retain normal Run and AI task cancellation.
- `Sources/SwiftTutorApprentice/Views/LessonWorkspace.swift`: own the single outer lesson scroll, canonical below-player title/objective, conditional player presence, stage content, and bounded practice workspace.
- `Sources/SwiftTutorApprentice/Views/LessonPresentationPlayer.swift`: own the exact 16:9 player boundary, all internal surfaces, bounded transcript, control adaptation, and player-local focus restoration.
- `Sources/SwiftTutorApprentice/Views/LessonPanel.swift`: retain practice reference content while removing duplicated Lesson/title/Goal and walkthrough-only active-token input.
- `Sources/SwiftTutorApprentice/Views/SyntaxLensView.swift`: remove walkthrough-only active highlighting while retaining all syntax explanations and glossary interaction.
- `Sources/SwiftTutorApprentice/Views/CodeEditorPanel.swift`: stop receiving walkthrough-derived editability; remain editable according to the normal lesson/practice contract.
- `Sources/SwiftTutorApprentice/Views/CodeTextView.swift`: update obsolete walkthrough comments only if the removed behavior is referenced; do not otherwise rewrite the editor.
- `Sources/SwiftTutorApprentice/Services/NarrationSpeaker.swift`: update comments to name presentation playback as the only owner; preserve the reviewed speech implementation.
- `Tests/SwiftTutorApprenticeTests/AppModelNavigationTests.swift`: delete tests for the removed Walkthrough API and remove the `narrate` fixture dependency; retain Run/AI/navigation cancellation coverage.
- `Tests/SwiftTutorApprenticeTests/LessonPresentationPlayerLayoutTests.swift`: replace collapsed-card assumptions with exact stable-frame, transcript containment, state-transition, scroll-offset, and focus-boundary tests.
- `Tests/SwiftTutorApprenticeTests/CourseWorkspaceLayoutTests.swift`: replace the 35-percent learning-strip contract with one-scroll ordering, conditional player presence, title/path/practice reachability, and minimum-size layout tests.
- `Tests/SwiftTutorApprenticeTests/CourseRootLayoutTests.swift`, `OnboardingAndErrorViewTests.swift`, `OfflineCoreContractTests.swift`: remove only the obsolete `narrate` initializer argument.
- `docs/superpowers/specs/2026-07-12-player-first-lesson-flow-design.md`: already approved; change only if implementation reveals a genuine contradiction, never to weaken acceptance criteria.

Do not modify or stage the pre-existing dirty files
`Scripts/course-platform-smoke-state.sh` or
`Tests/Scripts/restore-transaction-tests.sh` during Tasks 1–5. They belong to
the separately reviewed restore-hardening slice and will be resumed after this
feature is complete.

### Task 1: Retire the legacy narrated Walkthrough

**Files:**
- Modify: `Tests/SwiftTutorApprenticeTests/AppModelNavigationTests.swift`
- Modify: `Tests/SwiftTutorApprenticeTests/CourseWorkspaceLayoutTests.swift`
- Modify: `Tests/SwiftTutorApprenticeTests/CourseRootLayoutTests.swift`
- Modify: `Tests/SwiftTutorApprenticeTests/OnboardingAndErrorViewTests.swift`
- Modify: `Tests/SwiftTutorApprenticeTests/OfflineCoreContractTests.swift`
- Modify: `Sources/SwiftTutorApprentice/AppModel.swift`
- Modify: `Sources/SwiftTutorApprentice/Views/LessonWorkspace.swift`
- Modify: `Sources/SwiftTutorApprentice/Views/LessonPanel.swift`
- Modify: `Sources/SwiftTutorApprentice/Views/SyntaxLensView.swift`
- Modify: `Sources/SwiftTutorApprentice/Views/CodeEditorPanel.swift`
- Modify: `Sources/SwiftTutorApprentice/Views/CodeTextView.swift`
- Modify: `Sources/SwiftTutorApprentice/Services/NarrationSpeaker.swift`

- [x] **Step 1: Add a behavior-preserving marker seam, then a focused failing test**

SwiftUI buttons are not reliably exposed as native `NSButton` descendants in
this hosted process. First add the repository's established behavior-neutral
runtime seam to the existing Walkthrough button in `LessonWorkspace`:

```swift
.background {
    RuntimeViewMarker(identifier: "legacy-walkthrough-action")
}
```

Run the existing `CourseWorkspaceLayoutTests` once to prove this marker-only
change preserves behavior. Then add a test that hosts an authored lesson and
asserts the deterministic `legacy-walkthrough-action` marker is absent while
the normal code editor remains mounted and editable. `markers(named:in:)` is
already the production layout-test seam, so this fails for the exact obsolete
surface rather than depending on hosted accessibility or native SwiftUI
internals. Inspect the underlying `NSTextView.isEditable` rather than testing
source text.

```swift
func testAuthoredLessonHasOnePlaybackSurfaceAndEditablePracticeEditor() throws {
    let fixture = try CourseWorkspaceFixture()
    let model = fixture.makeModel()
    model.openCourse(.swiftDevelopment)
    let rendered = hostInWindow(
        CourseWorkspaceView(model: model, canPresentLearningStages: true),
        size: NSSize(width: 680, height: 520)
    )
    defer { retainWindow(rendered.window) }

    XCTAssertEqual(
        markers(named: "legacy-walkthrough-action", in: rendered.host).count,
        0
    )
    let editor = try XCTUnwrap(descendant(of: NSTextView.self, in: rendered.host))
    XCTAssertTrue(editor.isEditable)
}
```

- [x] **Step 2: Run the regression test and confirm RED**

Run:

```bash
swift test --filter CourseWorkspaceLayoutTests/testAuthoredLessonHasOnePlaybackSurfaceAndEditablePracticeEditor
```

Expected: FAIL specifically with marker count 1 because the current rendered
Walkthrough action owns the marker. The hosted editor assertion separately
guards the desired post-removal editability.

- [x] **Step 3: Remove the obsolete Walkthrough model and UI path**

In `AppModel.swift`, remove:

- `isPlayingWalkthrough`, `walkthroughCaption`, and `activeTokenID`;
- the Walkthrough-owned `NarrationSpeaker`, `narrate` closure, task, and
  generation;
- the `narrate:` initializer parameter;
- `startWalkthrough`, `stopWalkthrough`, `endWalkthrough`, `runWalkthrough`,
  `isCurrentWalkthrough`, and `typeCode`;
- selection/run guards and cancellation branches that exist only for the
  Walkthrough.

Do not change `PresentationPlayerController` or its narrator. Normal explicit
Run remains governed only by `isRunning` and its existing generation checks.

In `LessonWorkspace.swift`, remove the Walkthrough navigation button, external
caption banner, editor lock, and active Syntax Lens token wiring:

```swift
private var lessonPanel: some View {
    LessonPanel(
        lesson: model.currentLesson,
        number: model.currentDisplayNumber
    )
}

private var codePanel: some View {
    CodeEditorPanel(
        code: $model.code,
        placeholder: model.currentLesson.starterCode,
        onInsertStarter: model.insertStarter,
        isEditable: true,
        practiceEnabled: !model.currentLessonIsConcept
    )
}
```

Then remove the now-unused `activeTokenID` inputs from `LessonPanel` and
`SyntaxLensView`. Remove the walkthrough-only async tests and `narrate`
fixture parameters rather than replacing them with meaningless absence tests.

- [x] **Step 4: Run the focused model and workspace tests**

Run:

```bash
swift test --filter AppModelNavigationTests
swift test --filter CourseWorkspaceLayoutTests/testAuthoredLessonHasOnePlaybackSurfaceAndEditablePracticeEditor
```

Expected: PASS. No Walkthrough symbols remain under production sources:

```bash
! rg -n 'startWalkthrough|stopWalkthrough|isPlayingWalkthrough|walkthroughCaption|activeTokenID' Sources/SwiftTutorApprentice
```

- [x] **Step 5: Commit only this slice**

```bash
git add Sources/SwiftTutorApprentice/AppModel.swift \
  Sources/SwiftTutorApprentice/Services/NarrationSpeaker.swift \
  Sources/SwiftTutorApprentice/Views/CodeEditorPanel.swift \
  Sources/SwiftTutorApprentice/Views/CodeTextView.swift \
  Sources/SwiftTutorApprentice/Views/LessonPanel.swift \
  Sources/SwiftTutorApprentice/Views/LessonWorkspace.swift \
  Sources/SwiftTutorApprentice/Views/SyntaxLensView.swift \
  Tests/SwiftTutorApprenticeTests/AppModelNavigationTests.swift \
  Tests/SwiftTutorApprenticeTests/CourseRootLayoutTests.swift \
  Tests/SwiftTutorApprenticeTests/CourseWorkspaceLayoutTests.swift \
  Tests/SwiftTutorApprenticeTests/OfflineCoreContractTests.swift \
  Tests/SwiftTutorApprenticeTests/OnboardingAndErrorViewTests.swift
git commit -m "refactor: retire legacy narrated walkthrough"
```

### Task 2: Make the animated player an invariant 16:9 media surface

**Files:**
- Modify: `Tests/SwiftTutorApprenticeTests/LessonPresentationPlayerLayoutTests.swift`
- Modify: `Sources/SwiftTutorApprentice/Views/LessonPresentationPlayer.swift`

- [x] **Step 1: Write state-invariant geometry, scroll-event, and focus tests before implementation**

Create a hosted harness with a fixed content width and a runtime marker named
`presentation-player-frame`. For widths representative of the minimum and
large detail columns, render poster, resume, active, skipped, completed,
decoded-empty/unavailable, transcript-open, and narration-toggle states.

For every state assert:

```swift
XCTAssertEqual(playerFrame.width / playerFrame.height, 16.0 / 9.0, accuracy: 0.02)
XCTAssertEqual(playerFrame.width, baselineFrame.width, accuracy: 1.0)
XCTAssertEqual(playerFrame.height, baselineFrame.height, accuracy: 1.0)
XCTAssertTrue(rootBounds.insetBy(dx: -1, dy: -1).contains(playerFrame))
```

Also assert the transcript marker and every control marker are contained by the
player marker. Keep existing controller persistence and accessibility tests.

In the same test file, first add the production player to a real vertical
`ScrollView` harness with content above and below. Move the real outer
`NSClipView` to a nonzero, nonterminal offset. Record the player frame and
outer origin, then invoke Start/Resume, Play/Pause, Back, Next, Replay, Skip,
Narration, and Transcript commands. After every action assert the outer origin
changes by no more than one point and the player width and height remain within
one point of baseline.

Before implementing focus restoration, add supported hosted-AppKit assertions:

- Transcript retains first responder when toggled open/closed because the
  control survives both states.
- Start/Replay moves first responder to a player-local focus proxy/control when
  the initiating control is replaced. Obtain the first responder as an
  `NSView`, convert its bounds into the hosting view's coordinate space, and
  assert that frame is geometrically contained by the separately converted
  `presentation-player-frame` marker. Do not assert an AppKit ancestor
  relationship: the runtime marker is a leaf background measurement view.

Also prove scrolling remains operable while the controller is playing and the
narrator spy is suspended. Send a synthetic continuous scroll-wheel event to
the real outer `NSScrollView` using `CGEvent(scrollWheelEvent2Source:units:
wheelCount:wheel1:wheel2:wheel3:)` wrapped as `NSEvent`, and a Down Arrow/Page
Down key event using `NSEvent.keyEvent(...)`. Assert each event changes the
outer offset in the expected direction without pausing playback or changing
player geometry. If the hosted process cannot create a known-good event,
explicitly skip only that event assertion after proving an equivalent baseline
event also fails outside playback; the real-app smoke remains mandatory.

- [x] **Step 2: Run the player layout suite and confirm RED**

Run:

```bash
swift test --filter LessonPresentationPlayerLayoutTests
```

Expected: FAIL for the current production reasons: resume/completed states
collapse, transcript changes content-driven height, state transitions can
change outer layout, and no player-local focus replacement contract exists.

- [x] **Step 3: Implement one invariant media boundary**

Refactor `LessonPresentationPlayer.body` so entry modes choose internal content
but never outer geometry:

```swift
var body: some View {
    ZStack {
        Color(nsColor: .controlBackgroundColor)
        playerSurface
        playerChrome
        if controller.showsTranscript { transcriptOverlay }
    }
    .aspectRatio(16.0 / 9.0, contentMode: .fit)
    .frame(maxWidth: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(...) }
    .background { RuntimeViewMarker(identifier: "presentation-player-frame") }
    .accessibilityElement(children: .contain)
    .onDisappear { controller.deactivate() }
}
```

Keep the existing `isExpanded` state only as an internal surface choice if it
is still required for saved resume semantics; it must never change the frame.
Poster, resume, skipped, completed, and unavailable states fill the frame with
status/visual content and the appropriate actions instead of summary rows.

Implement transcript as a bounded overlay/region inside the frame:

```swift
private var transcriptOverlay: some View {
    ScrollView {
        Text(controller.presentation.transcript)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    .background(.regularMaterial)
    .background { RuntimeViewMarker(identifier: "presentation-transcript") }
}
```

Use `ViewThatFits`, compact labels, or internally scrolling controls at narrow
widths. Do not add a minimum-height override or external transcript content.

- [x] **Step 4: Add player-local focus restoration**

Introduce a private `PlayerFocus` enum and `@FocusState`. Each button that
survives a state change retains focus. Start/Skip/Replay/completion transitions
set a logical destination such as Play/Pause or Replay inside the player after
the state update:

```swift
private enum PlayerFocus: Hashable { case primary, replay, transcript, narration }
@FocusState private var focusedControl: PlayerFocus?

private func start() {
    controller.start()
    focusedControl = .primary
}
```

Transcript toggling always returns focus to `.transcript`. Do not request any
workspace or outer-scroll focus generation from the player.

- [x] **Step 5: Run focused player tests**

Run:

```bash
swift test --filter LessonPresentationPlayerLayoutTests
swift test --filter PresentationPlayerControllerTests
```

Expected: PASS with the existing narration cancellation/persistence coverage
unchanged, including the production-action offset/frame tests and the supported
wheel/keyboard event checks written in Step 1.

- [x] **Step 6: Commit the stable player slice**

```bash
git add Sources/SwiftTutorApprentice/Views/LessonPresentationPlayer.swift \
  Tests/SwiftTutorApprenticeTests/LessonPresentationPlayerLayoutTests.swift
git commit -m "feat: make lesson player a stable media surface"
```

### Task 3: Compose the lesson as one outer vertical document

**Files:**
- Modify: `Tests/SwiftTutorApprenticeTests/CourseWorkspaceLayoutTests.swift`
- Modify: `Sources/SwiftTutorApprentice/Views/LessonWorkspace.swift`
- Modify: `Sources/SwiftTutorApprentice/Views/LessonPanel.swift`
- Modify: `Sources/SwiftTutorApprentice/Views/LessonPresentationPlayer.swift`

- [x] **Step 1: Write layout tests for document order and conditional player presence**

Replace assertions for a separate `learning-scroll` plus visible sibling
workspace panes with these production markers:

- `lesson-document-scroll`
- `detail-top`
- `presentation-player-frame` when applicable
- `lesson-document-header`
- `lesson-stage-path`
- `practice-workspace`
- existing `workspace-upper-pane` and `run-output-pane`

At 680-by-520 and 1280-by-860, assert there is exactly one outer detail scroll,
the document is vertically scrollable, and marker document coordinates follow:

```swift
XCTAssertLessThan(playerFrame.minY, headerFrame.minY)
XCTAssertLessThan(headerFrame.minY, pathFrame.minY)
XCTAssertLessThan(pathFrame.minY, practiceFrame.minY)
```

Cover all three presence categories:

1. normal authored presentation -> stable player;
2. unsupported presentation flag with nil presentation -> unavailable player;
3. ordinary nil/unauthored lesson -> no player and header first.

Assert the 16-point horizontal gutter between the document and player boundary
within layout tolerance, not against the entire app window/sidebar.

- [x] **Step 2: Run workspace layout tests and confirm RED**

Run:

```bash
swift test --filter CourseWorkspaceLayoutTests
```

Expected: FAIL because the current workspace owns a 35-percent nested
`learning-scroll` and keeps the practice split outside it.

- [x] **Step 3: Build the single outer document**

In `LessonWorkspace.body`, keep `navigationBar` outside the detail document,
then replace `learningHeight`, `learningViewport`, and the sibling `VSplitView`
with one `ScrollViewReader` and vertical `ScrollView`:

```swift
GeometryReader { detailGeometry in
    ScrollViewReader { proxy in
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                detailTopMarker
                playerSection
                lessonDocumentHeader
                stageAndLearningContent
                practiceWorkspace
                    .frame(height: max(minimumWorkspaceHeight,
                                       detailGeometry.size.height - 32))
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background { ScrollViewportProbe(identifier: "lesson-document-scroll") }
        .onChange/task for explicit detail-top and Recall navigation only
    }
}
```

Use the existing `VSplitView` inside `practiceWorkspace`; it receives a finite
height so editor and output panels remain usable. Keep the 860-point
wide/narrow panel switch. Do not use nested outer lesson scrolling around this
document.

The canonical header is:

```swift
private var lessonDocumentHeader: some View {
    VStack(alignment: .leading, spacing: 6) {
        Text("Lesson \(model.currentDisplayNumber)")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
        Text(model.currentLesson.title).font(.title2.bold())
        Text(model.currentLesson.goal)
            .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 16)
    .padding(.top, 18)
    .background { RuntimeViewMarker(identifier: "lesson-document-header") }
}
```

Remove Lesson/title/Goal from `LessonPanel`, retaining the practice reference
sections specified by the design.

For `presentation == nil && hasUnsupportedPresentation`, render a stable
`LessonPresentationUnavailablePlayer` using the same exact 16:9 frame
component/marker. For ordinary nil presentations, omit the frame.

- [x] **Step 4: Keep only intentional outer scrolling**

Retain `proxy.scrollTo("detail-top")` for explicit course/lesson navigation and
the existing linked Recall destination for stage-path navigation. Confirm that
`LessonPresentationPlayer` receives no scroll proxy, scroll coordinator, Recall
focus callback, or practice focus callback.

- [x] **Step 5: Run focused workspace and root tests**

Run:

```bash
swift test --filter CourseWorkspaceLayoutTests
swift test --filter CourseRootLayoutTests
swift test --filter LessonLearningLoopTests
```

Expected: PASS. The practice workspace remains reachable and finite in both
supported sizes.

- [x] **Step 6: Commit the document composition slice**

```bash
git add Sources/SwiftTutorApprentice/Views/LessonWorkspace.swift \
  Sources/SwiftTutorApprentice/Views/LessonPanel.swift \
  Sources/SwiftTutorApprentice/Views/LessonPresentationPlayer.swift \
  Tests/SwiftTutorApprenticeTests/CourseWorkspaceLayoutTests.swift
git commit -m "feat: place lessons in one player-first document"
```

### Task 4: Focused code-quality and specification review

**Files:**
- Review all files changed by Tasks 1–3
- Modify only files with validated findings

- [x] **Step 1: Request a fresh specification-compliance review**

Provide the reviewer only the approved design, plan, Task 1–3 commit range,
and worktree path. Require explicit coverage of player-first ordering, exact
16:9 state invariance, conditional player presence, one outer scroll,
Walkthrough removal, narration ownership, progress compatibility,
accessibility, and no unrelated restore-file edits.

- [x] **Step 2: Fix validated specification findings with focused RED/GREEN evidence**

For every material finding, first add or identify the focused failing test,
then make the minimum fix and rerun the relevant suite. Reject speculative
scope expansion.

- [x] **Step 3: Request a fresh code-quality review**

Check SwiftUI identity/state lifetime, controller deactivation, focus updates,
scroll ownership, finite sizing, AppKit test reliability, accessibility order,
and dead Walkthrough code. Require findings with file/line evidence.

- [x] **Step 4: Resolve validated quality findings and commit**

Use a focused commit per coherent fix. Do not stage the dirty restore files.

---

## Chunk 2: Verification, Real-App Proof, and Milestone Continuation

### Task 5: Verify the player-first code in proportion to its risk

**Files:**
- No production edits unless verification exposes a defect
- Update existing milestone evidence/handoff only at the normal final milestone documentation step

- [x] **Step 1: Run targeted tests once after review fixes**

```bash
swift test --filter LessonPresentationPlayerLayoutTests
swift test --filter CourseWorkspaceLayoutTests
swift test --filter PresentationPlayerControllerTests
swift test --filter AppModelNavigationTests
swift test --filter LessonLearningLoopTests
```

Expected: all PASS. These are the behaviorally relevant suites; do not add
extra unrelated repetitions.

- [x] **Step 2: Run the full package gate once**

```bash
swift test
swift build
```

Expected: both exit 0. If a failure is unrelated, use
`@systematic-debugging` and preserve the failure evidence rather than rerunning
blindly.

- [x] **Step 3: Record the automated gate without claiming runtime completion**

Record exact command exits and commit. Do not build the app bundle or touch
learner data yet: the preserved restore transaction must be completed,
reviewed, and committed first.

### Task 6: Finish the safety blockers before any real-app smoke

**Files:**
- Preserve and resume: `Scripts/course-platform-smoke-state.sh`
- Preserve and resume: `Tests/Scripts/restore-transaction-tests.sh`
- Follow: `docs/CODEX_COURSE_PLATFORM_M1_CONTINUATION_2026-07-11.md`
- Follow the existing milestone plan/design documents named by that handoff

- [x] **Step 1: Re-read the continuation handoff and reconcile completed commits**

Record the player-first feature commits as an approved additive user-directed
change. Do not shrink or replace the remaining Task 20, merge, bundle, public
push, or CI obligations.

- [x] **Step 2: Finish the preserved restore-transaction hardening slice**

Review the existing dirty changes before editing. Run only their documented
focused tests first, resolve validated findings, obtain the required fresh
spec/code-quality reviews, and commit them without mixing player UI files.

The minimum local gate before the first real backup is:

```bash
bash -n Scripts/course-platform-smoke-state.sh
bash -n Tests/Scripts/restore-transaction-tests.sh
bash Tests/Scripts/restore-transaction-tests.sh \
  Scripts/course-platform-smoke-state.sh
```

Expected: both syntax checks exit 0 and the test prints
`restore transaction safety tests passed`. Then obtain fresh specification and
code-quality approval and commit these two files. Do not run `backup`, `clean`,
or any fixture command before that approval and commit.

- [x] **Step 3: Resolve the remaining branch-wide findings from the handoff**

At minimum, address the still-open process-runner descendant-held-pipe finding
and final documentation checkbox if they remain current. Use focused TDD and
fresh review; do not redo already approved fixes.

Run the process runner's focused gate after the fix:

```bash
swift test --filter CancellableProcessRunnerTests
```

Expected: PASS, including the regression where a descendant holds inherited
stdout/stderr pipe descriptors. Commit the reviewed fix before bundle work.

- [x] **Step 4: Prove the worktree is ready for provenance-gated bundle work**

```bash
git status --short
git diff --check
```

Expected: no tracked source/script/test changes. The protected continuation
handoff may remain untracked, but no uncommitted production or restore tooling
may remain.

### Task 7: Build the exact feature bundle and perform protected real-app proof

**Files:**
- Verify bundle: `dist/SwiftTutor Apprentice.app`
- Use: `Scripts/course-platform-smoke-state.sh`
- Create: `docs/testing/course-platform-milestone-1-smoke.md`

- [x] **Step 1: Build and verify the exact clean feature bundle**

Run exactly:

```bash
swift build -c release --disable-sandbox
./Scripts/build-app.sh
bash Scripts/verify-app-bundle.sh
```

Expected: every command exits 0; the verifier prints the absolute verified
bundle path, signed executable SHA-256, manifest unsigned SHA-256, and source
commit matching `git rev-parse HEAD`. The bundle under test is exactly:

```text
dist/SwiftTutor Apprentice.app
```

Do not treat the first `swift build` command as bundle proof.

- [x] **Step 2: Prepare native verification and an unconditional restore trap**

Read and follow the `computer-use:computer-use` skill before interacting with
the native macOS app. Quit any running SwiftTutor instance, then create the
protected session only after Task 6 has passed:

```bash
SESSION="$(bash Scripts/course-platform-smoke-state.sh backup)"
test -n "$SESSION" && test -d "$SESSION"
restore_original() {
  if [[ -n "${SESSION:-}" && -d "$SESSION" ]]; then
    if bash Scripts/course-platform-smoke-state.sh restore "$SESSION"; then
      SESSION=""
      return 0
    fi
    echo "Restore failed; protected recovery session remains at: $SESSION" >&2
    return 1
  fi
}
restore_on_exit() {
  local original_status="$?"
  trap - EXIT INT TERM
  if ! restore_original; then
    exit 1
  fi
  exit "$original_status"
}
trap restore_on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
```

Record only the session path in private execution state, never learner file
contents or preference values. Any failure from this point still runs
`restore_original`; a restore failure blocks merge.

- [x] **Step 3: Exercise clean state and the player-first interaction contract**

```bash
bash Scripts/course-platform-smoke-state.sh clean "$SESSION"
open -na "$PWD/dist/SwiftTutor Apprentice.app"
```

Using Computer Use on the actual app bundle:

1. verify Course Home and enter Swift Development;
2. set/check a 680-by-520 window;
3. open authored Lessons 1–3 and confirm the exact 16:9 player is first inside
   its gutters with title/path/content below;
4. play/narrate for at least 60 seconds while repeatedly scrolling with mouse/
   trackpad-equivalent gestures, Down Arrow, and Page Down;
5. exercise Pause, Back, Next, Replay, Narration, Transcript, Skip, and Read
   Deeper;
6. verify no action changes the outer offset, clips above navigation, locks the
   editor, traps focus outside the player, or opens unrelated UI;
7. confirm transcript remains inside the frame and the player scrolls away
   naturally without becoming sticky;
8. edit and Run code in the practice workspace;
9. repeat poster, transcript, and completed states in a larger window;
10. open an ordinary unauthored lesson such as Lesson 4 and confirm it shows no
    synthetic player and begins with title/objective.

- [x] **Step 4: Exercise legacy and byte-preservation fixtures with exact guarded commands**

For legacy migration:

```bash
bash Scripts/course-platform-smoke-state.sh legacy "$SESSION"
open -na "$PWD/dist/SwiftTutor Apprentice.app"
```

Verify the documented legacy migration path, then quit the app before the next
fixture (the guarded script also enforces quit).

For future progress:

```bash
PROGRESS_FILE="$HOME/Library/Application Support/SwiftTutorApprentice/progress.json"
bash Scripts/course-platform-smoke-state.sh future-progress "$SESSION"
bash Scripts/course-platform-smoke-state.sh snapshot \
  "$SESSION" "$PROGRESS_FILE" future-progress-before
open -na "$PWD/dist/SwiftTutor Apprentice.app"
# Attempt the documented progress mutations through Computer Use, then quit.
bash Scripts/course-platform-smoke-state.sh assert-unchanged \
  "$SESSION" "$PROGRESS_FILE" future-progress-before
```

For future/unsupported lessons:

```bash
LESSONS_FILE="$HOME/Library/Application Support/SwiftTutorApprentice/lessons.json"
bash Scripts/course-platform-smoke-state.sh future-lessons "$SESSION"
bash Scripts/course-platform-smoke-state.sh snapshot \
  "$SESSION" "$LESSONS_FILE" future-lessons-before
open -na "$PWD/dist/SwiftTutor Apprentice.app"
# Verify the stable unavailable player and attempt documented mutations, then quit.
bash Scripts/course-platform-smoke-state.sh assert-unchanged \
  "$SESSION" "$LESSONS_FILE" future-lessons-before
```

For corrupt progress:

```bash
bash Scripts/course-platform-smoke-state.sh corrupt-progress "$SESSION"
bash Scripts/course-platform-smoke-state.sh snapshot \
  "$SESSION" "$PROGRESS_FILE" corrupt-progress-before
open -na "$PWD/dist/SwiftTutor Apprentice.app"
# Attempt documented mutations, then quit.
bash Scripts/course-platform-smoke-state.sh assert-unchanged \
  "$SESSION" "$PROGRESS_FILE" corrupt-progress-before
```

Expected: every guarded command exits 0; future/corrupt files remain
byte-identical; the unsupported presentation path shows the specified stable
unavailable frame without blocking lesson content.

- [x] **Step 5: Restore original learner state unconditionally and prove it**

```bash
if ! restore_original; then
  echo "Merge blocked; retry restore with the preserved session path." >&2
  exit 1
fi
trap - EXIT INT TERM
test -z "$SESSION"
```

Expected: restore exits 0, internally verifies Application Support, Workspace,
and normalized preferences, removes the protected session, and clears the
local session variable. If restore fails, the session path remains available,
the trap stays armed, the shell exits nonzero, and merge is blocked.

- [x] **Step 6: Record evidence without private state and commit it**

Create `docs/testing/course-platform-milestone-1-smoke.md` containing only
dates, commit, bundle path, hashes printed by the verifier, exact commands,
fixture labels, and pass/fail outcomes. Never record learner contents,
preference values, or backup payload details.

```bash
git add docs/testing/course-platform-milestone-1-smoke.md
git commit -m "test: record course platform app smoke"
```

### Task 8: Finish the parent Course Platform Milestone 1 boundary

- [x] **Step 1: Finish Task 20 documentation and branch-wide review**

Update README, `docs/learning-evidence.md`, and only evidenced plan checkboxes,
including the user-approved player-first behavior while keeping the full Web,
Cybersecurity, Networking, and certification programs explicitly future scope.
Request the required branch-wide code/product review against `main`, resolve
validated findings test-first, and commit coherent documentation/review fixes.

- [x] **Step 2: Run final feature-branch gates once**

```bash
swift test
swift build -c release --disable-sandbox
./Scripts/build-app.sh
bash Scripts/verify-app-bundle.sh
```

Expected: all exit 0 and the verified feature bundle manifest records exact
feature `HEAD`.

- [ ] **Step 3: Execute the handoff's merge and merged-main bundle boundary exactly**

Perform the explicit merge commit into local `main`, then from merged main run:

```bash
swift test
swift build -c release --disable-sandbox
./Scripts/build-app.sh
bash Scripts/verify-app-bundle.sh
open -na "$PWD/dist/SwiftTutor Apprentice.app"
```

Use Computer Use to confirm Course Home and the player-first Swift lesson from
the exact merged-main bundle. Keep this merged-main proof distinct from Task
7's feature-branch smoke.

- [ ] **Step 4: Push public main and verify hosted truth**

Push public `main`, verify GitHub CI to completion, and verify public LICENSE,
CONTRIBUTING, SECURITY, README, and future-scope claims at the pushed commit.

- [ ] **Step 5: Run `@verification-before-completion` and complete the persistent goal**

Check current `git status`, exact commit/merge range, feature and merged-main
bundle provenance, protected restore evidence, real-app proof, public push, CI,
and targeted/full test output.

Do not mark complete because the player-first feature alone works. Report the
final goal token usage when the goal tool returns it.
