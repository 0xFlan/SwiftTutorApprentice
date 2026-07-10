# Course Platform, Animated Lessons, and Certification Tracks Design

Date: 2026-07-10

## Decision

Evolve SwiftTutor Apprentice into an offline-first learning platform with four
courses:

1. Swift Development
2. Web Development
3. Cybersecurity
4. Networking

Every course starts with no assumed experience and progresses through
orientation, foundations, application, mastery, projects, and certification
preparation. Course completion means repeated evidence of independent skill,
not merely viewing content or reaching the final lesson.

The implementation uses a foundation-first staged rollout. The first milestone
adds the shared course model, Course Home, course-scoped migration-safe
progress, stable lesson navigation, and an embedded offline animated player for
Swift Lessons 1-3. Later milestones fill the same platform with the complete
Swift, Web, Cybersecurity, and Networking curricula. This staging controls
implementation risk without reducing the approved final scope.

## Product Outcomes and Non-Negotiable Requirements

- Every app launch enters Course Home after the one-time welcome flow. It does
  not restore a lesson or an old scroll position as the root screen.
- Course Home makes Swift, Web, Cybersecurity, and Networking obvious and easy
  to switch between. One Start, Continue, or Review action is visually dominant.
- The first teaching element in each supported lesson is an actual offline
  animated or slideshow-style explanation embedded at the top of the lesson.
- A first visit expands a paused poster. Motion and narration begin only after
  the learner presses Start.
- The standard learning loop is Watch, Recall, Modify, Practice, Run, and later
  delayed retrieval. Passive viewing is never recorded as mastery.
- The existing written Deep Lesson remains available as an optional Read deeper
  surface. It no longer auto-opens once the embedded player exists.
- Swift Lessons 1-3 prove the player and navigation foundation before content
  production expands to every lesson and course.
- Existing Swift lesson IDs, custom lessons, saved code, completion, Deep
  Lesson events, and settings survive migration.
- The sidebar and main content must remain bounded, independently scrollable,
  keyboard navigable, and free of launch-time bottom scrolling or clipping.
- All core teaching, narration, execution, simulations, progress, and
  certification mapping work without an internet connection.
- Optional AI assistance may remain opt-in, but no course depends on a remote
  model or external account.
- Each course includes an Understand AI Code thread that teaches learners to
  inspect, explain, test, secure, and maintain AI-generated work.

## Considered Approaches

### Hard-code only the three-lesson animation pilot

This would ship the first player quickly, but would leave global integer lesson
IDs, global progress, and the single-course root in place. Web, Cybersecurity,
and Networking would then force a second migration and likely duplicate player
logic. Rejected because it makes the pilot disposable.

### Build every course and runtime simultaneously

This would attempt the full curricula, WebKit runner, network simulator,
security labs, navigation migration, review scheduler, and animated content in
one release. Rejected because independent migration, execution, content, and
accessibility failures would become difficult to isolate or verify.

### Foundation-first staged platform (selected)

Build stable identities, persistence, navigation, and the reusable player once;
prove them on Swift Lessons 1-3; then add complete course content and bounded
offline runtimes behind those interfaces. This preserves the full goal while
keeping each implementation milestone testable.

## Delivery Boundaries

This document fixes the program architecture and all course endpoints. The
first implementation plan produced from it covers Milestone 1 only. Subsequent
milestones receive bounded implementation/content plans that must conform to
the interfaces and acceptance criteria here.

### Milestone 1: Platform and animated Swift pilot

- Course identities, catalog, certification target summaries, and Course Home.
- Swift Development active; Web Development, Cybersecurity, and Networking
  visible as Coming next cards with their certification targets.
- Course-scoped progress schema and lossless legacy Swift migration.
- Stable Course Home to lesson navigation and the scroll/clipping regression
  fix.
- Reusable embedded presentation player and complete presentations for Swift
  Lessons 1-3.
- Only the objective IDs referenced by the released Swift pilot activities are
  activated; complete certification profiles and readiness remain disabled
  until their course release level becomes `certificationReady`.
- Recall, Modify, existing Practice/Run, captions, transcript, narration,
  Reduce Motion, keyboard, and VoiceOver support.
- The existing Deep Lesson becomes optional Read deeper content.
- Initial Understand AI Code exercises for Swift Lessons 1-3.

### Milestone 2: Complete Swift Development

- Complete zero-experience-to-certification curriculum for all current Swift
  lessons plus the additional advanced modules required below.
- Animated presentations, active exercises, cumulative reviews, projects,
  mock examinations, capstones, and objective coverage for the full course.
- No change to Swift's legacy local execution contract without a separately
  reviewed runner change.

### Milestone 3: Complete Web Development

- Multi-file HTML, CSS, and JavaScript workspace.
- Offline WebKit preview and deterministic validation.
- Complete curriculum, projects, certification objective coverage, mock exams,
  capstone, and Understand AI Code exercises.

### Milestone 4: Complete Cybersecurity

- Safe offline simulations and defensive labs only.
- Complete curriculum, certification objective coverage, mock exams, incident
  capstones, and AI/security review exercises.

### Milestone 5: Complete Networking

- Offline packet-flow, addressing, subnetting, topology, and troubleshooting
  simulations.
- Complete curriculum, certification objective coverage, mock exams,
  troubleshooting capstone, and AI-generated configuration review.

### Milestone 6: Cross-course mastery and Project X-Ray

- Transparent spaced retrieval across previously learned concepts.
- Scaffold fading based on demonstrated independent performance.
- Offline Project X-Ray for supported Swift and Web projects: file map, entry
  points, dependencies, data flow, deterministic checks, and guided
  explain-back questions.
- Project X-Ray performs static local analysis; it does not upload source or
  claim semantic certainty beyond its supported parsers and rules.

## Architecture and Data Boundaries

### Course identity and catalog

Introduce stable string-backed identifiers:

- `CourseID`: `swift-development`, `web-development`, `cybersecurity`, or
  `networking`.
- `LessonLocalID`: a course-local stable string. Existing Swift integer IDs
  bridge to their decimal strings (`1` through `24`, plus current custom lesson
  IDs) rather than being renumbered.
- `LessonKey`: the pair `(courseID, lessonLocalID)`. It is the only identity
  used by new navigation, presentation state, review state, and cross-course
  progress code.
- `ConceptID`: remains string-backed and becomes course-namespaced in bundled
  content, for example `swift.variables.mutation` or `networking.ipv4.subnet`.

`CourseDefinition` is immutable bundled metadata containing `id`, `title`,
`summary`, `icon`, `accent`, `availability`, certification target summaries,
release level, and the course runtime kind. `CourseCatalog` owns the four
definitions and exposes lookup and display order. It does not own modules,
lessons, learner progress, or mutable lesson workspace state.

`CourseAvailability` is `available`, `comingNext`, or `contentUnavailable`.
Milestone 1 marks only Swift Development available. A coming-next card can be
inspected but cannot enter an empty workspace.

`CourseReleaseLevel` is `pilot`, `inDevelopment`, or `certificationReady`.
Milestone 1 marks Swift as `pilot` even though its workspace is available.
Course Home therefore shows ordinary lesson completion for Swift, not a
certification-readiness percentage.

Course content resolves through a shared boundary:

```swift
protocol CourseContentProvider {
    var courseID: CourseID { get }
    var modules: [CourseModule] { get }
    func lessons(in moduleID: ModuleID) -> [CourseLesson]
    func lesson(for key: LessonKey) -> CourseLesson?
    func contains(_ key: LessonKey) -> Bool
}
```

`CourseLesson` pairs an explicit `LessonKey` with its `Lesson` value; consumers
never derive a key from the legacy integer `Lesson.id`. `CourseModule` owns a
stable module ID, title, instructional band, and ordered lesson local IDs. A
provider owns module and lesson ordering and must return only keys for its own
course. `CourseContentRegistry` maps available course IDs to providers and is
the only object navigation uses to resolve course content.
Milestone 1 supplies `LegacySwiftCourseProvider`, an adapter around the current
`LessonStore`. Later bundled providers conform to the same protocol; their
storage format and runtimes may differ without changing navigation.

A `comingNext` course intentionally has no registered provider. An `available`
course whose provider is absent or fails validation becomes
`contentUnavailable`, displays a recoverable local-content error, and cannot
open a partial workspace. This distinction prevents future course stores from
being confused with intentionally unreleased content.

### Certification mapping

`CertificationTargetSummary` contains only provider, credential name, optional
exam code, and source URL. Course Home uses these summaries for Coming next and
pilot courses; a summary does not activate readiness calculation or require a
complete objective set.

`CertificationProfile` contains:

- stable profile ID;
- provider and credential name;
- exam code when the provider publishes one;
- source URL;
- objective-set version or effective date;
- `lastReviewed` date;
- ordered domains and objectives;
- target milestone;
- readiness requirements.

Every assessable item declares one or more concept IDs and zero or more
certification objective IDs. A build-time validator always rejects duplicate
IDs, dangling mappings, invalid domain membership, and references to an
objective-set version not bundled for that course. For `pilot` and
`inDevelopment` courses it validates only the objective references present in
released content and reports uncovered objectives as development coverage, not
as a build failure. For `certificationReady` courses it additionally rejects
empty required domains and any objective without both teaching coverage and an
independent assessment. Changing a course to `certificationReady` is therefore
the explicit strict-validation gate.

Certification profiles are versioned content, not hard-coded marketing copy.
When a provider changes an exam, the app can retain the learner's concept
mastery while presenting the updated objective coverage separately. The app
shows the target exam version and last-reviewed date and never guarantees an
external exam result.

Current targets are:

- Swift Development: Certiport App Development with Swift Associate.
- Web Development: Pearson IT Specialist HTML and CSS, Pearson IT Specialist
  JavaScript, and the integrated HTML5 Application Development objectives.
- Cybersecurity: ISC2 Certified in Cybersecurity and Pearson IT Specialist
  Cybersecurity.
- Networking: Cisco CCST Networking and Pearson IT Specialist Networking.

### Curriculum progression

Every course has the same six instructional bands:

1. Orientation: tools, files, vocabulary, execution, and how to learn safely.
2. Foundations: one concept at a time with visual explanation and high support.
3. Application: combined concepts with partial scaffolding.
4. Mastery: unfamiliar problems, debugging, trade-offs, and reduced hints.
5. Projects: integrated work whose requirements allow multiple valid solutions.
6. Certification preparation: objective review, timed mock exams, practical
   capstone, remediation, and readiness report.

The app never skips Orientation based only on confidence. A learner may take a
diagnostic to shorten familiar material, but every skipped objective remains
available and must still be demonstrated in an assessment before readiness.

### Presentation content

Add optional `presentation: LessonPresentation?` to `Lesson`. It is separate
from `deepContent`, allowing the new visual player and the existing written
Deep Lesson to evolve independently. Older lesson JSON decodes with
`presentation == nil`.

`LessonPresentation` contains:

- schema version and bundled content revision;
- stable presentation ID and title;
- paused poster description and static poster state;
- three to six ordered `PresentationScene` values for the normal lesson
  presentation;
- complete transcript;
- narration locale and optional locally synthesized narration text;
- one linked recall prompt after the final scene;
- provenance and certification/concept mappings.

Each `PresentationScene` contains a stable ID, title, caption, narration,
static description, focus targets, before state, after state, and a typed visual
kind. Supported initial kinds are code execution, value binding, output flow,
branch choice, collection change, web render, packet journey, security event
timeline, and labeled diagram. Milestone 1 implements only the kinds required
by Swift Lessons 1-3, while the schema names every approved kind so later
courses do not require identity or persistence redesign.

Presentation validation requires unique scene IDs, nonempty captions and
static descriptions, a transcript covering every narration segment, valid
focus targets, and at least one meaningful state change. Decorative motion is
not a valid scene.

### Presentation progress

`LessonPresentationState` is keyed by `LessonKey` and stores:

- status: `notStarted`, `started`, `skipped`, or `completed`;
- last scene ID;
- presentation revision last opened;
- first-started and last-opened timestamps;
- replay count.

Auto-expanding the paused poster does not change status. Pressing Start changes
the state to `started`; intentional Skip changes it to `skipped`; completing
the final scene and recall handoff changes it to `completed`. A returning
lesson collapses the player after any of those intentional actions, with Replay
always available.

If a saved scene ID no longer exists, the player returns to the first scene and
preserves the prior intentional status. A revision change resets only the
resume position unless the bundled content explicitly declares a new
presentation ID. Existing `deepLessonViewed` events remain historical written
lesson activity and do not suppress first presentation of the new animation.
Legacy lesson completion also does not imply presentation activity: a completed
Swift Lesson 1-3 with no presentation state receives the same first-visit
paused poster as any other learner.

### Versioned progress migration

Progress schema version 3 contains a dictionary of course progress keyed by
`CourseID`. Each course record contains completed lesson local IDs, identified
stage events, presentation state, immutable assessment attempts, identified
review records, last lesson, and derived readiness snapshots. Concept mastery
and certification readiness are calculated from the identified attempts,
reviews, active objective set, and mastery policy version; they are not stored
as unversioned booleans.

Migration rules are deterministic:

- Legacy version 1 completion IDs become Swift Development completion IDs with
  decimal-string local IDs.
- Version 2 completion IDs and stage events move into the Swift Development
  record without changing timestamps, correctness, or idempotency meaning.
- Existing Deep Lesson, Modify, and Recall events are retained as their current
  event kinds.
- Existing lesson files remain at their current location during Milestone 1;
  `LessonStore` is the Swift course content store and gains a course adapter.
- The first successful post-migration mutation writes version 3 atomically.
  Loading alone does not rewrite the file.
- A file with a newer unsupported version is read-only and never overwritten,
  reset, or partially migrated.
- A failed atomic save retains in-memory work, preserves the prior file, and
  presents a recoverable local-save error.

Store initializers continue accepting injected file URLs and clocks for tests.
Schema decoding, migration, and serialization remain pure enough to test
without constructing SwiftUI views.

`LessonStore` applies the same fail-closed protection to `presentation` that it
already applies to unsupported Deep Lesson data. A saved lesson with a newer or
malformed non-null presentation schema keeps its other readable fields but
makes lesson persistence and editing read-only so the unknown presentation
bytes are never lost. Bundled presentation enrichment uses the current stable
ID, kind, and starter-code compatibility check and copies only the missing
presentation field.

### Workspace state

`AppModel` gains an explicit root route and course selection rather than using
the selected lesson as implicit app navigation:

- `AppRoute.courseHome`
- `AppRoute.course(CourseID)`

The route always initializes to Course Home on app launch. Each course may
remember its last meaningful `LessonKey` for the Continue action, but it does
not restore a root route or scroll offset. Switching courses cancels
walkthrough, narration, execution, presentation, and transient coach tasks
before changing the course.

Editor code, prediction, run result, AI response, and player UI state are keyed
or reset by `LessonKey`. A result from one lesson or course must never appear in
another.

## Course Home and Navigation

Course Home shows one card per course with title, concise purpose, target
credential, availability, private progress, and one Start, Continue, or Review
action.
In Milestone 1, progress is only released Swift lesson completion count over
released Swift lesson count. Coming next courses show no percentage, and no
card shows mastery or certification readiness until its course release level is
`certificationReady`. Course Home contains no leaderboard, public comparison,
XP economy, streak-loss mechanic, or claim that time spent proves learning.

Course-card labels and destinations follow one deterministic policy:

1. If the course has no completion, stage event, presentation action, submitted
   attempt, review result, or saved workspace edit, label the action Start and
   select the first lesson. Merely opening a course does not create meaningful
   activity.
2. If meaningful activity exists and the stored last lesson is valid and
   incomplete, label the action Continue and select it.
3. If the stored last lesson is valid and complete, select the first incomplete
   lesson after it in module/course order, wrapping once to the beginning.
4. If the stored key was deleted or is invalid, select the first incomplete
   lesson in course order.
5. If every released lesson is complete, label the action Review and select the
   valid stored last lesson, falling back to the first lesson.

A Home toolbar action always returns to Course Home. Returning Home clears
transient workspace presentation without erasing saved lesson work. Course
switching happens through Home; Milestone 1 does not add a second persistent
course switcher to the lesson sidebar.

## Stable Layout and Scroll Contract

The reported bottom-stuck and clipped layout is a release-blocking regression.
The stable contract is:

- Course Home and course workspace are separate root view identities.
- The course workspace retains `NavigationSplitView`, but its sidebar and
  detail each own bounded height and independent scrolling.
- The sidebar's lesson collection fills only the space above its fixed footer.
  The footer never participates in lesson scrolling.
- Sidebar rows use `LessonKey` identity. On course entry or programmatic
  selection, the selected row is scrolled into view once. Normal user scrolling
  is not continually overridden.
- The lesson detail establishes an explicit top anchor. Every `LessonKey`
  change creates a new detail scroll identity and scrolls that anchor to the
  top after the new lesson is mounted.
- No saved main-detail or sidebar pixel offset is restored at launch.
- Vertical scroll views are not nested around the entire `GeometryReader`,
  split view, editor, or run output. Panels that already need internal scrolling
  retain it within a bounded frame.
- Minimum window size remains 680 by 520. At narrow widths, the existing
  single-panel picker remains bounded and the selected panel begins at its own
  top.
- Selection changes cancel pending automatic presentation tasks from the old
  lesson, then update selection, transient workspace state, sidebar visibility,
  and detail top position in that order.
- Repeatedly choosing top, middle, and bottom lessons, using mouse and arrow
  keys, resizing, returning Home, and relaunching must never clip the course
  header, first lesson content, player, or sidebar rows.

## Embedded Animated Lesson Player

The player is the first element below lesson navigation and status. It is not a
sheet and does not replace the editor or practice workspace.

First visit behavior:

1. Expand the player with a static poster and Start, Skip, Transcript, and Read
   deeper actions.
2. Do not move, speak, or mark the presentation seen.
3. Start enters scene one and records `started`.
4. The learner controls Back, Next, Play/Pause, Replay, captions, and narration.
5. The final scene hands off to one prediction or causal recall prompt.
6. Continue moves to Modify and then the existing Practice/Run workspace.

Skip means skip this presentation, not skip the lesson. It records `skipped`,
collapses the player, suppresses automatic Resume for that presentation
revision, and moves keyboard focus to Recall. It does not answer Recall, pass
Modify, complete the lesson, or create mastery evidence. If the lesson has no
Recall surface, focus moves to the next available Modify or Practice surface.
Replay after a skip always starts scene one and changes status to `started`,
after which ordinary resume behavior is available again.

Returning visits show a compact completed, started, or skipped summary with
Replay. Resume is offered only for a started, incomplete presentation whose
saved scene still exists.

The player uses local SwiftUI drawing, transitions, timers, and macOS speech
synthesis. It bundles no prerecorded streaming media and makes no network
request. Captions are always available and remain synchronized with the
current scene rather than wall-clock audio timing.

If the requested local speech voice is unavailable, narration disables for that
session and the player continues with captions and transcript; it never
downloads a voice. Changing scene, lesson, course, route, or app activity
cancels the current narration and timer before starting any subsequent state.

Reduce Motion replaces interpolation and travel with immediate before/after
states. VoiceOver announces scene number, playback state, focused code/value,
and result. All controls are keyboard reachable, status never relies on color,
and every visual has an equivalent static description and transcript.

## Learning and Mastery Model

The common lesson spine is:

1. Watch a short meaningful presentation.
2. Recall or predict before revealing the result.
3. Investigate the actual execution or state change.
4. Complete a Parsons, partial-completion, or debugging bridge when useful.
5. Modify working material and explain the consequence.
6. Practice independently and run or validate the result.
7. Retrieve the concept later with a different cue.

Hints progress from a question, to a concept reminder, to a localized clue,
and only then to a worked explanation. The learner can always request help, but
using a revealed solution prevents that attempt from counting as independent
mastery.

`MasteryEvidence` records concept ID, activity kind, scaffold level, result,
timestamp, content revision, and whether the problem was previously seen.
Durable mastery requires independent success plus a later varied or delayed
success. Exact intervals remain transparent product policy rather than a claim
of scientifically optimal scheduling.

New assessment and review persistence uses stable identities:

- `ActivityID` identifies the authored exercise across revisions.
- `ItemVariantID` identifies the concrete prompt/input variant; replaying the
  same variant retains the same ID.
- `AttemptID` is created once when the learner submits a response and is reused
  for retries of the same persistence operation. Duplicate writes with the same
  attempt ID are ignored.
- `ObjectiveSetID` identifies the provider, credential, and effective objective
  version used by an assessment mapping.
- `MasteryPolicyVersion` identifies the transparent rules used to derive
  mastery and readiness.
- `ReviewID` identifies one scheduled concept review and optionally links to
  the attempt that satisfied it.

An immutable attempt record contains attempt ID, lesson key, activity ID, item
variant ID, concept IDs, objective IDs plus objective-set ID, scaffold level,
result, content revision, first-seen state, and submitted timestamp. A new
submission receives a new attempt ID even when it repeats an item. Repeating a
known variant is marked previously seen and cannot satisfy an unseen-transfer
requirement. The same attempt cannot count twice because derived mastery uses
unique attempt IDs.

Review records contain review ID, concept ID, creation and due timestamps,
policy version, source evidence IDs, and optional satisfying attempt ID.
Certification readiness is a derived `ReadinessSnapshot` containing objective
set ID, policy version, calculation timestamp, and the exact evidence IDs used;
it is recomputed when content, objective mappings, or policy versions change.
The persisted snapshot is explanatory cache data, not an authoritative boolean.

New version 3 stage events receive stable event IDs. Migrated version 1 and 2
events receive deterministic legacy IDs from their course, lesson, kind,
question ID when present, and retained first timestamp. This preserves existing
idempotency while allowing later evidence and review records to refer to a
specific event without inventing duplicates.

Certification readiness requires:

- coverage of every active objective;
- repeated independent concept evidence;
- passing cumulative and timed mock assessments on unseen item variants;
- required projects and a reduced-scaffold capstone;
- no unresolved prerequisite gaps;
- an objective-by-object readiness report.

Course completion and certification-ready status are separate. The product
uses wording such as Ready for the target exam based on in-app evidence and
never guarantees passing, employment, or professional licensure.

## Course Depth Requirements

### Swift Development

The course covers tool orientation, syntax, types, constants and variables,
operators, optionals, strings, collections, control flow, functions, closures,
structures, classes, value and reference semantics, protocols, extensions,
generics, error handling, memory concepts, concurrency, testing, debugging,
SwiftUI, state and data flow, navigation, persistence, accessibility, app
architecture, performance, privacy, security, packaging, and distribution.

Projects progress from console programs through reusable models to complete
SwiftUI applications. The capstone must be designed, implemented, tested,
debugged, made accessible, and explained with reduced scaffolding.

### Web Development

HTML covers document anatomy, semantics, links, media, tables, metadata, forms,
validation, accessibility, and maintainable structure. CSS covers cascade,
inheritance, specificity, units, box model, typography, color, responsive
design, Flexbox, Grid, positioning, states, transitions, animation, architecture,
and compatibility. JavaScript covers values, coercion, scope, control flow,
functions, closures, arrays, objects, modules, DOM, events, asynchronous work,
network APIs, errors, testing, debugging, performance, storage, accessibility,
and browser security.

After foundations, the course interleaves all three technologies through
integrated projects. The offline runtime uses a multi-file workspace with
`index.html`, `styles.css`, and `script.js`, renders in a contained WebKit
preview, and validates behavior and structure without requiring one exact
source solution.

The WebKit containment contract is strict:

- Use a nonpersistent website data store and an in-memory
  `swifttutor-preview://project/` scheme handler for normalized project paths.
- Do not grant `file://` access and do not expose arbitrary filesystem,
  process, shell, clipboard, credential, or network APIs to JavaScript.
- Inject a Content Security Policy with `connect-src 'none'`,
  `frame-src 'none'`, `object-src 'none'`, `base-uri 'none'`, and
  `form-action 'none'`; allow scripts, styles, images, fonts, and media only
  from the project origin or explicitly required inline/data/blob forms.
- Apply a WebKit content-rule list that blocks `http`, `https`, `ws`, and `wss`
  subresources even if authored markup attempts to bypass the policy.
- Navigation delegates allow only the project origin and `about:blank`, deny
  new windows and custom URL schemes, and show a local blocked-link message
  rather than opening an external destination automatically.
- A native bridge, if required for console capture or deterministic validation,
  accepts only versioned structured result messages. It exposes no command
  execution capability and is removed when the preview is torn down.
- Remote images, fonts, scripts, fetches, WebSockets, forms, and frames produce
  an offline-resource validation message while leaving source intact.

### Cybersecurity

The course covers computer and operating-system foundations, command-line
literacy, security principles and ethics, governance and risk, access control,
networking, cryptography and PKI, data handling, threats and vulnerabilities,
social engineering, secure configuration, endpoint protection, cloud concepts,
logging and monitoring, alert triage, incident response, business continuity,
disaster recovery, policy, privacy, compliance, secure coding, web security,
and AI-system security fundamentals.

Labs use bundled logs, diagrams, mock filesystems, permission models, packet
records, policy scenarios, and intentionally vulnerable code. They never scan
or attack public targets, create deployable malware, collect real credentials,
or require elevated host permissions. Offensive concepts are taught only to
support recognition, mitigation, and authorized defensive reasoning.

### Networking

The course covers device and terminal orientation, LAN/WAN topologies,
physical media, routers and switches, OSI and TCP/IP models, Ethernet, MAC
addressing, IPv4, IPv6, subnetting, routing, VLANs, NAT, DNS, DHCP, ports,
protocols, sockets, wireless, VPNs, firewalls, cloud and virtualization,
monitoring, documentation, support practice, security, and systematic
troubleshooting.

Offline simulations animate packet journeys, routing decisions, address
allocation, name resolution, segmentation, failures, and diagnostic evidence.
The capstone requires designing, documenting, securing, and troubleshooting a
small-business network from unfamiliar symptoms.

## Understand AI Code Thread

This thread appears throughout every applicable course rather than as a final
prompt-engineering chapter. Learners must practice how to:

- identify files, entry points, dependencies, state, data flow, and network
  boundaries in generated work;
- trace code and predict behavior before execution;
- compare an AI explanation with compiler, runtime, test, log, or packet
  evidence;
- detect nonexistent APIs, insecure defaults, exposed secrets, missing error
  handling, fragile assumptions, unnecessary dependencies, and excess
  complexity;
- inspect a diff and state exactly what changed;
- consult primary documentation and verify version compatibility;
- write tests that challenge generated claims;
- make and explain an independent modification;
- describe uncertainty and request appropriately scoped help.

AI may be used during designated capstones, but certification readiness also
requires a no-generation explain-back, defect repair, and independent-change
check. The app assesses demonstrated understanding, not whether AI was used.

## Error Handling, Privacy, and Safety

- Missing or invalid optional presentation content falls back to the written
  lesson and normal workspace; it never prevents the course from opening.
- Invalid bundled course or certification mappings fail validation during
  tests/build rather than silently shipping partial readiness coverage.
- Unsupported saved schema versions are read-only and preserved byte-for-byte.
- Save failures keep in-memory edits and expose Retry and Reveal File actions.
- Web preview crashes or invalid markup leave source intact and provide a
  reloadable error state.
- Simulation failures reset only the current simulation, not course progress.
- Local learning telemetry is private, inspectable, resettable, and excluded
  from certification mastery unless it represents an actual response or task.
- Playback completion, time watched, replay count, streaks, and accessibility
  settings are never treated as ability measures.
- Optional remote AI remains off by default. Core curricula never require an
  API key or send source, progress, or personal data to a service.

## Testing and Verification

### Automated model and migration tests

- Stable course, lesson, concept, presentation, scene, and objective IDs.
- Course catalog completeness and availability.
- Certification objective coverage and dangling-map rejection.
- Legacy progress v1 and v2 migration to Swift Development v3.
- Preservation of completions, timestamps, correctness, stage-event
  idempotency, custom lessons, and existing settings.
- No rewrite on load; atomic first mutation; read-only future schemas; save
  failure recovery.
- Presentation status transitions, revision changes, invalid resume scene,
  replay count, and auto-expand-without-marking behavior.
- Existing LessonStore enrichment protections for edited and custom lessons.

### Automated learning and runtime tests

- Player scene validation, transcript completeness, static alternatives, and
  concept/objective mappings.
- Activity, item-variant, attempt, event, objective-set, review, and policy
  identity uniqueness plus attempt-write idempotency.
- Recall, hint-level, independent mastery, delayed evidence, course completion,
  and certification readiness calculations.
- Web validation and preview navigation policy when that runtime ships.
- Cybersecurity/networking simulation determinism and containment when those
  runtimes ship.
- Project X-Ray parser limits and local-only behavior when that feature ships.

### UI and accessibility tests

- Every launch reaches Course Home after welcome.
- Course card Start/Continue, Home return, and unavailable-card behavior.
- Mouse and keyboard navigation through top, middle, and bottom lessons.
- Main detail resets to its top on every lesson change.
- Sidebar selected row remains visible without forcing later user scroll.
- Repeated lesson changes, course changes, window resize, narrow panel changes,
  relaunch, and first-visit player expansion do not clip or bottom-stick.
- Player Start, Skip, Back, Next, Pause, Replay, Resume, captions, transcript,
  narration, Reduce Motion, VoiceOver, and keyboard operation.
- Deep Lesson Read deeper, Recall, Modify, Practice/Run, and legacy custom
  lesson paths remain usable.

### Real app verification

Before any milestone is called complete:

1. Run the complete automated test suite and release build.
2. Build the signed app with `./Scripts/build-app.sh`.
3. Back up Application Support, workspace files, and app defaults.
4. Launch and smoke-test `dist/SwiftTutor Apprentice.app`, including migration
   fixtures and the user-reported scroll path.
5. Quit, relaunch, and confirm Course Home, progress, saved code, animation
   state, and scroll position behavior.
6. Restore the backed-up user data after destructive smoke scenarios.

Source tests or a bare SwiftPM executable are not sufficient proof that the app
the user opens is updated.

## Milestone 1 Acceptance Criteria

- Course Home opens on every normal launch and presents all four approved
  courses with accurate availability and certification targets.
- Milestone 1 cards show only released lesson completion and do not imply
  mastery or certification readiness.
- Swift Development opens through a Start/Continue action; returning Home and
  re-entering selects the correct lesson without restoring accidental scroll.
- Existing Swift lessons, custom lessons, saved edits, completion, Deep Lesson
  activity, settings, and workspace behavior survive version 3 migration.
- Swift Lessons 1-3 show a paused embedded presentation first, with three to
  six meaningful scenes, captions, transcript, narration, static alternative,
  Reduce Motion, keyboard, and VoiceOver support.
- Player expansion alone records nothing; Start, Skip, Resume, Complete, and
  Replay follow the specified persistence contract.
- The written Deep Lesson is reachable through Read deeper and does not
  auto-open.
- Watch hands off to Recall, Modify, and the existing Practice/Run workspace.
- Swift Lessons 1-3 include at least one Understand AI Code exercise each.
- Selecting the first, last, and first lesson repeatedly by mouse and keyboard,
  resizing at each step, and relaunching never clips content or leaves either
  navigation surface stuck at the bottom.
- All core behavior works with networking disabled.
- Automated tests, release build, and the real bundled-app smoke test pass.

## Program Completion Criteria

The approved program is complete only when all four courses are available and
each one:

- starts with no assumed experience;
- includes complete instruction and assessment for every declared topic and
  current mapped certification objective;
- uses the visual-to-active learning loop throughout;
- includes cumulative review, debugging, projects, mock exams, and a
  reduced-scaffold capstone;
- includes the Understand AI Code thread;
- produces an objective-level readiness report from repeated independent
  evidence;
- passes its content, runtime, accessibility, migration, and real-app smoke
  verification.

## Evidence Boundaries

The design follows the accompanying learning-optimization research brief.
Animation is used for meaningful processes and state change; segmenting,
signaling, retrieval, active practice, and scaffold fading shape the player and
lesson loop. Product hypotheses such as Course Home, first-visit expansion, and
the precise review schedule require local usability and learning validation.

The product must not claim that watching proves understanding, autoplay
improves learning, a learner has a fixed visual style, time or streaks equal
mastery, the selected Web sequence is universally optimal, or an external
certification or job outcome is guaranteed.
