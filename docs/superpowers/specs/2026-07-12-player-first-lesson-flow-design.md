# Player-First Lesson Flow Design

Date: 2026-07-12
Status: user-approved visual direction; implementation specification

## Decision

Restructure the Swift course lesson detail into one vertically scrolling,
player-first learning document. After the compact lesson navigation bar, the
offline animated lesson player is the first content surface and uses the full
available detail-column width at a stable 16:9 aspect ratio. The lesson title,
objective, learning path, recall, modification, and practice workspace follow
below it in normal document flow.

Playback remains entirely inside the player. Starting, pausing, replaying,
seeking between scenes, toggling narration, showing captions, or opening the
transcript must not move the outer lesson scroll position, resize the player,
move keyboard focus outside the player, open a sheet, or block manual
scrolling. Focus remains on the invoked control when that control survives the
state change; if the transition replaces it, focus moves to the logical
replacement control inside the player. The player is not sticky and naturally
scrolls out of view when the learner moves down to practice.

This design preserves the existing offline presentation content, progress
schema, Deep Lesson content, Recall stage, Modify task, AI code review,
three-panel practice workspace, and completion rules. It changes their visual
composition and the presentation player's layout contract; it does not add a
new course type, remote video service, autoplay, or a new learning-progress
schema.

It deliberately retires the separate legacy narrated Walkthrough. That older
path lives outside `LessonPresentationPlayer`, clears and auto-types into the
practice editor, highlights the lesson panel, runs code, disables editing, and
uses a second narration owner. Those behaviors match the reported loss of
screen and editor control and conflict with the approved requirement that
narrated playback be a distinct top player. The Walkthrough button, external
caption banner, `AppModel` walkthrough task/narrator state, editor locking, and
walkthrough-only token highlighting are removed. Insert Starter, Syntax Lens,
the authored player, Deep Lesson, Recall, Modify, and normal Run remain.

The supporting evidence and product review are recorded in
`outputs/2026-07-12-coding-learning-layout-research.md` and its provenance
file.

## Approved Visual Hierarchy

The selected hierarchy is:

1. compact course/lesson navigation bar;
2. wide 16:9 animated lesson player;
3. lesson title and one plain-language objective;
4. compact `Watch -> Recall -> Modify -> Practice/Run` path;
5. persistence warnings, when present;
6. linked Recall and other lesson-specific learning checks;
7. the existing coding workspace and Run output.

The player is the first lesson content the learner sees. The title and path
sit immediately below it so the player remains visually dominant without
removing orientation. The page uses one outer vertical scroll rather than a
small learning strip above a permanently visible, separately split workspace.
Editor, transcript, lesson-panel, and output regions may retain bounded inner
scrolling where their own content requires it, but they cannot take ownership
of the outer lesson scroll.

## Alternatives Considered

### Keep the current 35-percent learning strip

The current `LessonWorkspace` reserves at most 35 percent of the detail height
for `learningViewport`, then displays the coding workspace underneath in a
separate fixed region. This keeps practice visible but makes the presentation
feel like a banner, clips expanded player states at short window heights, and
allows player state changes to reflow a constrained scroll surface. It does
not match the approved player-first direction and is rejected.

### Sticky player over the coding workspace

A sticky or floating player would keep playback visible while coding, but it
would consume too much of the supported 680-by-520 window, obscure lesson
content, and introduce another source of focus and scroll interference. The
user explicitly approved a player that scrolls away, so this is rejected.

### Separate video sheet or full-screen mode

Presenting narration in a sheet would isolate it from the workspace but would
also take control of the screen, reproduce the reported interaction problem,
and break the familiar video-first document model. This is rejected.

### Single player-first lesson document (selected)

A stable player in normal document flow matches the requested YouTube-like
orientation while allowing the rest of the lesson to continue below. It also
gives playback a testable containment boundary and retains the full existing
learning loop.

## Lesson Workspace Composition

`LessonWorkspace` continues to own lesson navigation, the
`LessonWorkspaceSession`, presentation sheets for Deep Lesson and Modify,
progress integration, persistence warnings, and the existing practice panels.
Its detail body changes from a fixed `learningViewport` plus a sibling
`VSplitView` into one bounded outer lesson `ScrollView` inside the existing
detail `GeometryReader`.

The scroll document contains two major sections:

- `learningDocument`: player, title/objective, stage path, warnings, Recall,
  and AI code review;
- `practiceWorkspace`: the existing wide three-column or narrow tabbed
  workspace plus Run output, with a deliberate minimum height so it remains a
  usable work surface after the learner scrolls to it.

The outer document is always constrained to the detail viewport width. It may
be taller than the viewport and must scroll vertically at the supported
680-by-520 window. It must never publish an infinite or oversized horizontal
fitting width.

The existing `detail-top` marker remains the explicit destination for course
or lesson navigation. That navigation may intentionally move to the top. A
learner selecting Recall from the stage path may intentionally move to the
Recall card. Those are document-navigation commands and are not player
controls. No action originating in `LessonPresentationPlayer` may invoke an
outer scroll command.

The practice workspace keeps its responsive behavior:

- at 860 points or wider, Lesson, Code, and Coach remain side-by-side;
- below 860 points, the segmented Lesson/Code/Coach selector remains;
- Run output remains below the upper workspace;
- editor and output functionality and completion rules remain unchanged.

## Stable Player Contract

`LessonPresentationPlayer` becomes a stable media frame rather than a card
whose height changes by entry mode.

### Geometry

- The outer player frame fills the available lesson-document width.
- Standard 16-point lesson-document gutters sit outside the media boundary.
  The rounded outer media boundary is exactly 16:9 at every supported detail
  width; there is no minimum-height override. Accessibility is handled through
  internal reflow, bounded scrolling, and compact control grouping rather than
  changing the aspect ratio.
- Poster, resume, active, skipped, completed, unavailable, transcript-open,
  caption, and narration states all occupy the same outer frame.
- Player content clips inside the rounded media boundary. It cannot clip above
  the lesson navigation bar or outside the detail column.
- The frame uses normal document positioning. It has no sticky, floating,
  overlay-window, or mini-player behavior.

### Internal regions

The player contains:

1. a scene/poster region occupying the available space above the controls;
2. the scene caption inside the media region;
3. a bottom transport/control bar;
4. an optional bounded transcript region inside the same frame.

The scene visual adapts within the media region and may use compact internal
layout at narrow widths. Text must truncate or internally scroll where
necessary rather than growing the outer player.

Opening the transcript does not insert content below the player or increase
the player's height. It presents the transcript inside a bounded, independently
scrollable player region, with an explicit close/hide control. The authored
caption remains available without requiring transcript expansion.

### Entry modes

- **Poster:** shows title, poster description/state, and a prominent Play
  control inside the frame.
- **Resume:** shows the saved scene/poster with Resume and Replay controls,
  without collapsing the frame.
- **Active scene:** shows the visual state, scene title/count, caption,
  playback state, and controls.
- **Skipped/completed:** preserves the full player frame with clear status and
  Replay; it does not collapse into a summary row.
- **Unavailable:** preserves the full frame with a local-unavailable message
  and Read Deeper when applicable.

The existing presentation state machine remains authoritative. No progress is
inferred from merely rendering the larger frame.

## Playback and Narration Containment

The containment rule applies to Start, Resume, Play, Pause, Back, Next,
Replay, Skip, Narration, Transcript, and any future seek control.

Each action may update only presentation-owned state and the existing
presentation progress record. It must not:

- call the outer `ScrollViewReader` proxy;
- change `LessonScrollCoordinator` generations;
- request Recall or practice focus;
- set focus on an element outside the player;
- present Deep Lesson or Modify automatically;
- alter the player aspect ratio or measured outer height;
- disable hit testing or scrolling on the outer lesson document;
- begin speech or motion without an explicit learner playback action.

Narration remains optional, fully offline, and coupled to presentation
playback. Toggling narration off stops current speech. Toggling it on does not
autoplay or move to another scene. Starting or resuming playback may narrate
the current scene according to the existing controller contract. Switching
lessons, leaving the workspace, pausing, skipping, replaying, or replacing a
presentation continues to cancel obsolete narration safely.

Player-local keyboard shortcuts operate only while the corresponding player
action is available. Space must not trap the learner inside the player or
prevent arrow, Page Up/Down, and trackpad/mouse scrolling of the lesson.

The presentation player is the only narrated lesson-playback owner. The legacy
`AppModel.startWalkthrough()` flow and its independent `NarrationSpeaker` are
removed rather than integrated, because they mutate and lock the practice
workspace while speaking. Consequently presentation narration cannot overlap
with a second narrated lesson system.

## Learning Sequence Below the Player

The visible sequence uses the current milestone labels:

1. **Watch:** learner-controlled, segmented animated explanation.
2. **Recall:** predict or explain before replaying cues.
3. **Modify:** change a working example with specific feedback.
4. **Practice/Run:** use the existing editor and runner with less scaffolding.

The player does not claim mastery. Watch status continues to represent
presentation progress only. Recall, Modify, and legacy Practice/Run completion
remain distinct evidence. Existing Deep Lesson and AI review experiences stay
available; Read Deeper remains an explicit player action and AI review remains
in the document below the core path when authored.

The stage path remains non-locking. Selecting Watch may expose/replay the
player without moving the outer document. Selecting Recall may intentionally
scroll the document to Recall. Selecting Modify may explicitly open its current
sheet. Practice remains the visible workspace below.

The below-player lesson header uses `Lesson.title` as its title and
`Lesson.goal` as its plain-language objective. `LessonPresentation.title`
remains player-local authored media metadata and does not replace the lesson
title. To avoid repeating the same hierarchy twice on one page,
`LessonPanel` no longer repeats its `Lesson N`, title, or Goal block. It retains
What You Will Type, What This Teaches, Terms, and Syntax Lens as the reference
panel for practice.

## Accessibility

- The player exposes one meaningful media/player container with children in a
  logical order: status, scene description/caption, controls, transcript.
- All controls keep explicit text accessibility labels and useful help.
- Playback status, stage status, skipped/completed state, and focus are not
  communicated by color alone.
- VoiceOver and keyboard users can enter the player, activate every available
  control, and leave it without a focus trap.
- Opening or closing transcript retains focus on the invoking transcript
  control, which remains present in both states, unless the learner explicitly
  navigates into transcript text.
- Captions and a complete text transcript remain available.
- Reduce Motion removes nonessential scene transition animation while
  preserving scene state and narration controls.
- At 680-by-520 and larger supported sizes, visible controls do not clip outside
  the player. Narrow controls may adapt into multiple internal rows or a menu,
  but remain reachable and do not grow the frame.

## Data, Persistence, and Compatibility

No data migration is required. The design reuses:

- `Lesson.presentation` and existing bundled presentation revisions;
- `LessonPresentationState` and `ProgressStore` persistence;
- Deep Lesson viewed, Recall answered, Modify passed, and completion evidence;
- current future-schema and read-only preservation behavior.

Existing saved presentation states reopen in the corresponding stable full
player state. Completed or skipped presentations no longer collapse visually,
but their saved status and replay semantics are unchanged.

Player presence is conditional and follows three explicit categories:

- A lesson with a decoded non-nil presentation always renders the stable
  player first. If that presentation has no playable scenes, the controller's
  unavailable state fills the same 16:9 frame.
- A lesson whose presentation could not be decoded or is from an unsupported
  future schema (`presentation == nil` and `hasUnsupportedPresentation ==
  true`) renders a stable 16:9 unavailable frame first, followed by the
  read-only persistence warning and usable lesson content.
- A legacy, custom, concept, or otherwise unauthored lesson with
  `presentation == nil` and `hasUnsupportedPresentation == false` renders no
  synthetic player. Its lesson title/objective becomes the first lesson
  content, and Deep Lesson/Modify actions remain available when authored.

This conditional behavior avoids pretending that unauthored content has a
video while keeping the player-first contract for every presentation-authored
lesson.

## Error Handling

- A decoded empty presentation or an unsupported/invalid authored
  presentation renders the stable unavailable player without preventing lesson
  practice. A normal unauthored lesson renders no player.
- An unavailable narration voice disables narration as it does today and never
  starts a fallback with the wrong locale.
- Persistence warnings appear below the title/path area and remain readable;
  they do not cover the player.
- A presentation save error leaves playback usable and displays the existing
  progress persistence warning.
- Transcript overflow stays inside its bounded region.
- Content that is too large for the scene visual adapts or internally scrolls;
  it does not change the outer player height.

## Testing Strategy

Implementation follows focused test-driven development. Tests should prove the
contract without duplicating unrelated milestone coverage.

### Pure and controller tests

- Preserve all `PresentationPlayerController` playback, narration
  cancellation, unavailable-locale, persistence, and replacement tests.
- Add a player-action containment seam only if needed to prove no player action
  emits document navigation or focus requests. Do not introduce production
  indirection solely for superficial test coverage.

### Hosted SwiftUI layout tests

At 680-by-520 and 1280-by-860:

- the lesson detail owns one bounded outer vertical scroll viewport;
- the player marker is above the title/path and practice markers;
- the player width fits the detail document and its height is 16:9 within
  layout tolerance;
- poster, resume, active, skipped, completed, unavailable, transcript-open, and
  narration-toggle states keep the same outer player frame;
- decoded empty, unsupported/invalid authored, and normal unauthored lesson
  categories render respectively an unavailable player, an unavailable player,
  and no synthetic player;
- the document is taller than the minimum viewport and can reach the practice
  workspace;
- no player or document content publishes horizontal overflow;
- the practice workspace retains wide and narrow responsive layouts;
- player controls remain within player bounds.

### Scroll and focus regression tests

Using the real hosted outer `NSScrollView` and production player actions:

- set a nonzero outer scroll offset, invoke each player action, settle layout,
  and assert the offset changes by no more than one point;
- assert the player frame remains unchanged after each action;
- assert focus remains on an invoked control that survives the state change;
  when Start, Skip, Replay, completion, or another transition replaces that
  control, assert focus moves to the documented logical replacement inside the
  player and never outside the player;
- verify wheel/trackpad-equivalent and keyboard scrolling remain enabled while
  the controller is playing/narrating;
- separately retain intentional navigation tests for course top and Recall.

### Accessibility and real-app verification

- Run existing accessibility representation and Reduce Motion tests.
- In the rebuilt app, traverse into and out of the player with keyboard and
  VoiceOver-oriented accessibility inspection.
- Play/narrate for at least 60 seconds while repeatedly scrolling with mouse or
  trackpad and keyboard.
- Exercise Play, Pause, Back, Next, Replay, Narration, Transcript, Skip, and
  Read Deeper, checking that only explicit Read Deeper opens a sheet.
- Confirm there is no separate Walkthrough control, external narrated banner,
  editor auto-typing narration, or second simultaneous narration path.
- Verify the player scrolls naturally out of view and never becomes sticky.
- Verify 680-by-520 and a larger window with poster, active, transcript, and
  completed states.

## Acceptance Criteria

- For every presentation-authored or unsupported-presentation lesson, the
  animated/unavailable player is the first lesson content after navigation and
  fills the available detail width inside 16-point outer gutters at an exact,
  stable 16:9 aspect ratio. A normal unauthored lesson shows no synthetic
  player and begins with its title/objective.
- The lesson title/objective, `Watch -> Recall -> Modify -> Practice/Run` path,
  learning checks, and coding workspace follow below in one outer vertical
  document.
- The player naturally scrolls away and never becomes sticky or floating.
- Every presentation state, including transcript-open, has the same outer
  player frame.
- Player and narration actions do not change the outer scroll offset by more
  than one point, move focus outside the player, open unrelated UI, resize the
  player, or disable manual scrolling. Focus stays on the invoked control when
  it survives and otherwise moves to a logical replacement inside the player.
- Narration remains fully offline, learner-controlled, cancellable, and scoped
  to presentation playback.
- The separate legacy narrated Walkthrough, editor auto-typing/locking path,
  and second narration owner no longer exist in the production UI or model.
- Captions, transcript, keyboard navigation, VoiceOver semantics, visible
  focus, and Reduce Motion behavior remain available.
- Existing lesson content, presentation progress, Recall, Modify, AI review,
  practice, completion, future-version preservation, and persistence behavior
  remain compatible.
- The responsive practice workspace remains usable at 680-by-520 and larger
  sizes.
- Focused tests, full `swift test`, `swift build`, and the protected real-app
  smoke path pass before completion is claimed.
