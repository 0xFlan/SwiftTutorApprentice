# Course Platform Milestone 1 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a migration-safe Course Home and reusable offline animated lesson player for Swift Lessons 1-3 while fixing unstable lesson/sidebar scroll behavior and preserving every existing Swift learning path.

**Architecture:** Introduce stable course/lesson identities, a provider registry around the legacy Swift lesson store, and version 3 course-scoped progress before changing navigation. Route every launch to Course Home, then embed a state-driven presentation player above the existing workspace; existing Deep Lesson content becomes explicit Read deeper material. Keep the milestone bounded to Swift Lessons 1-3 while exposing truthful Coming next cards for Web Development, Cybersecurity, and Networking.

**Tech Stack:** Swift 5.9, SwiftUI on macOS 14, Foundation/Codable, AVFoundation speech synthesis, XCTest, Swift Package Manager, local JSON persistence.

**Required skills during execution:** `@test-driven-development` for every behavior change, `@systematic-debugging` for any regression or unexpected failure, `@subagent-driven-development` for task execution and two-stage review, `@computer-use:computer-use` for real macOS bundle smoke testing, and `@verification-before-completion` before any completion claim.

**Design reference:** `docs/superpowers/specs/2026-07-10-course-platform-animated-certification-tracks-design.md`

---

## Scope Guardrails

- This plan implements Milestone 1 only.
- Swift Development is the only available course. Web Development,
  Cybersecurity, and Networking are visible as Coming next.
- No WebKit runtime, security lab runtime, network simulator, spaced scheduler,
  full certification curriculum, or Project X-Ray implementation belongs in
  this plan.
- Existing custom lessons, integer Swift lesson IDs, Deep Lesson events,
  Modify/Recall activity, saved code behavior, and exact completion semantics
  remain compatible.
- The core app remains offline. Optional AI remains opt-in and is not required
  by the new AI-code-understanding exercises.

## Planned File Structure

### New model and service files

- `Sources/SwiftTutorApprentice/Models/CourseIdentity.swift` — stable
  `CourseID`, `LessonLocalID`, `LessonKey`, `ModuleID`, and `CourseLesson`.
- `Sources/SwiftTutorApprentice/Models/CourseDefinition.swift` — course card
  metadata, release/availability/runtime enums, and certification summaries.
- `Sources/SwiftTutorApprentice/Models/LearningEvidence.swift` — stable event,
  activity, variant, attempt, review, objective-set, and policy identities.
- `Sources/SwiftTutorApprentice/Models/ProgressDocument.swift` — version 3
  course-scoped persistence DTOs and presentation state.
- `Sources/SwiftTutorApprentice/Models/LessonPresentation.swift` — versioned
  presentation, scenes, visual states, and offline AI-code review exercise.
- `Sources/SwiftTutorApprentice/Models/SwiftPilotPresentationContent.swift` —
  bundled presentation and AI-code-review content for Swift Lessons 1-3.
- `Sources/SwiftTutorApprentice/Models/CourseHomeCardModel.swift` — truthful
  display projection for available and Coming next course cards.
- `Sources/SwiftTutorApprentice/Services/CourseCatalog.swift` — four immutable
  course definitions and target summaries.
- `Sources/SwiftTutorApprentice/Services/CourseContentRegistry.swift` — common
  provider protocol, explicit content errors, and provider lookup.
- `Sources/SwiftTutorApprentice/Services/LegacySwiftCourseProvider.swift` —
  adapter from `LessonStore` to explicit `LessonKey` values.
- `Sources/SwiftTutorApprentice/Services/CourseDestinationResolver.swift` —
  deterministic Start/Continue/Review destination policy.
- `Sources/SwiftTutorApprentice/Services/ProgressMigration.swift` — pure v1/v2
  to v3 migration and deterministic legacy event IDs.
- `Sources/SwiftTutorApprentice/Services/PresentationContentValidator.swift` —
  pilot/release-aware content validation.
- `Sources/SwiftTutorApprentice/Services/PresentationPlayerStateMachine.swift`
  — pure presentation entry and progress transitions.
- `Sources/SwiftTutorApprentice/Services/PresentationPlayerController.swift` —
  cancellable playback, narration, and view-facing presentation state.
- `Sources/SwiftTutorApprentice/Services/AICodeReviewEvaluator.swift` — pure
  evaluation for local AI-code-understanding exercises.
- `Sources/SwiftTutorApprentice/Services/LessonScrollCoordinator.swift` —
  one-shot sidebar visibility and detail-top requests without saved offsets.
- `Sources/SwiftTutorApprentice/Services/LessonWorkspaceSession.swift` —
  reference-owned player and learning-sheet lifecycle for route cancellation.

### New views

- `Sources/SwiftTutorApprentice/Views/CourseHomeView.swift` — four-course
  orientation surface with one dominant action per card.
- `Sources/SwiftTutorApprentice/Views/CourseWorkspaceView.swift` — course-level
  `NavigationSplitView` shell and Home action.
- `Sources/SwiftTutorApprentice/Views/LessonPresentationPlayer.swift` — poster,
  controls, captions, transcript, and progress handoff.
- `Sources/SwiftTutorApprentice/Views/PresentationSceneVisual.swift` — meaningful
  static/animated Swift scene rendering.
- `Sources/SwiftTutorApprentice/Views/AICodeReviewView.swift` — offline trace,
  verification, and repair exercise.
- `Sources/SwiftTutorApprentice/Views/LessonRecallView.swift` — linked Recall
  prompt and evidence handoff outside the optional written Deep Lesson.

### Existing files to modify

- `Sources/SwiftTutorApprentice/Models/Lesson.swift:27-148` — optional
  presentation decoding and fail-closed unsupported-schema state.
- `Sources/SwiftTutorApprentice/Services/LessonStore.swift:18-244` — compatible
  bundled presentation enrichment and read-only preservation.
- `Sources/SwiftTutorApprentice/Services/ProgressStore.swift:20-305` — v3
  storage, migration, course-keyed APIs, compatibility adapters, and save
  errors.
- `Sources/SwiftTutorApprentice/AppModel.swift:24-328` — explicit root route,
  selected course/key, destination resolution, and task cancellation.
- `Sources/SwiftTutorApprentice/ContentView.swift:18-84` — Course Home root and
  separate course workspace route.
- `Sources/SwiftTutorApprentice/Views/LessonListSidebar.swift:10-116` — stable
  `LessonKey` selection, bounded list/footer, and one-time visibility scroll.
- `Sources/SwiftTutorApprentice/Views/LessonWorkspace.swift:13-501` — embedded
  player, stable identity, Read deeper sheet, Recall/Modify handoff, and removal
  of automatic Deep Lesson sheets.
- `Sources/SwiftTutorApprentice/Views/LessonStageStepper.swift:10-148` — Watch,
  Recall, Modify, Practice labels and compact layout.
- `Sources/SwiftTutorApprentice/Services/NarrationSpeaker.swift:18-68` — local
  voice availability and deterministic cancellation.
- `Sources/SwiftTutorApprentice/Views/WelcomeView.swift:20-84` — zero-experience
  course orientation and Course Home handoff.
- `README.md` — shipped Milestone 1 behavior after verification.

### New and modified tests

- Create focused tests named in each task below under
  `Tests/SwiftTutorApprenticeTests/`.
- Modify `LessonCompatibilityTests.swift`, `LessonStoreMigrationTests.swift`,
  `ProgressStoreMigrationTests.swift`, `DeepLessonPilotContentTests.swift`, and
  `LessonStageStepperLayoutTests.swift` only where their existing contracts
  intentionally advance.
- Add `Tests/SwiftTutorApprenticeTests/Fixtures/version-2-progress.json`,
  `version-3-progress.json`, and `future-presentation-lessons.json` as literal
  legacy/current/future fixtures.

## Chunk 1: Course Identity, Content, and Persistence Foundation

### Task 1: Add stable course identities and truthful catalog metadata

**Files:**
- Create: `Sources/SwiftTutorApprentice/Models/CourseIdentity.swift`
- Create: `Sources/SwiftTutorApprentice/Models/CourseDefinition.swift`
- Create: `Sources/SwiftTutorApprentice/Services/CourseCatalog.swift`
- Test: `Tests/SwiftTutorApprenticeTests/CourseIdentityTests.swift`
- Test: `Tests/SwiftTutorApprenticeTests/CourseCatalogTests.swift`

- [ ] **Step 1: Write failing tests for stable course and lesson identities**

```swift
import XCTest
@testable import SwiftTutorApprentice

final class CourseIdentityTests: XCTestCase {
    func testSwiftIntegerLessonIDBridgesWithoutRenumbering() {
        XCTAssertEqual(LessonKey.swift(24).courseID, .swiftDevelopment)
        XCTAssertEqual(LessonKey.swift(24).localID.rawValue, "24")
        XCTAssertEqual(LessonKey.swift(24).id, "swift-development:24")
    }

    func testObjectiveSetIDIsAvailableToCourseDefinitions() {
        XCTAssertEqual(
            ObjectiveSetID(rawValue: "certiport-swift-associate-2024").rawValue,
            "certiport-swift-associate-2024"
        )
    }
}
```

- [ ] **Step 2: Run the identity tests and verify the missing-type failure**

Run: `swift test --filter CourseIdentityTests`

Expected: FAIL at compile time with `cannot find 'LessonKey' in scope`.

- [ ] **Step 3: Implement only the stable identity wrappers**

Create `CourseIdentity.swift`. `ObjectiveSetID` lives here so
`CourseDefinition` can compile before the broader evidence models exist.

```swift
struct CourseID: RawRepresentable, Hashable, Codable, Identifiable {
    let rawValue: String
    var id: String { rawValue }
    static let swiftDevelopment = Self(rawValue: "swift-development")
    static let webDevelopment = Self(rawValue: "web-development")
    static let cybersecurity = Self(rawValue: "cybersecurity")
    static let networking = Self(rawValue: "networking")
}

struct LessonLocalID: RawRepresentable, Hashable, Codable {
    let rawValue: String
}

struct LessonKey: Hashable, Codable, Identifiable {
    let courseID: CourseID
    let localID: LessonLocalID
    var id: String { "\(courseID.rawValue):\(localID.rawValue)" }
    static func swift(_ legacyID: Int) -> Self {
        Self(courseID: .swiftDevelopment,
             localID: LessonLocalID(rawValue: String(legacyID)))
    }
}

struct ModuleID: RawRepresentable, Hashable, Codable, Identifiable {
    let rawValue: String
    var id: String { rawValue }
}

struct ObjectiveSetID: RawRepresentable, Hashable, Codable {
    let rawValue: String
}

struct CourseLesson: Identifiable {
    let key: LessonKey
    let lesson: Lesson
    var id: LessonKey { key }
}
```

- [ ] **Step 4: Run the identity tests until they pass**

Run: `swift test --filter CourseIdentityTests`

Expected: 2 tests PASS.

- [ ] **Step 5: Write the failing catalog metadata tests**

```swift
final class CourseCatalogTests: XCTestCase {
    func testDefaultCatalogUsesFourStableOrderedCourseIDs() {
        XCTAssertEqual(
            CourseCatalog.default.definitions.map(\.id.rawValue),
            ["swift-development", "web-development", "cybersecurity", "networking"]
        )
    }

    func testOnlySwiftIsAvailableAndItIsStillAPilot() throws {
        let swift = try XCTUnwrap(CourseCatalog.default[.swiftDevelopment])
        XCTAssertEqual(swift.availability, .available)
        XCTAssertEqual(swift.releaseLevel, .pilot)
        XCTAssertEqual(swift.runtimeKind, .swiftConsole)
        XCTAssertNil(swift.activeObjectiveSetID)
        for id in [CourseID.webDevelopment, .cybersecurity, .networking] {
            XCTAssertEqual(CourseCatalog.default[id]?.availability, .comingNext)
            XCTAssertNil(CourseCatalog.default[id]?.activeObjectiveSetID)
        }
    }

    func testEveryCourseUsesExactApprovedCertificationTargetMetadata() {
        let actual = Dictionary(uniqueKeysWithValues:
            CourseCatalog.default.definitions.map { definition in
                (definition.id, definition.certificationTargets.map {
                    "\($0.provider)|\($0.credentialName)|\($0.sourceURL.absoluteString)"
                })
            }
        )
        XCTAssertEqual(actual[.swiftDevelopment], [
            "Certiport|App Development with Swift Associate|https://certiport.pearsonvue.com/Educator-resources/Exam-details/Objective-domains/App-Development-with-Swift-Objective-Domain-Crossw.pdf"
        ])
        XCTAssertEqual(actual[.webDevelopment], [
            "Pearson|IT Specialist HTML and CSS|https://www.pearsonvue.com/us/en/it-exam-resources/it-specialist.html",
            "Pearson|IT Specialist JavaScript|https://www.pearsonvue.com/us/en/it-exam-resources/it-specialist.html",
            "Pearson|IT Specialist HTML5 Application Development|https://www.pearsonvue.com/content/dam/VUE/vue/en/documents/clients/it-specialist/its-od-306-html-app-develop-pearson.pdf"
        ])
        XCTAssertEqual(actual[.cybersecurity], [
            "ISC2|Certified in Cybersecurity (CC)|https://www.isc2.org/Certifications/CC",
            "Pearson|IT Specialist Cybersecurity|https://www.pearsonvue.com/content/dam/VUE/vue/en/documents/clients/it-specialist/its-od-105-cybersecurity-pearson.pdf"
        ])
        XCTAssertEqual(actual[.networking], [
            "Cisco|Cisco Certified Support Technician (CCST) Networking|https://www-cloud.cisco.com/site/us/en/learn/training-certifications/exams/ccst-networking.html",
            "Pearson|IT Specialist Networking|https://www.pearsonvue.com/content/dam/VUE/vue/en/documents/clients/it-specialist/its-od-101-networking-pearson.pdf"
        ])
    }
}
```

- [ ] **Step 6: Run the catalog tests and verify only catalog symbols are missing**

Run: `swift test --filter CourseCatalogTests`

Expected: FAIL with `cannot find 'CourseCatalog' in scope`; identity tests
still compile.

- [ ] **Step 7: Implement immutable course-definition types**

Keep card colors as semantic names rather than persisted `Color` values.

```swift
enum CourseAvailability: String, Codable { case available, comingNext, contentUnavailable }
enum CourseReleaseLevel: String, Codable { case pilot, inDevelopment, certificationReady }
enum CourseRuntimeKind: String, Codable { case swiftConsole, webPreview, securitySimulation, networkSimulation }

struct CertificationTargetSummary: Hashable, Codable, Identifiable {
    let id: String
    let provider: String
    let credentialName: String
    let examCode: String?
    let sourceURL: URL
}

struct CourseDefinition: Identifiable, Hashable {
    let id: CourseID
    let title: String
    let summary: String
    let symbolName: String
    let accentName: String
    let availability: CourseAvailability
    let releaseLevel: CourseReleaseLevel
    let runtimeKind: CourseRuntimeKind
    let certificationTargets: [CertificationTargetSummary]
    let activeObjectiveSetID: ObjectiveSetID?
}
```

- [ ] **Step 8: Implement `CourseCatalog.default` with the exact tested constants**

Use the exact providers, names, ordering, and URLs asserted above. Swift is
`.available`/`.pilot`; the other three are `.comingNext`/`.inDevelopment`.
Every `activeObjectiveSetID` is `nil` in Milestone 1, so target summaries do not
activate readiness validation.

- [ ] **Step 9: Run identity, catalog, and full tests**

Run: `swift test --filter CourseIdentityTests && swift test --filter CourseCatalogTests && swift test`

Expected: all focused tests PASS; the full suite reports at least 79 tests with
0 failures (74 baseline plus the 5 tests added here).

- [ ] **Step 10: Commit the course identity boundary**

```bash
git add Sources/SwiftTutorApprentice/Models/CourseIdentity.swift \
  Sources/SwiftTutorApprentice/Models/CourseDefinition.swift \
  Sources/SwiftTutorApprentice/Services/CourseCatalog.swift \
  Tests/SwiftTutorApprenticeTests/CourseIdentityTests.swift \
  Tests/SwiftTutorApprenticeTests/CourseCatalogTests.swift
git commit -m "feat: add stable course catalog"
```

### Task 2: Add the shared content-provider boundary and Swift adapter

**Files:**
- Create: `Sources/SwiftTutorApprentice/Services/CourseContentRegistry.swift`
- Create: `Sources/SwiftTutorApprentice/Services/LegacySwiftCourseProvider.swift`
- Test: `Tests/SwiftTutorApprenticeTests/CourseContentRegistryTests.swift`

- [ ] **Step 1: Write failing tests for explicit key/value pairing and availability errors**

```swift
final class CourseContentRegistryTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CourseContentRegistryTests-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
    }

    private func makeSwiftProvider() -> LegacySwiftCourseProvider {
        let url = temporaryDirectory.appendingPathComponent("lessons.json")
        let store = LessonStore(
            fileURL: url,
            defaults: Array(Curriculum.defaultLessons.prefix(3))
        )
        return LegacySwiftCourseProvider(store: store)
    }

    func testSwiftProviderReturnsExplicitKeysForLegacyLessons() throws {
        let provider = makeSwiftProvider()

        XCTAssertEqual(provider.modules.map(\.id.rawValue), ["swift-current"])
        XCTAssertEqual(provider.lessons(in: provider.modules[0].id).map(\.key),
                       [.swift(1), .swift(2), .swift(3)])
        XCTAssertEqual(try XCTUnwrap(provider.lesson(for: .swift(2))).lesson.id, 2)
    }

    func testRegistryDistinguishesComingNextFromMissingAvailableContent() {
        let registry = CourseContentRegistry(providers: [:])
        XCTAssertThrowsError(try registry.provider(for: .webDevelopment)) {
            XCTAssertEqual($0 as? CourseContentError, .comingNext(.webDevelopment))
        }
        XCTAssertThrowsError(try registry.provider(for: .swiftDevelopment)) {
            XCTAssertEqual($0 as? CourseContentError, .contentUnavailable(.swiftDevelopment))
        }
    }

    func testProviderRejectsKeysFromAnotherCourse() {
        let provider = makeSwiftProvider()
        let foreign = LessonKey(courseID: .networking,
                                localID: LessonLocalID(rawValue: "1"))
        XCTAssertNil(provider.lesson(for: foreign))
    }
}
```

- [ ] **Step 2: Run and confirm the missing provider types fail compilation**

Run: `swift test --filter CourseContentRegistryTests`

Expected: FAIL with missing `LegacySwiftCourseProvider` and
`CourseContentRegistry`.

- [ ] **Step 3: Implement the module, provider protocol, and error contracts**

```swift
enum InstructionalBand: String, Codable {
    case orientation, foundations, application, mastery, projects, certificationPreparation
}

struct CourseModule: Identifiable, Hashable {
    let id: ModuleID
    let title: String
    let band: InstructionalBand
    let orderedLessonLocalIDs: [LessonLocalID]
}

protocol CourseContentProvider {
    var courseID: CourseID { get }
    var modules: [CourseModule] { get }
    func lessons(in moduleID: ModuleID) -> [CourseLesson]
    func lesson(for key: LessonKey) -> CourseLesson?
    func contains(_ key: LessonKey) -> Bool
}

enum CourseContentError: Error, Equatable {
    case unknownCourse(CourseID)
    case comingNext(CourseID)
    case contentUnavailable(CourseID)
}
```

- [ ] **Step 4: Implement `LegacySwiftCourseProvider`**

It creates one `swift-current` module in Milestone 1,
maps every current `Lesson.id` through `LessonKey.swift(_:)`, and never asks a
consumer to derive the key. Foreign course keys return `nil`.

- [ ] **Step 5: Implement `CourseContentRegistry`**

`provider(for:)` consults `CourseCatalog` to distinguish unknown, Coming next,
and missing available content before returning a registered provider.

- [ ] **Step 6: Run the provider/registry tests**

Run: `swift test --filter CourseContentRegistryTests`

Expected: all provider and error-boundary tests PASS.

- [ ] **Step 7: Run the migration-sensitive lesson tests**

Run: `swift test --filter LessonStoreMigrationTests`

Expected: all existing lesson migration tests PASS.

- [ ] **Step 8: Commit the provider boundary**

```bash
git add Sources/SwiftTutorApprentice/Services/CourseContentRegistry.swift \
  Sources/SwiftTutorApprentice/Services/LegacySwiftCourseProvider.swift \
  Tests/SwiftTutorApprenticeTests/CourseContentRegistryTests.swift
git commit -m "feat: add course content provider registry"
```

### Task 3: Implement deterministic Start, Continue, and Review destinations

**Files:**
- Create: `Sources/SwiftTutorApprentice/Services/CourseDestinationResolver.swift`
- Test: `Tests/SwiftTutorApprenticeTests/CourseDestinationResolverTests.swift`

- [ ] **Step 1: Write the complete resolver decision-table tests**

```swift
final class CourseDestinationResolverTests: XCTestCase {
    private let ordered: [LessonKey] = [.swift(1), .swift(2), .swift(3)]

    private func resolve(
        completed: Set<LessonKey>,
        last: LessonKey?
    ) -> CourseDestination {
        CourseDestinationResolver.resolve(
            orderedLessons: ordered,
            completed: completed,
            lastLesson: last,
            hasMeaningfulActivity: true
        )!
    }

    func testNoMeaningfulActivityStartsAtFirstLesson() {
        let result = CourseDestinationResolver.resolve(
            orderedLessons: ordered,
            completed: [],
            lastLesson: .swift(3),
            hasMeaningfulActivity: false
        )
        XCTAssertEqual(result, CourseDestination(label: .start, lessonKey: .swift(1)))
    }

    func testIncompleteLastLessonContinuesThere() {
        let result = resolve(completed: [.swift(1)], last: .swift(2))
        XCTAssertEqual(result, CourseDestination(label: .continue, lessonKey: .swift(2)))
    }

    func testCompletedLastLessonAdvancesAndWrapsToFirstIncomplete() {
        XCTAssertEqual(resolve(completed: [.swift(2)], last: .swift(2)).lessonKey, .swift(3))
        XCTAssertEqual(resolve(completed: [.swift(2), .swift(3)], last: .swift(3)).lessonKey, .swift(1))
    }

    func testInvalidLastLessonFallsBackToFirstIncomplete() {
        let invalid = LessonKey.swift(999)
        XCTAssertEqual(resolve(completed: [.swift(1)], last: invalid).lessonKey, .swift(2))
    }

    func testAllReleasedLessonsCompleteReturnsReview() {
        let result = resolve(completed: Set(ordered), last: .swift(2))
        XCTAssertEqual(result, CourseDestination(label: .review, lessonKey: .swift(2)))
    }
}
```

Include a test for an empty released lesson list returning `nil` rather than
inventing a key.

- [ ] **Step 2: Run the resolver tests and verify the missing symbol failure**

Run: `swift test --filter CourseDestinationResolverTests`

Expected: FAIL with missing `CourseDestinationResolver`.

- [ ] **Step 3: Implement one pure resolver with no store or UI dependency**

```swift
enum CourseActionLabel: String, Equatable { case start = "Start", `continue` = "Continue", review = "Review" }

struct CourseDestination: Equatable {
    let label: CourseActionLabel
    let lessonKey: LessonKey
}

enum CourseDestinationResolver {
    static func resolve(
        orderedLessons: [LessonKey],
        completed: Set<LessonKey>,
        lastLesson: LessonKey?,
        hasMeaningfulActivity: Bool
    ) -> CourseDestination? {
        guard let first = orderedLessons.first else { return nil }
        guard hasMeaningfulActivity else {
            return CourseDestination(label: .start, lessonKey: first)
        }
        let incomplete = orderedLessons.filter { !completed.contains($0) }
        guard !incomplete.isEmpty else {
            let validLast = lastLesson.flatMap { orderedLessons.contains($0) ? $0 : nil }
            return CourseDestination(label: .review, lessonKey: validLast ?? first)
        }
        guard let last = lastLesson,
              let lastIndex = orderedLessons.firstIndex(of: last)
        else {
            return CourseDestination(label: .continue, lessonKey: incomplete[0])
        }
        if !completed.contains(last) {
            return CourseDestination(label: .continue, lessonKey: last)
        }
        let rotated = Array(orderedLessons[(lastIndex + 1)...]) + Array(orderedLessons[..<lastIndex])
        return CourseDestination(
            label: .continue,
            lessonKey: rotated.first(where: { !completed.contains($0) }) ?? incomplete[0]
        )
    }
}
```

Avoid persisting the label; derive it from current progress every time.

- [ ] **Step 4: Run the complete resolver tests**

Run: `swift test --filter CourseDestinationResolverTests`

Expected: all decision-table tests PASS.

- [ ] **Step 5: Commit the destination policy**

```bash
git add Sources/SwiftTutorApprentice/Services/CourseDestinationResolver.swift \
  Tests/SwiftTutorApprenticeTests/CourseDestinationResolverTests.swift
git commit -m "feat: resolve course continuation deterministically"
```

### Task 4: Define version 3 progress identities and document shape

**Files:**
- Create: `Sources/SwiftTutorApprentice/Models/LearningEvidence.swift`
- Create: `Sources/SwiftTutorApprentice/Models/ProgressDocument.swift`
- Create: `Tests/SwiftTutorApprenticeTests/Fixtures/version-3-progress.json`
- Test: `Tests/SwiftTutorApprenticeTests/ProgressDocumentTests.swift`

- [ ] **Step 1: Write failing identity, stage-event, and presentation-state tests**

```swift
final class ProgressDocumentTests: XCTestCase {
    func testStableEvidenceIDsRoundTripTheirRawValues() throws {
        let ids = [
            ProgressEventID(rawValue: "event-1").rawValue,
            ActivityID(rawValue: "activity-1").rawValue,
            ItemVariantID(rawValue: "variant-1").rawValue,
            AttemptID(rawValue: "attempt-1").rawValue,
            ObjectiveID(rawValue: "objective-1").rawValue,
            ReviewID(rawValue: "review-1").rawValue,
            MasteryPolicyVersion(rawValue: "policy-1").rawValue
        ]
        XCTAssertEqual(ids, ["event-1", "activity-1", "variant-1",
                             "attempt-1", "objective-1", "review-1", "policy-1"])
    }

    func testCourseStageEventRoundTripsAllIdentityAndRecallFields() throws {
        let event = CourseStageEvent(
            id: ProgressEventID(rawValue: "event-1"),
            lessonLocalID: LessonLocalID(rawValue: "1"),
            kind: .recallAnswered,
            timestamp: Date(timeIntervalSince1970: 100),
            questionID: "recall-1",
            wasCorrect: false
        )
        let data = try JSONEncoder().encode(event)
        XCTAssertEqual(try JSONDecoder().decode(CourseStageEvent.self, from: data), event)
    }

    func testPresentationStateUsesIntentionalStatusNotAViewedBoolean() {
        let state = LessonPresentationState(status: .notStarted,
                                            lastSceneID: nil,
                                            presentationRevision: 1,
                                            firstStartedAt: nil,
                                            lastOpenedAt: nil,
                                            replayCount: 0)
        XCTAssertEqual(state.status, .notStarted)
    }
}
```

- [ ] **Step 2: Run and confirm the evidence identities are missing**

Run: `swift test --filter ProgressDocumentTests`

Expected: FAIL at compile time for missing `ProgressEventID`.

- [ ] **Step 3: Implement only evidence ID wrappers, stage events, and presentation state**

In `LearningEvidence.swift`, declare string-backed, `Hashable`, `Codable`
wrappers for `ProgressEventID`, `ActivityID`, `ItemVariantID`, `AttemptID`,
`ObjectiveID`, `ReviewID`, and `MasteryPolicyVersion`. Reuse the existing
string-backed `ConceptID` in `LessonDeepContent.swift` and the
`ObjectiveSetID` created in Task 1; do not redefine either type.

```swift
enum CourseStageEventKind: String, Codable {
    case deepLessonViewed, modifyPassed, recallAnswered
}

struct CourseStageEvent: Codable, Equatable {
    let id: ProgressEventID
    let lessonLocalID: LessonLocalID
    let kind: CourseStageEventKind
    let timestamp: Date
    let questionID: String?
    let wasCorrect: Bool?
}

enum PresentationStatus: String, Codable { case notStarted, started, skipped, completed }

struct LessonPresentationState: Codable, Equatable {
    var status: PresentationStatus
    var lastSceneID: String?
    var presentationRevision: Int
    var firstStartedAt: Date?
    var lastOpenedAt: Date?
    var replayCount: Int
}
```

- [ ] **Step 4: Run the first progress-model tests until they pass**

Run: `swift test --filter ProgressDocumentTests`

Expected: the identity, stage-event, and presentation-state tests PASS.

- [ ] **Step 5: Add failing attempt, review, readiness, and document round-trip tests**

Append a test that creates this exact object graph and asserts encoded/decoded
equality:

```swift
let mapping = ObjectiveMapping(
    conceptID: ConceptID(rawValue: "swift.lesson-1.string-literal"),
    objectiveSetID: ObjectiveSetID(rawValue: "swift-associate-2024"),
    objectiveID: ObjectiveID(rawValue: "3.1")
)
let attempt = AssessmentAttempt(
    id: AttemptID(rawValue: "attempt-1"),
    lessonKey: .swift(1),
    activityID: ActivityID(rawValue: "swift.lesson-1.ai-review"),
    itemVariantID: ItemVariantID(rawValue: "v1"),
    conceptIDs: [ConceptID(rawValue: "swift.lesson-1.string-literal")],
    objectiveMappings: [mapping],
    scaffoldLevel: .none,
    result: .passed,
    contentRevision: 1,
    wasPreviouslySeen: false,
    submittedAt: Date(timeIntervalSince1970: 100)
)
let review = ReviewRecord(
    id: ReviewID(rawValue: "review-1"),
    conceptID: ConceptID(rawValue: "swift.lesson-1.string-literal"),
    createdAt: Date(timeIntervalSince1970: 200),
    dueAt: Date(timeIntervalSince1970: 300),
    policyVersion: MasteryPolicyVersion(rawValue: "policy-1"),
    sourceEvidenceAttemptIDs: [attempt.id],
    satisfyingAttemptID: attempt.id
)
let snapshot = ReadinessSnapshot(
    objectiveSetID: mapping.objectiveSetID,
    policyVersion: MasteryPolicyVersion(rawValue: "policy-1"),
    calculatedAt: Date(timeIntervalSince1970: 400),
    evidenceAttemptIDs: [attempt.id]
)
let course = CourseProgressDocument(
    completedLessonLocalIDs: [LessonLocalID(rawValue: "1")],
    stageEvents: [],
    presentationStates: [:],
    assessmentAttempts: [attempt],
    reviews: [review],
    lastLessonLocalID: LessonLocalID(rawValue: "1"),
    readinessSnapshots: [snapshot]
)
let original = ProgressDocument(version: 3, courses: [.swiftDevelopment: course])
let encoder = JSONEncoder()
let decoder = JSONDecoder()
let data = try encoder.encode(original)
XCTAssertEqual(try decoder.decode(ProgressDocument.self, from: data), original)
```

- [ ] **Step 6: Run and verify only the higher-level DTOs are missing**

Run: `swift test --filter ProgressDocumentTests`

Expected: FAIL for missing `AssessmentAttempt`, while the tests from Step 1
still compile.

- [ ] **Step 7: Implement objective mappings, attempt enums, and `AssessmentAttempt`**

```swift
struct ObjectiveMapping: Codable, Equatable, Hashable {
    let conceptID: ConceptID
    let objectiveSetID: ObjectiveSetID
    let objectiveID: ObjectiveID
}

enum ScaffoldLevel: String, Codable { case none, prompt, conceptReminder, localizedClue, workedExplanation }
enum AttemptResult: String, Codable { case passed, failed }

struct AssessmentAttempt: Codable, Equatable {
    let id: AttemptID
    let lessonKey: LessonKey
    let activityID: ActivityID
    let itemVariantID: ItemVariantID
    let conceptIDs: [ConceptID]
    let objectiveMappings: [ObjectiveMapping]
    let scaffoldLevel: ScaffoldLevel
    let result: AttemptResult
    let contentRevision: Int
    let wasPreviouslySeen: Bool
    let submittedAt: Date
}
```

- [ ] **Step 8: Implement `ReviewRecord` and `ReadinessSnapshot`**

```swift

struct ReviewRecord: Codable, Equatable {
    let id: ReviewID
    let conceptID: ConceptID
    let createdAt: Date
    let dueAt: Date
    let policyVersion: MasteryPolicyVersion
    let sourceEvidenceAttemptIDs: [AttemptID]
    let satisfyingAttemptID: AttemptID?
}

struct ReadinessSnapshot: Codable, Equatable {
    let objectiveSetID: ObjectiveSetID
    let policyVersion: MasteryPolicyVersion
    let calculatedAt: Date
    let evidenceAttemptIDs: [AttemptID]
}
```

- [ ] **Step 9: Implement `CourseProgressDocument` and `ProgressDocument`**

```swift

struct CourseProgressDocument: Codable, Equatable {
    var completedLessonLocalIDs: Set<LessonLocalID> = []
    var stageEvents: [CourseStageEvent] = []
    var presentationStates: [LessonLocalID: LessonPresentationState] = [:]
    var assessmentAttempts: [AssessmentAttempt] = []
    var reviews: [ReviewRecord] = []
    var lastLessonLocalID: LessonLocalID?
    var readinessSnapshots: [ReadinessSnapshot] = []
}

struct ProgressDocument: Codable, Equatable {
    static let currentVersion = 3
    var version: Int
    var courses: [CourseID: CourseProgressDocument]
}
```

Do not add an authoritative `isReady` boolean. Use explicit initializers with
defaults only for the empty array/dictionary fields in
`CourseProgressDocument`; all identity-bearing evidence remains immutable.

- [ ] **Step 10: Run the higher-level DTO round-trip test**

Run: `swift test --filter ProgressDocumentTests/testVersionThreeRoundTrip`

Expected: the complete attempt/review/readiness graph round-trips with the
temporary default Date strategy.

- [ ] **Step 11: Write and run the failing course-key object test**

Create `testVersionThreeUsesObjectCourseKeys`: encode one Swift course, use
`JSONSerialization` to assert `courses` is `[String: Any]` and
`courses["swift-development"]` exists, and assert an empty course key fails
decode.

Run: `swift test --filter ProgressDocumentTests/testVersionThreeUsesObjectCourseKeys`

Expected: FAIL because synthesized custom-key dictionary coding produces an
alternating array instead of the required JSON object.

- [ ] **Step 12: Implement object-key coding for `ProgressDocument.courses`**

Encode through `[String: CourseProgressDocument]` keyed by
`CourseID.rawValue`. Decode the same shape, reject empty raw keys, and rebuild
the domain dictionary.

- [ ] **Step 13: Run the course-key wire-shape test**

Run: `swift test --filter ProgressDocumentTests/testVersionThreeUsesObjectCourseKeys`

Expected: PASS and `courses` is a JSON object.

- [ ] **Step 14: Write and run the failing presentation-state key test**

Create `testVersionThreeUsesObjectPresentationStateKeys`: encode one state,
assert `presentationStates["1"]` exists, and assert an empty local key fails
decode.

Run: `swift test --filter ProgressDocumentTests/testVersionThreeUsesObjectPresentationStateKeys`

Expected: FAIL because synthesized custom-key dictionary coding is not a JSON
object.

- [ ] **Step 15: Implement object-key coding for presentation states**

Encode through `[String: LessonPresentationState]` keyed by
`LessonLocalID.rawValue`. Decode the same shape and reject empty local IDs.

- [ ] **Step 16: Run presentation-key and invalid-key tests**

Run: `swift test --filter ProgressDocumentTests/testVersionThreeUsesObjectPresentationStateKeys`

Expected: object-key round trip passes and an empty key throws a decoding
error.

- [ ] **Step 17: Write and run a failing exact fractional timestamp test**

Round-trip `Date(timeIntervalSinceReferenceDate: 0.123456789)` and assert exact
`Date` equality. Assert the JSON date value contains a readable ISO-8601 string
with fractional seconds and the exact `referenceSeconds` Double. Also assert
the decoder accepts a whole-second ISO-8601 string from a hand-written fixture.

Run: `swift test --filter ProgressDocumentTests/testExactFractionalTimestamp`

Expected: FAIL with missing `ProgressDateCoding`.

- [ ] **Step 18: Implement the symmetric v3 date strategy**

`ProgressDateCoding` encodes each Date as a small object:

```swift
struct WireDate: Codable {
    let iso8601: String
    let referenceSeconds: Double
}
```

Format `iso8601` with `ISO8601DateFormatter` using
`[.withInternetDateTime, .withFractionalSeconds]`. Decode `WireDate` by using
`referenceSeconds` to reconstruct the exact `Date`; parse the ISO string as a
validation check. For hand-written fixtures, fall back to decoding a single
ISO string with the fractional formatter and then the whole-second formatter.
Expose `encodingStrategy` and `decodingStrategy` constants for every v3 encoder
and decoder.

- [ ] **Step 19: Add the literal v3 fixture and run all progress-model tests**

The fixture uses JSON objects named by raw ID strings, never synthesized
alternating key/value arrays, and uses the exact `WireDate` shape. Decode it,
re-encode with sorted keys and `ProgressDateCoding`, and compare parsed JSON
objects for equality. Every objective mapping explicitly includes its
`conceptID`, `objectiveSetID`, and `objectiveID`.

Run: `swift test --filter ProgressDocumentTests`

Expected: ID, DTO, object-key, exact fractional-date, whole-second fallback,
and fixture round-trip tests PASS.

- [ ] **Step 20: Run the diff check**

Run: `git diff --check`

Expected: no output and exit status 0.

- [ ] **Step 21: Commit the progress document contracts**

```bash
git add Sources/SwiftTutorApprentice/Models/LearningEvidence.swift \
  Sources/SwiftTutorApprentice/Models/ProgressDocument.swift \
  Tests/SwiftTutorApprenticeTests/ProgressDocumentTests.swift \
  Tests/SwiftTutorApprenticeTests/Fixtures/version-3-progress.json
git commit -m "feat: define course scoped progress schema"
```

## Chunk 2: Progress Migration, Store, and Presentation Content

### Task 5: Decode and migrate v1/v2 progress with a pure result contract

**Files:**
- Create: `Sources/SwiftTutorApprentice/Services/ProgressMigration.swift`
- Create: `Tests/SwiftTutorApprenticeTests/Fixtures/version-2-progress.json`
- Test: `Tests/SwiftTutorApprenticeTests/ProgressMigrationTests.swift`

- [ ] **Step 1: Add a literal version 2 fixture and fixture loader**

The fixture contains completion ID `2` plus a `deepLessonViewed` event for
lesson `1` at legacy encoded Date value `0`. Add this complete helper:

```swift
private func fixtureData(_ name: String) throws -> Data {
    let url = try XCTUnwrap(Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "Fixtures"
    ))
    return try Data(contentsOf: url)
}
```

- [ ] **Step 2: Write a failing version 1 migration test**

Encode `{"completedLessonIDs":[1,3]}` and assert
`ProgressMigration.decode(data:)` returns `.migrated(sourceVersion: 1, ...)`
with Swift local IDs `1` and `3`, no stage events, and no presentation state.

- [ ] **Step 3: Run the v1 test and verify the migrator is missing**

Run: `swift test --filter ProgressMigrationTests/testVersionOneMigratesToSwiftCourse`

Expected: FAIL with missing `ProgressMigration`.

- [ ] **Step 4: Implement the version envelope, result enum, and v1 branch**

```swift
enum ProgressLoadResult: Equatable {
    case current(ProgressDocument)
    case migrated(sourceVersion: Int, document: ProgressDocument)
    case unsupportedFuture(version: Int, originalData: Data)
    case corruptSupported(version: Int, originalData: Data, reason: String)
}
```

Decode only the optional integer version before decoding a payload. Missing
version means v1. A valid v1 payload maps integer IDs to Swift decimal local
IDs and returns an in-memory v3 document without writing.

- [ ] **Step 5: Run the v1 migration test until it passes**

Run: `swift test --filter ProgressMigrationTests/testVersionOneMigratesToSwiftCourse`

Expected: PASS.

- [ ] **Step 6: Write and run a failing lossy v2 element-decoder test**

Call the internal `LegacyStageEventDecoder.decodeElements(from:)` directly with
one valid element and one structurally undecodable element. Assert it returns
the structurally valid `LegacyStageEvent` without yet asking for metadata
validation, deduplication, IDs, or a v3 document.

Run: `swift test --filter ProgressMigrationTests/testLossyVersionTwoElementDecoding`

Expected: FAIL with missing `LegacyStageEventDecoder`.

- [ ] **Step 7: Implement only `LegacyStageEvent` and lossy element decoding**

`LegacyStageEvent` contains legacy integer lesson ID, kind, timestamp,
question ID, and correctness. Decode each array element independently and
discard only elements that cannot decode structurally.

- [ ] **Step 8: Run the lossy element-decoder test**

Run: `swift test --filter ProgressMigrationTests/testLossyVersionTwoElementDecoding`

Expected: PASS.

- [ ] **Step 9: Write and run a failing legacy metadata-validator test**

Call `ProgressMigration.hasValidMetadata(_:)` directly. Assert Recall requires
a nonblank question ID plus correctness, while Deep Lesson and Modify require
both optional metadata fields to be nil.

Run: `swift test --filter ProgressMigrationTests/testLegacyMetadataValidation`

Expected: FAIL with missing `hasValidMetadata`.

- [ ] **Step 10: Implement only legacy metadata validation**

Port the current `ProgressStore.hasValidMetadata` switch without adding
deduplication or mapping.

- [ ] **Step 11: Run the metadata-validator test**

Run: `swift test --filter ProgressMigrationTests/testLegacyMetadataValidation`

Expected: PASS.

- [ ] **Step 12: Write and run a failing first-logical-event deduplication test**

Pass valid `LegacyStageEvent` values to
`ProgressMigration.firstUniqueLegacyEvents(from:)`. Assert the first
`(lessonID, kind, recallQuestionID)` wins and events for distinct questions
remain.

Run: `swift test --filter ProgressMigrationTests/testFirstLegacyLogicalEventWins`

Expected: FAIL with missing `firstUniqueLegacyEvents`.

- [ ] **Step 13: Implement only first-logical-event filtering**

Use an internal Hashable key of legacy lesson ID, kind, and question ID only
for Recall. Do not generate IDs or v3 objects in this function.

- [ ] **Step 14: Run the duplicate-filter test**

Run: `swift test --filter ProgressMigrationTests/testFirstLegacyLogicalEventWins`

Expected: PASS.

- [ ] **Step 15: Write and run failing canonical legacy-ID tests**

Call `ProgressMigration.legacyEventID(for:)` directly. For the whole-second
fixture, assert this exact ID:

```text
legacy-v2|swift-development|1|deepLessonViewed|-|978307200000
```

For an event at legacy reference-date value `0.123456789`, assert the ID ends
in `978307200123`.

Run: `swift test --filter ProgressMigrationTests/testCanonicalLegacyEventID`

Expected: FAIL with missing `legacyEventID`.

- [ ] **Step 16: Implement only canonical legacy ID generation**

The ID's final component is
`Int64((timestamp.timeIntervalSince1970 * 1000).rounded())`; use
`questionID ?? "-"`. This function does not mutate or deduplicate.

- [ ] **Step 17: Run the canonical-ID tests**

Run: `swift test --filter ProgressMigrationTests/testCanonicalLegacyEventID`

Expected: both whole- and fractional-second ID cases PASS.

- [ ] **Step 18: Write and run a failing legacy-to-course-event conversion test**

Convert one already validated, identified `LegacyStageEvent` and assert every
`CourseStageEvent` field matches. This test does not decode a document.

Run: `swift test --filter ProgressMigrationTests/testLegacyEventConversion`

Expected: FAIL with missing conversion method.

- [ ] **Step 19: Implement only legacy-to-course-event conversion**

Use `legacyEventID(for:)` and decimal-string lesson local IDs. Copy timestamp,
kind, question ID, and correctness unchanged.

- [ ] **Step 20: Run the event-conversion test**

Run: `swift test --filter ProgressMigrationTests/testLegacyEventConversion`

Expected: PASS.

- [ ] **Step 21: Write and run failing v2 document-mapping and fractional-date tests**

Assert the version 2 fixture migrates completion `2` and the valid event's
timestamp/metadata into a `CourseStageEvent` with the tested ID. Add the
fractional legacy event, migrate it, encode the v3 document using
`ProgressDateCoding`, decode it, and assert exact timestamp equality. Assert
presentation state remains empty.

Run: `swift test --filter ProgressMigrationTests/testVersionTwoDocumentMapping`

Expected: FAIL because the v2 branch does not yet compose the tested helpers
into a v3 document.

- [ ] **Step 22: Implement only v2 document mapping**

Compose the already-tested element decoder, metadata validator, duplicate
filter, ID generator, and event converter. Map completion and retained events
into the Swift course record without writing and without deriving presentation
state.

- [ ] **Step 23: Run all v2 migration tests**

Run: `swift test --filter ProgressMigrationTests/testVersionTwo`

Expected: preservation, invalid-element, first-duplicate, full-ID, and exact
fractional timestamp tests PASS.

- [ ] **Step 24: Write and run the failing current-v3 result test**

Use `version-3-progress.json` to assert `.current(document)` with every field.

Run: `swift test --filter ProgressMigrationTests/testCurrentVersionThreeResult`

Expected: FAIL because current v3 decoding is not implemented.

- [ ] **Step 25: Decode current v3 using `ProgressDateCoding`**

Return `.current` only after the complete v3 document decodes with the exact
wire strategies from Task 4.

- [ ] **Step 26: Run the current-v3 result test**

Run: `swift test --filter ProgressMigrationTests/testCurrentVersionThreeResult`

Expected: PASS.

- [ ] **Step 27: Write and run the failing future-v4 envelope test**

Use `{"version":4,"payload":"not decodable by this app"}` and assert
`.unsupportedFuture(version: 4, originalData: exactBytes)` without payload
decode.

Run: `swift test --filter ProgressMigrationTests/testFutureVersionSkipsPayloadDecode`

Expected: FAIL because the future-envelope branch is missing.

- [ ] **Step 28: Implement only the future-version envelope branch**

Return original bytes immediately when `version > 3`; never decode its payload.

- [ ] **Step 29: Run the future-v4 envelope test**

Run: `swift test --filter ProgressMigrationTests/testFutureVersionSkipsPayloadDecode`

Expected: PASS.

- [ ] **Step 30: Write and run failing corrupt-supported result tests**

Use three exact inputs: malformed versionless v1, a version-2 envelope with an
invalid payload, and malformed v3 JSON. Assert every result is
`.corruptSupported` with the detected supported version, exact original bytes,
and a nonempty reason.

Run: `swift test --filter ProgressMigrationTests/testCorruptSupportedVersionsPreserveBytes`

Expected: FAIL because all supported corrupt envelopes are not classified.

- [ ] **Step 31: Implement only the corrupt-supported branch**

Never turn corrupt supported bytes into an empty writable document.

- [ ] **Step 32: Run all pure migration tests**

Run: `swift test --filter ProgressMigrationTests`

Expected: all v1/v2/v3/future/corrupt result tests PASS.

- [ ] **Step 33: Commit the pure migration boundary**

```bash
git add Sources/SwiftTutorApprentice/Services/ProgressMigration.swift \
  Tests/SwiftTutorApprenticeTests/ProgressMigrationTests.swift \
  Tests/SwiftTutorApprenticeTests/Fixtures/version-2-progress.json
git commit -m "feat: add lossless progress migration"
```

### Task 6: Refactor `ProgressStore` to course-keyed v3 persistence

**Files:**
- Modify: `Sources/SwiftTutorApprentice/Services/ProgressStore.swift:20-305`
- Modify: `Tests/SwiftTutorApprenticeTests/ProgressStoreMigrationTests.swift:28-451`

- [ ] **Step 1: Update the existing version-specific test expectations**

Make these explicit changes before adding behavior:

- Change `testFutureVersionLoadsReadOnlyAndEveryMutationLeavesStateAndBytesUnchanged`
  and `testFutureVersionWithIncompatiblePayloadIsReadOnlyBeforePayloadDecode`
  to use version `4`, not `3`.
- Rename `testResetClearsCompletionAndStageEventsAndPersistsVersionTwo` to end
  in `PersistsVersionThree` and assert the course-keyed object shape.
- Keep `testVersionTwoReloadPreservesEveryEventField`, but change it to assert
  v2 loads in memory without rewriting and the first mutation writes v3.
- Add `testVersionThreeReloadPreservesEveryFieldWithoutRewriting` using the
  literal v3 fixture.

- [ ] **Step 2: Add the initial store and decoder test helpers**

```swift
private func makeStore() -> ProgressStore {
    ProgressStore(fileURL: progressURL, now: { fixedDate })
}

private func decodeV3(_ url: URL) throws -> ProgressDocument {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = ProgressDateCoding.decodingStrategy
    return try decoder.decode(ProgressDocument.self, from: Data(contentsOf: url))
}
```

- [ ] **Step 3: Add failing v2/v3 load and no-rewrite tests**

Load the v2 fixture, assert `isComplete(.swift(2))` and
`hasViewedDeepLesson(.swift(1))`, and compare on-disk bytes to the original.
Load the v3 fixture and assert every field plus unchanged bytes.

- [ ] **Step 4: Run the focused store tests and confirm the keyed APIs are missing**

Run: `swift test --filter ProgressStoreMigrationTests/testVersionTwo`

Run: `swift test --filter ProgressStoreMigrationTests/testVersionThreeReloadPreservesEveryFieldWithoutRewriting`

Expected: the v2 command FAILS at compile time for `isComplete(LessonKey)`;
the v3 command also fails until the current-document load path is implemented.

- [ ] **Step 5: Implement only current/migrated load and keyed read queries**

Refactor load to populate the v3 document for `.current` and `.migrated`
without writing. Add `progress(for:)`, `isComplete(_ key:)`, and keyed Deep
Lesson/Modify queries needed by the Step 3 test. Keep integer read adapters.

- [ ] **Step 6: Run the v2/v3 load and no-rewrite tests**

Run: `swift test --filter ProgressStoreMigrationTests/testVersionTwo`

Expected: v2 loads through the migrated document without rewriting.

Run: `swift test --filter ProgressStoreMigrationTests/testVersionThreeReloadPreservesEveryFieldWithoutRewriting`

Expected: v3 reload preserves every field without rewriting.

- [ ] **Step 7: Write and run future/corrupt load-state tests**

Assert version 4 sets `isReadOnlyForUnsupportedVersion`; malformed v3 sets a
nonempty `loadError`; both retain exact original bytes on construction.

Run: `swift test --filter ProgressStoreMigrationTests/testFutureAndCorruptLoadState`

Expected: FAIL because load error modes are not wired.

- [ ] **Step 8: Implement only future and corrupt load flags**

Store the original bytes, set the existing future-version flag or new
`@Published private(set) var loadError: String?`, and do not create an empty
writable document for either result.

- [ ] **Step 9: Run future/corrupt load-state tests**

Run: `swift test --filter ProgressStoreMigrationTests/testFutureAndCorruptLoadState`

Expected: PASS.

- [ ] **Step 9a: Write and run a failing keyed-completion save test**

Start from the v2 fixture, call `markComplete(.swift(3))`, and assert the
in-memory keyed completion plus an on-disk v3 document that preserves all
migrated completion/events and uses the Task 4 object-key/date wire shape.
Assert `markComplete(3)` is an equivalent idempotent compatibility adapter.

Run: `swift test --filter ProgressStoreMigrationTests/testKeyedCompletionWritesVersionThree`

Expected: FAIL because keyed completion and v3 saving are missing.

- [ ] **Step 9b: Implement keyed completion and the basic v3 save path**

Add `markComplete(_ key: LessonKey)` plus the integer adapter. Implement one
private v3 serializer using pretty-printed/sorted keys and
`ProgressDateCoding`. Add `ProgressStore.atomicWrite`, which creates the parent
directory and then calls `data.write(to:options: .atomic)`. Use that writer for
ordinary saves; do not add injection, `saveError`, or retry yet.

- [ ] **Step 9c: Run the keyed-completion save test**

Run: `swift test --filter ProgressStoreMigrationTests/testKeyedCompletionWritesVersionThree`

Expected: PASS with the exact v3 wire document on disk.

- [ ] **Step 10: Extend the helper, then write and run keyed stage tests**

Change `makeStore` to accept only this new parameter:

```swift
private func makeStore(
    makeEventID: @escaping () -> ProgressEventID = {
        ProgressEventID(rawValue: "new-event-id")
    }
) -> ProgressStore {
    ProgressStore(fileURL: progressURL,
                  now: { fixedDate },
                  makeEventID: makeEventID)
}
```

Assert idempotency for `markDeepLessonViewed(_ key:)`,
`markModifyPassed(_ key:)`, and
`recordRecallAnswer(lessonKey:questionID:wasCorrect:)`; assert the integer
overloads return the same data for existing views. Starting from the v2 fixture,
assert the first keyed mutation writes v3 with preserved completion, the full
legacy event ID from Task 5, and the injected new event ID.

Run: `swift test --filter ProgressStoreMigrationTests/testKeyedStageMethods`

Expected: FAIL because key-based stage methods do not exist.

- [ ] **Step 11a: Add only event-ID injection**

Extend the existing initializer with
`makeEventID: @escaping () -> ProgressEventID = { ...UUID... }` and retain it.
Do not call it during load or completion.

- [ ] **Step 11b: Add keyed stage methods and integer adapters**

Every new event uses `makeEventID()` exactly once. Preserve the legacy
first-answer-wins and valid-metadata behavior. Use the existing future-version
guard; corrupt-state centralization is tested in Step 22.

- [ ] **Step 12: Run keyed stage tests**

Run: `swift test --filter ProgressStoreMigrationTests/testKeyedStageMethods`

Expected: PASS.

- [ ] **Step 13: Write and run presentation-state persistence tests**

Set `.started` for `.swift(1)`, reload, and assert every state field persists.
Then set `.skipped` and assert replacement by lesson key. Separately load a
legacy completed Lesson 1 and assert `presentationState(for:) == nil`.

Run: `swift test --filter ProgressStoreMigrationTests/testPresentationStatePersistence`

Expected: FAIL because presentation-state APIs are missing.

- [ ] **Step 14: Implement keyed presentation-state get/set methods**

Add `presentationState(for:)` and `setPresentationState(_:for:)`. Persist only
the addressed course/local key and never infer a state from completion or
Deep Lesson activity.

- [ ] **Step 15: Run presentation-state persistence tests**

Run: `swift test --filter ProgressStoreMigrationTests/testPresentationStatePersistence`

Expected: PASS.

- [ ] **Step 16: Write and run attempt-ID and course-reset tests**

Create `makeAttempt(id:)` inline from Task 4. Record the same attempt twice and
assert one entry. Seed a second course record, call
`reset(courseID: .swiftDevelopment)`, and assert only Swift completion, stage,
presentation, attempts, reviews, last lesson, and readiness clear.

Run: `swift test --filter ProgressStoreMigrationTests/testAttemptIDAndCourseReset`

Expected: FAIL because attempt recording and course reset are missing.

- [ ] **Step 17: Implement `record(_:)` and course-only reset**

Deduplicate only by `AttemptID`; distinct attempts for the same variant remain.
Use the existing future-version guard; corrupt-state centralization is tested
in Step 22.

- [ ] **Step 18: Run attempt/reset tests**

Run: `swift test --filter ProgressStoreMigrationTests/testAttemptIDAndCourseReset`

Expected: PASS.

- [ ] **Step 18a: Write and run meaningful-activity/last-lesson tests**

Assert an empty course and merely reading it report no meaningful activity.
Assert completion, stage event, started/skipped/completed presentation,
submitted attempt, satisfied review result, or explicit saved-workspace
activity each report meaningful activity and store/derive that activity's
`lastLessonLocalID`. A satisfied review must have a nonnil
`satisfyingAttemptID` resolving to an assessment attempt in the same course;
derive its lesson from that attempt. Assert an unsatisfied scheduled review, an
unresolvable satisfying ID, and a `.notStarted` presentation do not count.
Course reset clears the last lesson and returns false.

Run: `swift test --filter ProgressStoreMigrationTests/testMeaningfulActivityAndLastLesson`

Expected: FAIL because the query and explicit workspace-activity API are
missing.

- [ ] **Step 18b: Implement meaningful activity and last-lesson updates**

Add `hasMeaningfulActivity(in:)`, `lastLessonKey(in:)`, and
`recordSavedWorkspaceActivity(for:)`. Every existing successful keyed mutation
sets its lesson as last; opening/selecting a lesson never calls this API.
Exclude `.notStarted` presentation state and unsatisfied/unresolvable review
records. A satisfied review derives its key only from its referenced immutable
attempt. Persist through the already-tested v3 save path.

- [ ] **Step 18c: Run meaningful-activity tests**

Run: `swift test --filter ProgressStoreMigrationTests/testMeaningfulActivityAndLastLesson`

Expected: PASS, including reset and no-activity navigation boundaries.

- [ ] **Step 19: Extend the helper, then write first-save and retry tests**

```swift
final class ControllableWriter {
    var shouldFail = true
    func write(_ data: Data, to url: URL) throws {
        if shouldFail { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url, options: .atomic)
    }
}
```

Only now add `writeData` to `makeStore`, defaulting it to
`ProgressStore.atomicWrite`, and pass it through the initializer. The expected
compile failure is the missing production initializer parameter plus
`saveError`/`retrySave`.

First construct a default-writer store at a nested URL whose parent does not
exist, mutate it, and assert the directory and v3 file are created. Then
Write the v2 fixture to disk, construct the store with
`writeData: writer.write`, call `markComplete(.swift(3))`, and assert: the
in-memory state includes lesson 3, `saveError` is nonnil, and file bytes remain
exactly the original v2 bytes. Set `shouldFail = false`, call `retrySave()`, and
assert `saveError == nil` and the file decodes as the retained v3 state.

Run: `swift test --filter ProgressStoreMigrationTests/testAtomicWriteAndRetry`

Expected: FAIL because writer injection and retained-state retry do not exist;
the already-tested default writer still creates the missing parent.

- [ ] **Step 20a: Implement only writer injection**

Use this exact initializer boundary:

```swift
init(fileURL: URL,
     now: @escaping () -> Date,
     makeEventID: @escaping () -> ProgressEventID = {
         ProgressEventID(rawValue: UUID().uuidString)
     },
     writeData: @escaping (Data, URL) throws -> Void = ProgressStore.atomicWrite)
```

Route the existing basic serializer through the injected writer. Keep
`ProgressStore.atomicWrite` as the production default and preserve its parent
creation behavior.

- [ ] **Step 20b: Implement retained save error and retry**

Expose `@Published private(set) var saveError: String?` and `retrySave()`.
On failure retain the already-mutated in-memory v3 document and prior file.
Retry serializes that existing document; it does not reload or regenerate
event IDs. Clear `saveError` only after a successful retry/write.

- [ ] **Step 21: Run atomic write and retry tests**

Run: `swift test --filter ProgressStoreMigrationTests/testAtomicWriteAndRetry`

Expected: both missing-parent and retained-state retry tests PASS.

- [ ] **Step 22: Write and run the complete future/corrupt mutation matrix**

For separate version-4 and corrupt-v3 files, invoke mark complete, Deep Lesson,
Modify, Recall, presentation set, attempt record, course reset, and retry save.
Assert every in-memory value and every original byte remains unchanged.

Run: `swift test --filter ProgressStoreMigrationTests/testUnsupportedAndCorruptBlockEveryMutation`

Expected: FAIL for corrupt progress because newly added mutations do not yet
share one corrupt/future guard.

- [ ] **Step 23: Centralize the mutation guard across every write path**

Add one `canMutate` check requiring neither unsupported future state nor
corrupt load state. Apply it to all legacy/new mutation methods and
`retrySave()`.

- [ ] **Step 24: Run store tests, full tests, and diff checks separately**

Run: `swift test --filter ProgressStoreMigrationTests`

Expected: all focused tests PASS.

Run: `swift test`

Expected: the full suite passes with no regressions.

Run: `git diff --check`

Expected: no output and exit status 0.

- [ ] **Step 25: Commit the course-keyed store**

```bash
git add Sources/SwiftTutorApprentice/Services/ProgressStore.swift \
  Tests/SwiftTutorApprenticeTests/ProgressStoreMigrationTests.swift
git commit -m "feat: persist course scoped progress"
```

### Task 7: Add a versioned lesson-presentation schema with fail-closed decoding

**Files:**
- Create: `Sources/SwiftTutorApprentice/Models/LessonPresentation.swift`
- Create: `Tests/SwiftTutorApprenticeTests/Fixtures/future-presentation-lessons.json`
- Modify: `Sources/SwiftTutorApprentice/Models/Lesson.swift:27-148`
- Test: `Tests/SwiftTutorApprenticeTests/LessonPresentationTests.swift`
- Modify: `Tests/SwiftTutorApprenticeTests/LessonCompatibilityTests.swift:1-318`

- [ ] **Step 1: Write and run failing standalone presentation-model tests**

Create `LessonPresentationTests.swift`. Round-trip one presentation and assert
scene identity, poster/before/after states, presentation concept/objective
mappings, transcript, provenance, and AI-code exercise claims. Assert
`schemaVersion` always encodes as `1`.

Run: `swift test --filter LessonPresentationTests`

Expected: FAIL with missing `LessonPresentation`.

- [ ] **Step 2: Implement visual-state and scene value types**

```swift
enum PresentationVisualKind: String, Codable, Hashable {
    case codeExecution, valueBinding, outputFlow, branchChoice,
         collectionChange, webRender, packetJourney, securityTimeline,
         labeledDiagram
}

struct PresentationValue: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let value: String
}

struct PresentationCodeToken: Codable, Hashable, Identifiable {
    let id: String
    let text: String
}

enum PresentationFocusKind: String, Codable, Hashable {
    case codeToken, value, output
}

struct PresentationFocusTarget: Codable, Hashable {
    let kind: PresentationFocusKind
    let id: String
}

struct PresentationVisualState: Codable, Hashable {
    let code: String?
    let codeTokens: [PresentationCodeToken]
    let values: [PresentationValue]
    let output: String?
    let outputTargetID: String?
    let description: String
}

struct PresentationScene: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let caption: String
    let narration: String
    let staticDescription: String
    let visualKind: PresentationVisualKind
    let focusTargets: [PresentationFocusTarget]
    let before: PresentationVisualState
    let after: PresentationVisualState
}
```

- [ ] **Step 3: Implement only AI-code review value types**

```swift
struct AICodeClaim: Codable, Hashable, Identifiable {
    let id: String
    let text: String
    let isCorrect: Bool
    let explanation: String
}

struct AICodeReviewExercise: Codable, Hashable, Identifiable {
    let id: String
    let prompt: String
    let generatedCode: String
    let claims: [AICodeClaim]
    let conceptIDs: [ConceptID]
}
```

- [ ] **Step 4: Implement the presentation provenance and envelope**

```swift

enum LessonPresentationProvenanceSource: String, Codable, Hashable {
    case bundled
}

struct LessonPresentationProvenance: Codable, Hashable {
    let source: LessonPresentationProvenanceSource
    let revision: Int
}

struct LessonPresentation: Codable, Hashable, Identifiable {
    static let currentSchemaVersion = 1
    let schemaVersion: Int
    let id: String
    let title: String
    let posterDescription: String
    let posterState: PresentationVisualState
    let scenes: [PresentationScene]
    let transcript: String
    let narrationLocale: String
    let finalRecallQuestionID: String
    let aiCodeExercise: AICodeReviewExercise?
    let conceptIDs: [ConceptID]
    let objectiveMappings: [ObjectiveMapping]
    let provenance: LessonPresentationProvenance
}
```

Give `LessonPresentation` a custom decoder that rejects any schema other than
1 and an encoder that always writes the current version.

- [ ] **Step 5: Run standalone presentation tests**

Run: `swift test --filter LessonPresentationTests`

Expected: round-trip and schema tests PASS.

- [ ] **Step 6: Add and run failing `Lesson` compatibility tests**

Add cases for missing presentation, explicit null, current presentation
round-trip, malformed presentation, and future schema. Future/malformed
presentation must leave all base lesson fields readable, set presentation to
nil, and set `hasUnsupportedPresentation == true`; missing/null is supported
and leaves the flag false.

Run: `swift test --filter LessonCompatibilityTests/testPresentation`

Expected: FAIL because `Lesson` has no presentation fields.

- [ ] **Step 7: Add optional presentation decoding to `Lesson`**

Add `var presentation: LessonPresentation? = nil`, runtime-only
`private(set) var hasUnsupportedPresentation = false`, and a schema-envelope
decode path parallel to Deep Lesson. A presentation failure must not set
`hasUnsupportedDeepContent`; preserve the two diagnostics independently.
Refactor the current early-return Deep Lesson branch so both optional envelopes
initialize their value and unsupported flag on every decode path before the
initializer returns.

- [ ] **Step 8: Run compatibility and full lesson tests**

Run: `swift test --filter LessonCompatibilityTests`

Expected: all legacy, Deep Lesson, and presentation compatibility tests PASS.

- [ ] **Step 9: Author and validate the literal future-presentation fixture**

Create `future-presentation-lessons.json` as a complete one-lesson array with
readable base lesson fields and non-null presentation `schemaVersion: 2` plus
one additive future-only field. Add a compatibility test that reads the literal
fixture, asserts the base lesson title/starter code remain readable,
`presentation == nil`, and `hasUnsupportedPresentation == true`, then compares
the loaded bytes to the fixture bytes.

Run: `swift test --filter LessonCompatibilityTests/testLiteralFuturePresentationFixturePreservesBaseLesson`

Expected: PASS and the literal fixture is proven usable by Task 8.

- [ ] **Step 10: Commit the presentation schema**

```bash
git add Sources/SwiftTutorApprentice/Models/LessonPresentation.swift \
  Sources/SwiftTutorApprentice/Models/Lesson.swift \
  Tests/SwiftTutorApprenticeTests/LessonPresentationTests.swift \
  Tests/SwiftTutorApprenticeTests/LessonCompatibilityTests.swift \
  Tests/SwiftTutorApprenticeTests/Fixtures/future-presentation-lessons.json
git commit -m "feat: add versioned lesson presentations"
```

### Task 8: Enrich compatible Swift lessons without overwriting learner data

**Files:**
- Modify: `Sources/SwiftTutorApprentice/Services/LessonStore.swift:18-244`
- Modify: `Tests/SwiftTutorApprenticeTests/LessonStoreMigrationTests.swift:1-636`

- [ ] **Step 1: Write and run failing compatible-enrichment tests**

Add tests proving a saved built-in lesson with matching ID/kind/starter code
and `presentation == nil` receives only the bundled presentation while edited
title, goal, output, order, and Deep Lesson remain unchanged. Add a different
starter-code case that receives no presentation.

Run: `swift test --filter LessonStoreMigrationTests/testCompatibleBuiltInLessonReceivesOnlyStockPresentation`

Expected: FAIL because presentation enrichment does not exist.

- [ ] **Step 2: Add presentation-only field enrichment**

Extend the current merge pass with the same ID, kind, and exact starter-code
compatibility guard used by Deep Lesson. Copy only `presentation`; save only
when the resulting lesson differs.

- [ ] **Step 3: Run compatible and edited-lesson enrichment tests**

Run: `swift test --filter LessonStoreMigrationTests/testCompatibleBuiltInLessonReceivesOnlyStockPresentation`

Expected: matching lessons enrich and edited starter code remains untouched.

- [ ] **Step 4: Write and run bundled presentation revision tests**

Assert older bundled revision upgrades to the exact default presentation,
equal-revision content drift repairs to the exact default, and a newer bundled
revision makes the store read-only before compatibility reconciliation or
removal.

Run: `swift test --filter LessonStoreMigrationTests/testBundledPresentationRevision`

Expected: FAIL because presentation provenance reconciliation is missing.

- [ ] **Step 5: Implement bundled presentation provenance reconciliation**

Mirror the current Deep Lesson rules in a focused
`reconcilingBundledPresentation(in:)` helper. Upgrade/repair only compatible
bundled content, preserve nil/custom base fields, and detect a newer revision
before any automatic mutation.

- [ ] **Step 6: Run presentation revision tests**

Run: `swift test --filter LessonStoreMigrationTests/testBundledPresentationRevision`

Expected: older/equal presentations reconcile and newer content remains
byte-preserving read-only.

- [ ] **Step 7: Write and run the future-presentation byte-preservation test**

Load `future-presentation-lessons.json`, capture its exact bytes, attempt add,
update, delete, move, restore, and automatic merge, then assert all mutations
are blocked and bytes are identical.

Run: `swift test --filter LessonStoreMigrationTests/testFuturePresentationSchemaPreservesEveryByte`

Expected: FAIL because the store does not honor
`hasUnsupportedPresentation`.

- [ ] **Step 8: Generalize the store's read-only content gate**

Publish `isReadOnlyForUnsupportedLessonContent` when either Deep Lesson or
presentation content is unsupported. Keep
`isReadOnlyForUnsupportedDeepContent` as a compatibility computed adapter
until views migrate in Chunk 3. Every mutating path and automatic merge checks
the generalized gate before touching disk.

- [ ] **Step 9: Run every lesson store and compatibility test**

Run: `swift test --filter LessonStoreMigrationTests`

Expected: all enrichment, drift repair, custom lesson, future-schema, and
byte-preservation tests PASS.

Run: `swift test --filter LessonCompatibilityTests`

Expected: all compatibility tests PASS.

- [ ] **Step 10: Commit migration-safe presentation enrichment**

```bash
git add Sources/SwiftTutorApprentice/Services/LessonStore.swift \
  Tests/SwiftTutorApprenticeTests/LessonStoreMigrationTests.swift
git commit -m "feat: enrich lessons with safe presentations"
```

## Chunk 3: Validated Pilot Content and Presentation Runtime

### Task 9: Author and validate the Swift Lessons 1-3 presentation pilot

**Files:**
- Create: `Sources/SwiftTutorApprentice/Models/SwiftPilotPresentationContent.swift`
- Create: `Sources/SwiftTutorApprentice/Services/PresentationContentValidator.swift`
- Create: `Tests/SwiftTutorApprenticeTests/SwiftPilotPresentationContentTests.swift`
- Modify: `Sources/SwiftTutorApprentice/Models/Curriculum.swift:32-146`

- [ ] **Step 1a: Write and run failing identity/count validator tests**

Test blank/duplicate presentation, scene, code-token, value, and claim IDs plus
fewer than 3 or more than 6 scenes.

Run: `swift test --filter SwiftPilotPresentationContentTests/testValidatorRejectsInvalidIdentityOrSceneCount`

Expected: FAIL with missing `PresentationContentValidator`.

- [ ] **Step 1b: Implement only stable identity and scene-count validation**

Return `[PresentationValidationIssue]` rather than trapping. Add only the ID
and 3-through-6 scene rules from Step 1a.

- [ ] **Step 1c: Run identity/count validator tests**

Run: `swift test --filter SwiftPilotPresentationContentTests/testValidatorRejectsInvalidIdentityOrSceneCount`

Expected: PASS with one named issue per invalid fixture.

- [ ] **Step 2a: Write and run failing prose/state validator tests**

Test blank captions, narration, and static descriptions; identical before and
after states; and transcript text that omits one narration segment.

Run: `swift test --filter SwiftPilotPresentationContentTests/testValidatorRejectsInvalidProseOrState`

Expected: FAIL because prose/state rules are missing.

- [ ] **Step 2b: Implement only required prose, state-change, and transcript rules**

Keep the rules literal: trim required prose, require at least one unequal
before/after field, and require every narration string as a transcript
substring in scene order.

- [ ] **Step 2c: Run prose/state validator tests**

Run: `swift test --filter SwiftPilotPresentationContentTests/testValidatorRejectsInvalidProseOrState`

Expected: PASS.

- [ ] **Step 3a: Write and run failing linked-activity validator tests**

Test an invalid final Recall ID and a missing AI-code exercise.

Run: `swift test --filter SwiftPilotPresentationContentTests/testValidatorRejectsInvalidLinkedActivity`

Expected: FAIL because linked-activity rules are missing.

- [ ] **Step 3b: Implement only Recall-link and required pilot-exercise rules**

Resolve the Recall ID against the supplied lesson's current Deep Lesson. For
pilot presentations require nonnil AI-code exercise; do not yet validate its
concept/objective mappings.

- [ ] **Step 3c: Run linked-activity validator tests**

Run: `swift test --filter SwiftPilotPresentationContentTests/testValidatorRejectsInvalidLinkedActivity`

Expected: PASS.

- [ ] **Step 4: Write and run failing focus-target validator tests**

Cover blank and duplicate focus targets plus each dangling target kind:

- `.codeToken` must resolve to a `PresentationCodeToken.id` in the scene's
  before or after state, and joined token text must exactly equal nonnil `code`.
- `.value` must resolve to a `PresentationValue.id` in before or after.
- `.output` must match a nonnil `outputTargetID` in before or after.

Run: `swift test --filter SwiftPilotPresentationContentTests/testValidatorRejectsInvalidFocusTargets`

Expected: FAIL because focus resolution is not implemented.

- [ ] **Step 5: Implement only focus-target validation**

Reject blank or duplicate `(kind, id)` pairs and apply the exact per-kind
resolution rules from Step 4. Do not infer IDs from code text or output text.

- [ ] **Step 6: Run the focus-target validator tests**

Run: `swift test --filter SwiftPilotPresentationContentTests/testValidatorRejectsInvalidFocusTargets`

Expected: PASS.

- [ ] **Step 7: Write and run failing concept/objective mapping tests**

Assert presentation concept IDs are nonblank and unique; AI exercise concept
IDs are a subset of the presentation concept IDs; every objective mapping
references one of those presentation concepts; and the final Recall ID exists
in the lesson's current Deep Lesson recall questions. For a course whose
`activeObjectiveSetID` is nil, assert objective mappings must be empty. For a
test course with an active objective set, assert every mapping uses that exact
set and an objective supplied through an explicit
`[ObjectiveSetID: Set<ObjectiveID>]` validator argument.

Run: `swift test --filter SwiftPilotPresentationContentTests/testValidatorRejectsInvalidMappings`

Expected: FAIL because mapping validation is not implemented.

- [ ] **Step 8: Implement release-aware mapping validation**

Validate only mappings the pilot actually declares; do not require complete
certification coverage while Swift is `.pilot`. Accept
`knownObjectivesBySet: [ObjectiveSetID: Set<ObjectiveID>]` explicitly rather
than inventing objective profiles in `CourseCatalog`. Resolve the active set
through the passed `CourseDefinition` and Recall IDs through the lesson. When
the course has no active set, require empty mappings. Return named issues
instead of trapping.

- [ ] **Step 9: Run all validator rejection tests**

Run: `swift test --filter SwiftPilotPresentationContentTests/testValidatorRejects`

Expected: all structure, focus, concept, objective, and Recall failures report
their named issue.

- [ ] **Step 10: Define the exact scene map and AI-review claims**

Use four scenes per lesson, reusing the corresponding existing Deep Lesson
segment explanation as narration and transcript text:

| Lesson | Presentation/scene IDs | Visual progression | AI claim to challenge |
|---|---|---|---|
| 1 | `swift-1-print-output`; `print-call`, `string-literal`, `execution`, `output` | empty → call; focus quotes; call active; stdout `Hello, Swift!` | “The quotation marks appear in the printed output.” |
| 2 | `swift-2-constant-binding`; `let-binding`, `stored-value`, `name-lookup`, `output` | empty → binding; value `name = "Alex"`; `print(name)` lookup; stdout `Alex` | “`print("name")` reads the value stored in `name`.” |
| 3 | `swift-3-variable-mutation`; `var-binding`, `first-value`, `reassignment`, `output` | empty → `var`; `count = 1`; mutate to `2`; stdout `2` | “Changing `var` to `let` still permits reassignment.” |

Each false claim has a correct evidence-based explanation. Add at least one
true claim per exercise. Concept IDs use the
`swift.lesson-<n>.<concept>` namespace. The poster and every state have a
complete static description.

- [ ] **Step 11: Write and run the failing Lesson 1 exact-content test**

Assert every ID/state in the table, linked existing Recall ID, one true and one
false AI claim, transcript equality to joined narration, and validator success.

Run: `swift test --filter SwiftPilotPresentationContentTests/testLessonOnePresentation`

Expected: FAIL because `SwiftPilotPresentationContent.lesson1` is missing.

- [ ] **Step 12a: Author the Lesson 1 poster and first two scenes**

Add the authored poster state plus `print-call` and `string-literal`, reusing
the corresponding Deep Lesson explanations as narration.

- [ ] **Step 12b: Author the Lesson 1 execution and output scenes**

Add `execution` and `output` with exact token/value/output IDs and static
descriptions from the Step 10 map.

- [ ] **Step 12c: Add Lesson 1 transcript, mappings, and AI claims**

Join the four narration strings in scene order, link the existing Recall ID,
declare concept IDs, set `objectiveMappings: []` because Swift has no active
objective set in Milestone 1, and add the pinned true/false claims.

- [ ] **Step 13: Run the Lesson 1 test**

Run: `swift test --filter SwiftPilotPresentationContentTests/testLessonOnePresentation`

Expected: PASS.

- [ ] **Step 14: Write and run the failing Lesson 2 exact-content test**

Run: `swift test --filter SwiftPilotPresentationContentTests/testLessonTwoPresentation`

Expected: FAIL because `lesson2` is missing.

- [ ] **Step 15a: Author the Lesson 2 poster and binding scenes**

Add the poster, `let-binding`, and `stored-value` scenes with the exact
`name = "Alex"` state and reused Deep Lesson narration.

- [ ] **Step 15b: Author the Lesson 2 lookup and output scenes**

Add `name-lookup` and `output`, resolving authored token/value/output IDs and
pinning stdout to `Alex`.

- [ ] **Step 15c: Add Lesson 2 transcript, mappings, and AI claims**

Join narration in order, link Recall, add concept IDs with
`objectiveMappings: []`, and add the name-versus-string-literal true/false
claims.

- [ ] **Step 16: Run the Lesson 2 test**

Run: `swift test --filter SwiftPilotPresentationContentTests/testLessonTwoPresentation`

Expected: PASS.

- [ ] **Step 17: Write and run the failing Lesson 3 exact-content test**

Run: `swift test --filter SwiftPilotPresentationContentTests/testLessonThreePresentation`

Expected: FAIL because `lesson3` is missing.

- [ ] **Step 18a: Author the Lesson 3 poster and binding scenes**

Add the poster, `var-binding`, and `first-value` scenes with reused narration.

- [ ] **Step 18b: Author the Lesson 3 reassignment and output scenes**

Add `reassignment` and `output` with the exact `1` to `2` state change and
stdout `2`.

- [ ] **Step 18c: Add Lesson 3 transcript, mappings, and AI claims**

Join narration, link Recall, add concept IDs with `objectiveMappings: []`, and
add the pinned `var`-versus-`let` claims.

- [ ] **Step 19: Run the Lesson 3 test**

Run: `swift test --filter SwiftPilotPresentationContentTests/testLessonThreePresentation`

Expected: PASS.

- [ ] **Step 20: Write and run the failing curriculum-scope test**

Assert default Lessons 1-3 have the exact presentation IDs and Lessons 4-24
remain nil.

Run: `swift test --filter SwiftPilotPresentationContentTests/testOnlyFirstThreeLessonsHavePresentations`

Expected: FAIL because the default curriculum does not reference the new
content.

- [ ] **Step 21: Wire only Lessons 1-3 into the default curriculum**

Add `presentation: SwiftPilotPresentationContent.lesson1/2/3` beside the
existing `deepContent` assignments. Assert Lessons 4-24 and custom lessons
remain nil.

- [ ] **Step 22: Run the pilot content tests**

Run: `swift test --filter SwiftPilotPresentationContentTests`

Expected: all structural and exact-content tests PASS.

- [ ] **Step 23: Run migration-sensitive lesson tests**

Run: `swift test --filter LessonStoreMigrationTests`

Expected: bundled presentation enrichment remains migration-safe.

- [ ] **Step 24: Run the full suite**

Run: `swift test`

Expected: the full suite passes with 0 failures.

- [ ] **Step 25: Commit the validated pilot content**

```bash
git add Sources/SwiftTutorApprentice/Models/SwiftPilotPresentationContent.swift \
  Sources/SwiftTutorApprentice/Services/PresentationContentValidator.swift \
  Sources/SwiftTutorApprentice/Models/Curriculum.swift \
  Tests/SwiftTutorApprenticeTests/SwiftPilotPresentationContentTests.swift
git commit -m "feat: add animated Swift lesson content"
```

### Task 10: Implement deterministic presentation entry and progress transitions

**Files:**
- Create: `Sources/SwiftTutorApprentice/Services/PresentationPlayerStateMachine.swift`
- Test: `Tests/SwiftTutorApprenticeTests/PresentationPlayerStateMachineTests.swift`

- [ ] **Step 1: Write and run failing first-visit and return-entry tests**

Assert this exact entry policy through
`PresentationPlayerStateMachine.entryMode(presentation:savedState:)`:

| Saved state | Presentation relationship | Entry mode |
|---|---|---|
| nil or `.notStarted` | any | `.expandedPoster` |
| `.started` | same revision and valid scene | `.compactResume(sceneID:)` |
| `.started` | changed revision or missing scene | `.compactResume(sceneID: firstSceneID)` |
| `.skipped` | any | `.compactSummary(status: .skipped)` |
| `.completed` | any | `.compactSummary(status: .completed)` |

Run: `swift test --filter PresentationPlayerStateMachineTests/testEntryMode`

Expected: FAIL with missing `PresentationPlayerStateMachine`.

- [ ] **Step 2: Implement only the entry-mode resolver**

Declare `PresentationEntryMode: Equatable` with the three cases in the table.
The resolver is pure and never writes progress. A revision change resets only
the resume scene to the first current scene; it does not invent a different
intentional status.

- [ ] **Step 3: Run the entry-mode tests**

Run: `swift test --filter PresentationPlayerStateMachineTests/testEntryMode`

Expected: PASS.

- [ ] **Step 4: Write and run failing Start/Next/Back transition tests**

Use a fixed date and assert:

- Start from a poster stores `.started`, first scene, current revision,
  `firstStartedAt == now`, `lastOpenedAt == now`, and replay count 0.
- Next stores the next scene and updates only `lastOpenedAt`.
- Back stores the previous scene and never moves before scene zero.
- Repeating Start while already started preserves the original
  `firstStartedAt`.

Run: `swift test --filter PresentationPlayerStateMachineTests/testStartNextAndBackTransitions`

Expected: FAIL because transition methods are missing.

- [ ] **Step 5: Implement only Start, Next, and Back transitions**

Add pure methods accepting the current presentation, optional saved state,
and `now`. Each returns a complete `LessonPresentationState`; no method writes
the store or derives mastery.

- [ ] **Step 6: Run Start/Next/Back transition tests**

Run: `swift test --filter PresentationPlayerStateMachineTests/testStartNextAndBackTransitions`

Expected: PASS.

- [ ] **Step 7: Write and run failing Skip/Replay/Complete tests**

Assert Skip stores `.skipped` without a scene, preserves an existing
`firstStartedAt`, never creates one when skipping directly from the poster, and
sets `lastOpenedAt == now`. Replay from skipped/completed starts scene one,
stores `.started`, increments replay count exactly once, preserves an existing
first-start timestamp or creates it when absent, and sets `lastOpenedAt == now`.
Complete stores `.completed` at the final scene, preserves `firstStartedAt`,
and sets `lastOpenedAt == now`. Assert no transition creates a Recall answer,
Modify pass, lesson completion, attempt, or readiness snapshot.

Run: `swift test --filter PresentationPlayerStateMachineTests/testSkipReplayAndCompleteTransitions`

Expected: FAIL because those transitions are missing.

- [ ] **Step 8: Implement only Skip, Replay, and Complete transitions**

Keep presentation progress observational: it records intentional player
actions only. Completion means presentation completion, not lesson mastery.

- [ ] **Step 9: Run all state-machine tests**

Run: `swift test --filter PresentationPlayerStateMachineTests`

Expected: entry, resume repair, action transition, and evidence-boundary tests
PASS.

- [ ] **Step 10: Commit the presentation state machine**

```bash
git add Sources/SwiftTutorApprentice/Services/PresentationPlayerStateMachine.swift \
  Tests/SwiftTutorApprenticeTests/PresentationPlayerStateMachineTests.swift
git commit -m "feat: define presentation playback transitions"
```

### Task 11: Build the offline presentation controller and animated SwiftUI player

**Files:**
- Modify: `Sources/SwiftTutorApprentice/Services/NarrationSpeaker.swift`
- Create: `Sources/SwiftTutorApprentice/Services/PresentationPlayerController.swift`
- Create: `Sources/SwiftTutorApprentice/Views/PresentationSceneVisual.swift`
- Create: `Sources/SwiftTutorApprentice/Views/LessonPresentationPlayer.swift`
- Test: `Tests/SwiftTutorApprenticeTests/PresentationPlayerControllerTests.swift`
- Test: `Tests/SwiftTutorApprenticeTests/LessonPresentationPlayerLayoutTests.swift`

- [ ] **Step 1: Write and run failing controller start/persistence tests**

Construct `PresentationPlayerController` with an injected `LessonKey`,
presentation, saved state, `now`,
`persist: (LessonKey, LessonPresentationState) -> Void`, and async `waitForAdvance`
closure. Assert construction
uses the Task 10 entry mode and calls `persist` zero times. Assert `start()`
persists the exact Task 10 state once and displays the first scene.

Run: `swift test --filter PresentationPlayerControllerTests/testConstructionDoesNotPersistAndStartDoes`

Expected: FAIL with missing controller.

- [ ] **Step 2: Implement controller initialization and Start only**

Make the controller `@MainActor`, `ObservableObject`, and expose read-only
`entryMode`, `currentSceneIndex`, `isPlaying`, `showsTranscript`,
`narrationEnabled`, and `visualPhase`. `visualPhase` is `.before` or `.after`;
Start begins on `.before`. Do not start a timer or narration in `init`.

Expose
`replacePresentation(for: LessonKey, presentation: LessonPresentation,
savedState: LessonPresentationState?)`; it must call `deactivate()` before
changing either identity and recalculating entry mode. Every persistence call
passes the controller's current lesson key to the injected two-argument
closure; the closure never captures an initialization-only key.

- [ ] **Step 3: Run the construction/Start test**

Run: `swift test --filter PresentationPlayerControllerTests/testConstructionDoesNotPersistAndStartDoes`

Expected: PASS.

- [ ] **Step 4: Write and run failing scene-playback and cancellation tests**

Use a suspended injected `waitForAdvance` and a `NarrationSpy`. Assert Play
starts one timer and narrates the current scene; Pause cancels both; Next,
Back, Replay, `deactivate()`, and changing the controller's lesson identity
cancel the prior task before any new work. Resolve a cancelled wait and assert
it cannot advance or persist stale state. After replacement, invoke Start and
assert the only new persistence tuple contains the replacement `LessonKey`.

Run: `swift test --filter PresentationPlayerControllerTests/testPlaybackCancellationBoundary`

Expected: FAIL because playback controls are missing.

Define `NarrationSpy` in the test against the intended
`PresentationNarrating` contract; this red compile may also report the missing
production protocol until Step 5.

- [ ] **Step 5: Add the narration protocol and test adapter**

Declare:

```swift
@MainActor
protocol PresentationNarrating: AnyObject {
    var isAvailable: Bool { get }
    func speak(_ text: String) async
    func stop()
}
```

Conform `NarrationSpeaker` and add only the spy needed by the test.

- [ ] **Step 6: Implement Play/Pause and one cancellable scene task**

Use one owned `Task<Void, Never>?`. Play animates from before to after, speaks
only when narration is enabled and locally available, then awaits the injected
advance. Pause/deactivate always cancel the task and call `stop()`. Guard every
post-await mutation with cancellation plus the captured lesson key and
presentation ID.

- [ ] **Step 7: Implement Back/Next/Replay using cancel-before-transition order**

Each command cancels playback, applies the Task 10 state transition, persists
once, updates the scene/phase, and only resumes playback after state is
consistent. Replay always selects scene zero.

- [ ] **Step 8: Run playback cancellation tests**

Run: `swift test --filter PresentationPlayerControllerTests/testPlaybackCancellationBoundary`

Expected: PASS with no stale advancement or duplicate write.

- [ ] **Step 9: Write and run failing final-scene, Skip, and preference tests**

Assert advancing after the final scene persists `.completed` and emits one
`handoffRequested` callback. Assert Skip persists `.skipped`, collapses, and
emits the same callback without creating learning evidence. Assert captions
remain present when narration is unavailable, transcript toggles without
progress, and Reduce Motion changes the controller directly from `.before` to
`.after` without an interpolation delay.

Run: `swift test --filter PresentationPlayerControllerTests/testCompletionSkipAndAccessibilityPreferences`

Expected: FAIL because completion and preference controls are missing.

- [ ] **Step 10: Implement final-scene, Skip, transcript, and preference controls**

Inject `reduceMotion: () -> Bool`. If narration is unavailable, force
`narrationEnabled` false for the session and keep captions/static descriptions
available. `handoffRequested` is navigation focus only and never answers a
question.

- [ ] **Step 11: Run all controller tests**

Run: `swift test --filter PresentationPlayerControllerTests`

Expected: all lifecycle, cancellation, persistence, and accessibility tests
PASS.

- [ ] **Step 12: Write and run a failing bounded-layout hosting test**

Host `LessonPresentationPlayer` at widths 680 and 980 with the longest pilot
caption/transcript. Assert its collapsed summary is at most 120 points high,
its expanded poster has a finite fitting height at most 320, and its controls do
not publish an infinite or zero width.

Run: `swift test --filter LessonPresentationPlayerLayoutTests`

Expected: FAIL because the player view is missing.

- [ ] **Step 12a: Write and run the failing rendered accessibility contract**

Use a recursive `NSAccessibility` helper on `NSHostingView` to require scene
number, playback state, focused item, result, persistent caption, static
description, and named keyboard controls. Host with Reduce Motion enabled and
require the authored after-state without an intermediate travel state.

Run: `swift test --filter LessonPresentationPlayerLayoutTests/testRenderedAccessibilityContract`

Expected: FAIL because player chrome, semantics, and static alternatives are
not implemented.

- [ ] **Step 13: Implement code-execution and value-binding visuals**

In `PresentationSceneVisual`, render code execution and value binding with
authored `PresentationCodeToken` text, rounded value cards, and focus rings.
Focused tokens are resolved by stable ID rather than substring guessing.

- [ ] **Step 14: Add output-flow animation and Reduce Motion fallback**

Render output flow with local arrows and cards. Use `matchedGeometryEffect`
only when Reduce Motion is off; when it is on, switch immediately between
authored before/after states with no travel or interpolation.

- [ ] **Step 15: Add the static fallback for future visual kinds**

Render branch, collection, web, packet, security, and diagram kinds as the
content-authored labeled static description/state, never a blank view. No
`WebView`, media URL, remote image, or network API is allowed.

- [ ] **Step 16: Implement poster and compact-summary chrome**

Render title/status, paused poster, Start/Skip/Transcript/Read deeper, and the
compact started/skipped/completed summary with Replay. Expansion alone must
not call a controller mutation.

- [ ] **Step 17: Implement active-scene controls and persistent caption**

Render the visual, always-visible caption, scene count, Back/Next,
Play/Pause, Replay, Skip, and narration toggle. Give each control a unique
keyboard shortcut, help string, and accessibility label/value.

- [ ] **Step 18: Implement bounded transcript and static alternative**

Use a bounded vertical `ScrollView` only inside the transcript section. Expose
the scene's static description and focused token/value/output/result in the
VoiceOver description.

- [ ] **Step 19: Run the rendered accessibility contract green**

Run: `swift test --filter LessonPresentationPlayerLayoutTests/testRenderedAccessibilityContract`

Expected: PASS for keyboard-named controls, VoiceOver content, captions,
static equivalents, and Reduce Motion.

- [ ] **Step 20: Run player layout and controller tests**

Run: `swift test --filter LessonPresentationPlayerLayoutTests`

Expected: both compact and expanded layouts satisfy the tested bounds.

Run: `swift test --filter PresentationPlayerControllerTests`

Expected: all controller tests remain green.

- [ ] **Step 21: Commit the offline animated player**

```bash
git add Sources/SwiftTutorApprentice/Services/NarrationSpeaker.swift \
  Sources/SwiftTutorApprentice/Services/PresentationPlayerController.swift \
  Sources/SwiftTutorApprentice/Views/PresentationSceneVisual.swift \
  Sources/SwiftTutorApprentice/Views/LessonPresentationPlayer.swift \
  Tests/SwiftTutorApprenticeTests/PresentationPlayerControllerTests.swift \
  Tests/SwiftTutorApprenticeTests/LessonPresentationPlayerLayoutTests.swift
git commit -m "feat: add offline animated lesson player"
```

### Task 12: Add the offline Understand AI Code exercise

**Files:**
- Create: `Sources/SwiftTutorApprentice/Services/AICodeReviewEvaluator.swift`
- Create: `Sources/SwiftTutorApprentice/Views/AICodeReviewView.swift`
- Test: `Tests/SwiftTutorApprenticeTests/AICodeReviewEvaluatorTests.swift`
- Test: `Tests/SwiftTutorApprenticeTests/AICodeReviewViewLayoutTests.swift`

- [ ] **Step 1: Write and run failing pure evaluator tests**

Assert `evaluate(exercise:answers:)` returns `.incomplete` with sorted missing
claim IDs until every claim has a learner True/False answer. For a complete
submission, assert per-claim correctness/explanation, total correct count, and
overall pass only when all claims are correct. Extra or duplicate answer IDs
are rejected rather than ignored.

Run: `swift test --filter AICodeReviewEvaluatorTests`

Expected: FAIL with missing `AICodeReviewEvaluator`.

- [ ] **Step 2: Implement only the pure evaluator contract**

Use typed `AICodeClaimAnswer`, `AICodeClaimFeedback`, and
`AICodeReviewEvaluation` values. The evaluator performs no network call,
executes no generated code, and never changes progress.

- [ ] **Step 3: Run evaluator tests**

Run: `swift test --filter AICodeReviewEvaluatorTests`

Expected: PASS.

- [ ] **Step 4: Write and run a failing bounded-layout test**

Host the view at width 680 with the longest pilot code and explanations. Assert
the code region and claim list have finite bounded fitting sizes, every claim
has separately labeled True/False controls, and feedback is absent before
Submit.

Run: `swift test --filter AICodeReviewViewLayoutTests`

Expected: FAIL because `AICodeReviewView` is missing.

- [ ] **Step 4a: Write and run the failing AI-view accessibility test**

Using the same recursive `NSAccessibility` helper, require each claim group
label, selected True/False value, hidden-before-submit feedback, disabled
default Submit while incomplete, and the generated code as one named read-only
element.

Run: `swift test --filter AICodeReviewViewLayoutTests/testAccessibilityAndSubmissionSemantics`

Expected: FAIL because the view semantics are missing.

- [ ] **Step 5a: Implement prompt, code, and answer controls**

Render the prompt, scrollable monospaced generated code, one True/False choice
per claim, and a disabled-until-complete Submit button. Keep answers local to
the view and do not invoke the optional remote `AICoach`.

- [ ] **Step 5b: Implement submission feedback and Retry**

After Submit, render per-claim evidence, the total, Retry, and a final "Verify
code; do not trust generation blindly" reminder. On complete submission call
`onSubmit(AICodeReviewEvaluation)` exactly once per Submit action; do not invoke
it when an answer is incomplete.

- [ ] **Step 5c: Add keyboard and VoiceOver semantics**

Give every claim a group label, expose selected True/False state and feedback,
make Submit the default action only when enabled, and keep the generated code
reachable as one read-only accessibility element.

- [ ] **Step 6: Run view and evaluator tests**

Run: `swift test --filter AICodeReviewViewLayoutTests`

Expected: the hosted view remains bounded and feedback gating passes.

Run: `swift test --filter AICodeReviewEvaluatorTests`

Expected: all pure evaluator tests remain green.

- [ ] **Step 7: Commit the offline AI-code exercise**

```bash
git add Sources/SwiftTutorApprentice/Services/AICodeReviewEvaluator.swift \
  Sources/SwiftTutorApprentice/Views/AICodeReviewView.swift \
  Tests/SwiftTutorApprenticeTests/AICodeReviewEvaluatorTests.swift \
  Tests/SwiftTutorApprenticeTests/AICodeReviewViewLayoutTests.swift
git commit -m "feat: add offline AI code review exercises"
```

## Chunk 4: Course Home, Stable Navigation, and Learning-Loop Integration

### Task 13: Add explicit Home/course routing and course-card presentation

**Files:**
- Modify: `Sources/SwiftTutorApprentice/AppModel.swift:22-328`
- Modify: `Sources/SwiftTutorApprentice/Services/AppSettings.swift:18-68`
- Modify: `Sources/SwiftTutorApprentice/Services/SwiftRunner.swift`
- Modify: `Sources/SwiftTutorApprentice/Services/AICoach.swift`
- Create: `Sources/SwiftTutorApprentice/Services/CancellableProcessRunner.swift`
- Create: `Sources/SwiftTutorApprentice/Models/CourseHomeCardModel.swift`
- Create: `Tests/SwiftTutorApprenticeTests/AppModelNavigationTests.swift`
- Create: `Tests/SwiftTutorApprenticeTests/CourseHomeCardModelTests.swift`
- Create: `Tests/SwiftTutorApprenticeTests/CancellableProcessRunnerTests.swift`

- [ ] **Step 1: Write failing root-route tests**

Declare expected `AppRoute` values in the test and assert a new `AppModel`
always starts at `.courseHome`, even when progress has a valid last Swift
lesson. Assert it does not mutate progress, lessons, code, or settings while
constructing.

- [ ] **Step 1a: Run the root-route test red**

Run: `swift test --filter AppModelNavigationTests/testEveryNewModelStartsAtCourseHomeWithoutMutation`

Expected: FAIL because explicit routing and dependency-injected construction
are missing.

- [ ] **Step 2a: Isolate `AppSettings` persistence for tests**

Give `AppSettings` an injected `UserDefaults = .standard` initializer and route
every property write through that retained instance so tests use an isolated
suite without changing production behavior.

- [ ] **Step 2b: Add injectable model stores and root route**

Add `enum AppRoute: Hashable { case courseHome, course(CourseID) }` and
`@Published private(set) var route: AppRoute = .courseHome`. Extend `AppModel`
initialization to accept `LessonStore`, `ProgressStore`, `AppSettings`, and a
`CourseContentRegistry`, with current defaults for production. Preserve the
existing forwarding subscriptions and integer compatibility APIs. Async
operation injection is introduced with cancellation in Step 6f.

- [ ] **Step 3: Run the root-route test**

Run: `swift test --filter AppModelNavigationTests/testEveryNewModelStartsAtCourseHomeWithoutMutation`

Expected: PASS.

- [ ] **Step 4: Write failing open-course destination tests**

Seed no activity, incomplete meaningful activity, completed last lesson, all
complete, invalid last lesson, and Coming next courses. Assert
`openCourse(_:)` uses Task 3 exactly, selects the returned `LessonKey`, records
no activity merely for opening, and leaves Coming next on Home with a
nonblocking availability message.

- [ ] **Step 4a: Run the open-course test red**

Run: `swift test --filter AppModelNavigationTests/testOpenCourseUsesDeterministicDestination`

Expected: FAIL because course navigation is missing.

- [ ] **Step 5: Implement Swift course entry and unavailable-course handling**

Add `@Published private(set) var selectedLessonKey: LessonKey?` and
`@Published private(set) var courseOpenError: String?`. Define
`LessonSelectionOrigin { courseEntry, programmatic, direct }` and an identified
`LessonSelectionTransaction` carrying key, origin, and monotonic generation.
Expose `selectLesson(_:origin:)`; it updates selected key and publishes exactly
one transaction atomically. Resolve ordered keys
through `CourseContentRegistry`, current progress through `ProgressStore`, and
Task 3's pure resolver, passing `hasMeaningfulActivity(in:)` and
`lastLessonKey(in:)` exactly. Set `.course(courseID)` only after a valid
destination exists. Keep `selectedLessonID` as a computed Swift-only
compatibility adapter until the remaining views migrate. Do not add
workspace-activity recording until the runner exposes a truthful persisted
outcome in Step 6b.

- [ ] **Step 6: Run open-course tests**

Run: `swift test --filter AppModelNavigationTests/testOpenCourseUsesDeterministicDestination`

Expected: all Start/Continue/Review and Coming next paths PASS.

- [ ] **Step 6a: Write workspace-persistence outcome tests**

Construct `SwiftRunner` with an injected temporary workspace URL. Assert invalid
Swift syntax still returns `workspaceWasSaved == true` when `main.swift` was
written, while a workspace path blocked by an existing regular file returns
`workspaceWasSaved == false` and never launches Swift.

- [ ] **Step 6a.1: Run the workspace-persistence test red**

Run: `swift test --filter CancellableProcessRunnerTests/testSwiftRunnerReportsWorkspacePersistenceSeparatelyFromExecution`

Expected: FAIL because `RunResult` does not distinguish persistence.

- [ ] **Step 6b: Implement the explicit persisted-workspace outcome**

Add `workspaceWasSaved: Bool` to `RunResult`, inject `workspaceURL` into
`SwiftRunner` with the current URL as production default, and set the field
immediately after the atomic source write. AppModel calls
`recordSavedWorkspaceActivity(for:)` only when that field is true, regardless
of compiler/runtime success.

- [ ] **Step 6c: Run the workspace-persistence outcome test**

Run: `swift test --filter CancellableProcessRunnerTests/testSwiftRunnerReportsWorkspacePersistenceSeparatelyFromExecution`

Expected: PASS for saved-invalid-code and failed-write cases.

- [ ] **Step 6d: Write a real child-process cancellation test**

Start `/bin/sleep 30` through `CancellableProcessRunner`, cancel its Swift task,
and assert the child terminates and the await returns within two seconds.
Separately assert captured stdout/stderr and exit status for `/usr/bin/printf`.

- [ ] **Step 6d.1: Run the child-process test red**

Run: `swift test --filter CancellableProcessRunnerTests/testCancellationTerminatesChildProcess`

Expected: FAIL with missing cancellable process service.

- [ ] **Step 6e.1: Implement race-free POSIX process-group launch**

Use `posix_spawn_file_actions` for stdout/stderr pipes and
`posix_spawnattr_setflags(...POSIX_SPAWN_SETPGROUP)` with process group 0 so the
child becomes group leader before exec, without a `setpgid` race. Launch only
fixed executable paths/argument arrays, collect both pipes concurrently, and
resume the async result exactly once. Do not add cancellation yet and never
invoke a shell string.

- [ ] **Step 6e.2: Add process-group cancellation**

Own each spawned PID/group inside a per-invocation handle protected against
duplicate termination. Use
`withTaskCancellationHandler` to send TERM, then bounded KILL fallback, to that
group so interpreter/CLI descendants cannot outlive the task. Close pipes,
reap the process, and resume exactly once. Never invoke a shell string; retain
fixed executable URLs and argument arrays.

- [ ] **Step 6f.1: Route Swift execution through the cancellable runner**

Replace SwiftRunner's blocking DispatchQueue bridge with the shared process
runner while preserving the saved-workspace result.

- [ ] **Step 6f.2: Route CLI AI through the cancellable runner**

Replace AICoach's CLI DispatchQueue bridge with the shared process runner. Keep
API AI on `URLSession.data(for:)`, which observes task cancellation.

- [ ] **Step 6f.3: Inject and own AppModel async operations**

Add `runCode: (String) async -> RunResult` and
`requestAI: (AICoachRequest) async -> AIResult`; define `AICoachRequest` as the
captured code, lesson, provider, command, API key, and model values. Production
defaults delegate to the services; tests use suspended closures. Add private
`runTask` and `aiTask` handles; each new request cancels its prior handle. Keep
the generation/key check so a cancellation race cannot publish into another
lesson. Call `recordSavedWorkspaceActivity` only from a result whose
`workspaceWasSaved` is true.

- [ ] **Step 6g: Run process and AppModel async tests**

Run: `swift test --filter CancellableProcessRunnerTests`

Expected: persistence, output, and real child termination tests PASS.

- [ ] **Step 7: Write failing cancellation/Home tests**

Start a walkthrough, injected suspended run, injected suspended AI request,
and registered presentation-cancellation spy. Assert
`selectLesson`, `goHome`, and course replacement each cancel every prior
transient task before changing identity; clear code/prediction/results/AI
response; preserve saved progress and workspace edits; and never retain a
course route after `goHome()`.

- [ ] **Step 7a: Run the cancellation/Home test red**

Run: `swift test --filter AppModelNavigationTests/testNavigationCancelsTransientLessonWork`

Expected: FAIL because navigation cancellation is incomplete.

- [ ] **Step 8a: Centralize task cancellation and stale-result suppression**

Add one `cancelTransientLessonWork()` boundary used by lesson, course, and Home
changes. Invalidate runner/AI results with a captured `LessonKey` generation so
late async results cannot enter a different lesson.

- [ ] **Step 8b: Add the workspace cancellation registration API**

Call the registered workspace cancellation closure before route or key
mutation. Expose
`registerWorkspaceCancellation(_:) -> UUID` and
`unregisterWorkspaceCancellation(_:)`; registration replacement cancels the
old owner and the model never retains a view/controller strongly.

- [ ] **Step 9: Run all model-navigation tests**

Run: `swift test --filter AppModelNavigationTests`

Expected: launch, destination, unavailable-course, and cancellation tests PASS.

- [ ] **Step 10: Write failing course-card truth tests**

Assert Swift shows released completion as `"X of N lessons complete"` and one
derived Start/Continue/Review label. Assert Web, Cybersecurity, and Networking
show `"Coming next"`, target credential, no percentage, no readiness claim,
and a disabled primary action. Assert no card text contains leaderboard, XP,
streak-loss, mastery, guaranteed job, or guaranteed certification language.

- [ ] **Step 10a: Run course-card tests red**

Run: `swift test --filter CourseHomeCardModelTests`

Expected: FAIL with missing `CourseHomeCardModel`.

- [ ] **Step 11: Implement pure course-card projection**

Project `CourseDefinition`, optional released provider, progress, and Task 3
destination into display-only card values. Never infer certification readiness
for `.pilot` or `.comingNext` content.

- [ ] **Step 12: Run course-card tests**

Run: `swift test --filter CourseHomeCardModelTests`

Expected: all availability and evidence-boundary tests PASS.

- [ ] **Step 13: Commit routing models**

```bash
git add Sources/SwiftTutorApprentice/AppModel.swift \
  Sources/SwiftTutorApprentice/Services/AppSettings.swift \
  Sources/SwiftTutorApprentice/Services/SwiftRunner.swift \
  Sources/SwiftTutorApprentice/Services/AICoach.swift \
  Sources/SwiftTutorApprentice/Services/CancellableProcessRunner.swift \
  Sources/SwiftTutorApprentice/Models/CourseHomeCardModel.swift \
  Tests/SwiftTutorApprenticeTests/AppModelNavigationTests.swift \
  Tests/SwiftTutorApprenticeTests/CourseHomeCardModelTests.swift \
  Tests/SwiftTutorApprenticeTests/CancellableProcessRunnerTests.swift
git commit -m "feat: add deterministic course navigation"
```

### Task 14: Build Course Home and separate course workspace roots

**Files:**
- Create: `Sources/SwiftTutorApprentice/Views/CourseHomeView.swift`
- Create: `Sources/SwiftTutorApprentice/Views/CourseWorkspaceView.swift`
- Modify: `Sources/SwiftTutorApprentice/ContentView.swift:18-84`
- Test: `Tests/SwiftTutorApprenticeTests/CourseRootLayoutTests.swift`

- [ ] **Step 1: Write failing root-identity layout tests**

Host Home and course workspace separately at 680x520 and 1280x860. Assert
finite fitting sizes, unique root accessibility identifiers
`course-home-root`/`course-workspace-root`, and Home cards for all four catalog
IDs. Require the Home scroll viewport frame to stay within 680x520 while its
document height may exceed the viewport. Construct `ContentView` with an
injected model and assert the model route selects exactly one root.

- [ ] **Step 1a: Run root-identity tests red**

Run: `swift test --filter CourseRootLayoutTests/testHomeAndWorkspaceAreSeparateBoundedRoots`

Expected: FAIL because the new views and injectable `ContentView` are missing.

- [ ] **Step 2: Implement the Course Home card grid**

Render the app purpose, zero-experience orientation, private-progress note, and
one accessible card per `CourseHomeCardModel`. Each card shows purpose,
credential target, availability, truthful progress, and one dominant action.
Wrap the complete Home content in one bounded outer vertical `ScrollView`; use
an adaptive grid that becomes one column at 680 width and never nests a
vertical scroll inside a card. Tag the viewport `course-home-scroll` and each
card `course-card-<raw CourseID>` for frame/accessibility tests.

- [ ] **Step 3: Implement the course workspace shell and Home action**

Move `NavigationSplitView` into `CourseWorkspaceView`. Put Home in the toolbar
with a stable keyboard shortcut and call `model.goHome()`. Keep the 680x520
minimum frame on the shared window, not on scroll content.

- [ ] **Step 4: Route `ContentView` between separate identities**

Give `ContentView` an initializer defaulting to `AppModel()` plus an internal
injected-model initializer for tests. After the one-time welcome sheet,
`switch model.route` between Course Home and a course workspace. Do not persist
or restore the root route.

- [ ] **Step 5a: Run root layout tests**

Run: `swift test --filter CourseRootLayoutTests`

Expected: both window sizes remain bounded and only the selected root exists.

- [ ] **Step 5b: Run model route regressions**

Run: `swift test --filter AppModelNavigationTests`

Expected: routing behavior remains green.

- [ ] **Step 6: Commit Course Home and root routing UI**

```bash
git add Sources/SwiftTutorApprentice/ContentView.swift \
  Sources/SwiftTutorApprentice/Views/CourseHomeView.swift \
  Sources/SwiftTutorApprentice/Views/CourseWorkspaceView.swift \
  Tests/SwiftTutorApprenticeTests/CourseRootLayoutTests.swift
git commit -m "feat: add course home experience"
```

### Task 15: Stabilize sidebar visibility and detail top positioning

**Files:**
- Create: `Sources/SwiftTutorApprentice/Services/LessonScrollCoordinator.swift`
- Create: `Sources/SwiftTutorApprentice/Views/ScrollViewportProbe.swift`
- Modify: `Sources/SwiftTutorApprentice/Views/LessonListSidebar.swift:10-116`
- Modify: `Sources/SwiftTutorApprentice/Views/CourseWorkspaceView.swift`
- Modify: `Sources/SwiftTutorApprentice/Views/LessonWorkspace.swift:13-501`
- Test: `Tests/SwiftTutorApprenticeTests/LessonScrollCoordinatorTests.swift`
- Test: `Tests/SwiftTutorApprenticeTests/CourseWorkspaceLayoutTests.swift`

- [ ] **Step 1: Write failing one-shot scroll-request tests**

Assert `LessonScrollCoordinator.select(_:origin:)` emits one sidebar-visibility
request for `.courseEntry` and `.programmatic`, none for `.direct` selection,
and exactly one new detail-top generation whenever the `LessonKey` changes.
Re-selecting the same key emits nothing. Native `List` keyboard selection uses
`.direct`; AppKit keeps its selected row visible without an artificial proxy
request.

- [ ] **Step 1a: Run coordinator tests red**

Run: `swift test --filter LessonScrollCoordinatorTests`

Expected: FAIL with missing coordinator.

- [ ] **Step 2: Implement the pure one-shot coordinator**

Use monotonic request IDs, not pixel offsets. Expose consumable
`sidebarVisibilityRequest` and `detailTopGeneration`; never store a scroll
position and never publish continuously from scroll callbacks. The only origins
are `.courseEntry`, `.programmatic`, and `.direct`; no input-modality inference
is attempted from `List(selection:)`.

- [ ] **Step 3: Run coordinator tests**

Run: `swift test --filter LessonScrollCoordinatorTests`

Expected: PASS.

- [ ] **Step 4: Write failing bounded-workspace hosting tests**

Host the course workspace at 680x520 and 1280x860. Assert the sidebar footer's
frame remains inside the window, the lesson collection receives the remaining
height above it, the detail top anchor exists, and the narrow-panel picker plus
selected panel fit without an outer vertical scroll. Repeat with first, middle,
and last keys. Require these identifiers and bounds at 680x520:

- `course-sidebar-footer`: height <= 120, minY >= 0, maxY <= 520;
- `lesson-sidebar-scroll`: maxY <= footer minY and height >= 200;
- `learning-scroll`: height <= 182 and entirely inside detail;
- `workspace-upper-pane` and `run-output-pane`: each height >= 80 and their
  union remains below the learning scroll;
- `narrow-panel-picker`: height <= 44;
- every reported frame has finite coordinates and lies inside the root.

- [ ] **Step 4a: Run bounded-workspace tests red**

Run: `swift test --filter CourseWorkspaceLayoutTests/testSidebarDetailAndFooterStayBounded`

Expected: FAIL against the unbounded/current identity structure.

- [ ] **Step 5: Convert the sidebar to `LessonKey` identity**

Bind selection to `selectedLessonKey`; tag rows with explicit provider keys;
keep the fixed footer outside the `List`; and use `ScrollViewReader` only to
consume a coordinator visibility request with
`scrollTo(key, anchor: .center)`. Do not scroll on ordinary body recomputation.
The binding setter calls `model.selectLesson(key, origin: .direct)`; course
entry calls `.courseEntry`; Continue/Review calls `.programmatic`. Observe only
the identified `selectionTransaction` and pass its preserved origin to the
coordinator—never infer origin from a second `selectedLessonKey.onChange`.
Tag the fixed footer `course-sidebar-footer` and the probed List scroll view
`lesson-sidebar-scroll`.

- [ ] **Step 6a: Add the bounded learning scroll**

Wrap only navigation-adjacent teaching content—the player, path stepper,
Recall, AI-code review, and banners—in a `ScrollViewReader` whose height is
bounded to at most 35 percent of available detail height. Do not wrap
`GeometryReader`, `HSplitView`, editor, coach, or run output in that scroll. Tag
the probed teaching viewport `learning-scroll`.

- [ ] **Step 6b: Add fresh detail identity and top-anchor consumption**

Put a stable `detail-top` anchor first, key the learning root by `LessonKey`,
and consume each detail generation after one `Task.yield()`. Tag the anchor
`detail-top` and never issue a top request from ordinary body recomputation.

- [ ] **Step 7.1: Bound the wide workspace split**

Measure the remaining detail height once and put the lesson/code/coach panels
and run output in a bounded `VSplitView`. Remove the current competing
`.frame(minHeight: 300)` workspace and `.frame(minHeight: 200)` output
requirements; use compressible per-pane minimums that fit together at 520
points. Retain bounded internal editor/output scroll views. Tag the upper split
`workspace-upper-pane` and output `run-output-pane`.

- [ ] **Step 7.2: Bound the narrow workspace panel**

Give the picker at most 44 points and the selected panel all remaining upper
split height. Remove flexible spacers or intrinsic-height paths that can push
the header above the window. Tag the picker `narrow-panel-picker` and expose all
pane frames to the hosting test.

- [ ] **Step 7a: Write the interactive scroll regression**

Add `ScrollViewportProbe`, an `NSViewRepresentable` that tags only its nearest
ancestor `NSScrollView` with a stable identifier and exposes no production
scroll mutation. In an `NSHostingView`, find those tagged scroll views,
programmatically select first/middle/last/first, pump the main run loop, and
assert the selected row intersects the sidebar viewport and `detail-top`
intersects the top 4 points of the learning viewport. Manually scroll the
sidebar away after selection, pump again, and assert its bounds origin stays
unchanged. Resize 1280x860 → 680x520 → 900x640 and repeat.

- [ ] **Step 7a.1: Run the interactive scroll regression red**

Run: `swift test --filter CourseWorkspaceLayoutTests/testRepeatedSelectionResizeAndManualScrollDoNotBottomStick`

Expected: FAIL until the probes and one-shot view wiring are complete.

- [ ] **Step 7b: Wire viewport probes and satisfy the interaction contract**

Verify the List/learning probes and every footer/pane/picker/row/top identifier
from Steps 5-7 is present, then consume each coordinator request exactly once
after mount. Do not add timers, persisted offsets, or on-scroll feedback that
could reissue a request.

- [ ] **Step 7c: Run the interactive scroll regression green**

Run: `swift test --filter CourseWorkspaceLayoutTests/testRepeatedSelectionResizeAndManualScrollDoNotBottomStick`

Expected: all selection, manual-scroll, and resize assertions PASS.

- [ ] **Step 8a: Run coordinator regressions**

Run: `swift test --filter LessonScrollCoordinatorTests`

Expected: one-shot selection behavior passes.

- [ ] **Step 8b: Run workspace layout regressions**

Run: `swift test --filter CourseWorkspaceLayoutTests`

Expected: first/middle/last and both window sizes remain bounded.

- [ ] **Step 8c: Run stage-stepper layout regression**

Run: `swift test --filter LessonStageStepperLayoutTests`

Expected: the compact strip regression remains green.

- [ ] **Step 9: Commit stable course scrolling**

```bash
git add Sources/SwiftTutorApprentice/Services/LessonScrollCoordinator.swift \
  Sources/SwiftTutorApprentice/Views/ScrollViewportProbe.swift \
  Sources/SwiftTutorApprentice/Views/LessonListSidebar.swift \
  Sources/SwiftTutorApprentice/Views/CourseWorkspaceView.swift \
  Sources/SwiftTutorApprentice/Views/LessonWorkspace.swift \
  Tests/SwiftTutorApprenticeTests/LessonScrollCoordinatorTests.swift \
  Tests/SwiftTutorApprenticeTests/CourseWorkspaceLayoutTests.swift
git commit -m "fix: stabilize course workspace scrolling"
```

### Task 16: Integrate Watch, Recall, Modify, AI review, and Practice/Run

**Files:**
- Create: `Sources/SwiftTutorApprentice/Services/LessonWorkspaceSession.swift`
- Create: `Sources/SwiftTutorApprentice/Views/LessonRecallView.swift`
- Modify: `Sources/SwiftTutorApprentice/Views/LessonWorkspace.swift:13-501`
- Modify: `Sources/SwiftTutorApprentice/Views/LessonStageStepper.swift:10-148`
- Modify: `Sources/SwiftTutorApprentice/Views/DeepLessonView.swift`
- Test: `Tests/SwiftTutorApprenticeTests/LessonLearningLoopTests.swift`
- Modify: `Tests/SwiftTutorApprenticeTests/LessonStageStepperLayoutTests.swift`

- [ ] **Step 1: Write failing first-surface/legacy policy tests**

Assert a pilot lesson with no saved presentation state chooses an expanded
paused poster; opening alone writes nothing; a legacy completed/Deep-viewed
lesson still gets that poster; returning started/skipped/completed states use
Task 10 entry modes; and a lesson without presentation goes directly to the
existing workspace.

- [ ] **Step 1a: Run first-surface policy tests red**

Run: `swift test --filter LessonLearningLoopTests/testInitialLessonSurfacePolicy`

Expected: FAIL because the workspace has no presentation surface policy.

- [ ] **Step 2a: Add a reference-type workspace session**

Move `LessonStagePresentation` and `ActiveLessonStage` out of private view state
into `LessonWorkspaceSession.swift`. Create
`LessonWorkspaceSession: ObservableObject` with published optional controller
and `activeLessonStage`. Its
`activate(for:presentation:savedState:persist:)` deactivates the old controller
before replacement; `cancel()` deactivates the controller and clears the active
sheet in one reference-type boundary. Own exactly one session as `@StateObject`
in `LessonWorkspace` and bind sheets to `$session.activeLessonStage`.

- [ ] **Step 2b: Register the whole workspace cancellation boundary**

On appear register `{ [weak session] in session?.cancel() }` with AppModel and
retain its token. On disappear unregister then call `session.cancel()`. The
selected-key change activates the new session controller only after AppModel invokes this
old-workspace boundary and mutates identity.

- [ ] **Step 2a: Embed the owned player directly below navigation/status**

Use saved state and keyed `progress.setPresentationState`. Place
`LessonPresentationPlayer` before the stage stepper and panels. Wire its Read
deeper callback explicitly to `session.activeLessonStage = .deepLesson(...)` through
`openDeepLessonManually`; wire Replay/Start/Skip only to the controller.
Expansion and poster display do not write.

- [ ] **Step 3: Remove automatic Deep Lesson presentation**

Delete `scheduledDeepLessonTask`, initial/deferred auto-presentation flags, and
all scheduling methods. Keep Deep Lesson reachable only from the player's
explicit Read deeper action. Preserve its existing viewed/Recall recording
callbacks; the stage stepper's Watch action controls presentation Replay/Resume,
not the written Deep Lesson.

- [ ] **Step 4: Run first-surface policy tests**

Run: `swift test --filter LessonLearningLoopTests/testInitialLessonSurfacePolicy`

Expected: all first/return/legacy/custom surface cases PASS.

- [ ] **Step 5: Write failing Recall handoff tests**

Assert presentation completion and Skip focus the linked Recall prompt without
answering it; choosing/submitting an answer records the existing first-answer
Recall event once; Continue opens Modify when present and otherwise focuses the
Practice/Run panel. Assert incorrect Recall does not block learning.

- [ ] **Step 5a: Run Recall handoff tests red**

Run: `swift test --filter LessonLearningLoopTests/testPresentationHandsOffWithoutAnsweringRecall`

Expected: FAIL because standalone Recall and focus handoff are missing.

- [ ] **Step 6a: Implement the reusable Recall view**

Extract/reuse the current Deep Lesson recall prompt semantics in
`LessonRecallView`. Give the linked prompt a stable focus target and submit
callback. Keep explanations available after an answer.

- [ ] **Step 6b: Replace Deep Lesson's private Recall rendering**

Use `LessonRecallView` inside DeepLessonView with the identical question ID and
persistence callback, preserving first-answer-wins behavior from both surfaces.

- [ ] **Step 7a: Wire one-shot player handoff to Recall**

Use `@FocusState` and a one-shot scroll target. Skip/completion requests focus;
Recall submission records only Recall.

- [ ] **Step 7b: Preserve Modify and Practice/Run confirmation flow**

Continue opens the existing `ModifyTaskView`; Modify success updates the keyed
stage event and returns to the existing editor/run workspace only through its
existing explicit Replace Editor confirmation. Preserve the different-editor
warning; passing Modify never silently overwrites code or dismisses before the
learner chooses.

- [ ] **Step 8: Run Recall handoff tests**

Run: `swift test --filter LessonLearningLoopTests/testPresentationHandsOffWithoutAnsweringRecall`

Expected: PASS with independent presentation, Recall, Modify, and completion
evidence.

- [ ] **Step 9: Write failing AI-attempt integration tests**

Submit one failed and one passed evaluation with injected attempt IDs and a
fixed clock. Assert each Submit records one immutable `AssessmentAttempt` with lesson key, activity
and variant IDs, presentation concept/objective mappings, `.none` scaffold,
content revision, deterministic `submittedAt`, and result. The first submission
for an item variant has `wasPreviouslySeen == false`; later submissions derive
true from prior persisted attempts. Create one new ID once per Submit and retain
that complete attempt for save retry; re-recording the same attempt ID is
idempotent. Watching or opening the exercise records none.

- [ ] **Step 9a: Run AI-attempt tests red**

Run: `swift test --filter LessonLearningLoopTests/testAICodeReviewRecordsOnlySubmittedAttempts`

Expected: FAIL because the exercise is not wired to progress.

- [ ] **Step 10a: Embed the pilot AI review without side effects on open**

Place `AICodeReviewView` after Recall for the three pilot lessons. Opening or
answering without Submit does not touch progress.

- [ ] **Step 10b: Construct complete deterministic assessment attempts**

Inject an attempt-ID factory and clock at the
`LessonWorkspaceSession`/workspace boundary. Use authored concept/objective
mappings and derive `wasPreviouslySeen` from prior item-variant attempts.

- [ ] **Step 10c: Persist one retained attempt per Submit**

Call `progress.record(_:)` only from the complete submission callback. Retain
the constructed attempt until persistence succeeds so Retry never regenerates
identity or time.

- [ ] **Step 11: Run AI-attempt integration tests**

Run: `swift test --filter LessonLearningLoopTests/testAICodeReviewRecordsOnlySubmittedAttempts`

Expected: PASS.

- [ ] **Step 12: Update the compact learning-path stepper**

Show Watch, Recall, Modify, and Practice/Run in that order. Watch and Read
deeper remain replayable, but Read deeper stays inside player chrome rather than
becoming a fifth stage. No stage visually locks the next. Use status text, not
color alone, and preserve the bounded horizontal fallback.

- [ ] **Step 13a: Run learning-loop regressions**

Run: `swift test --filter LessonLearningLoopTests`

Expected: all pilot, legacy-completion, and no-presentation paths PASS.

- [ ] **Step 13b: Run stage-stepper regression**

Run: `swift test --filter LessonStageStepperLayoutTests`

Expected: updated four-stage strip stays at most 100 points tall at width 360.

- [ ] **Step 13c: Run written Deep Lesson regressions**

Run: `swift test --filter DeepLessonPilotContentTests`

Expected: existing written content remains intact and optional.

- [ ] **Step 14: Commit the integrated learning loop**

```bash
git add Sources/SwiftTutorApprentice/Views/LessonRecallView.swift \
  Sources/SwiftTutorApprentice/Services/LessonWorkspaceSession.swift \
  Sources/SwiftTutorApprentice/Views/LessonWorkspace.swift \
  Sources/SwiftTutorApprentice/Views/LessonStageStepper.swift \
  Sources/SwiftTutorApprentice/Views/DeepLessonView.swift \
  Tests/SwiftTutorApprenticeTests/LessonLearningLoopTests.swift \
  Tests/SwiftTutorApprenticeTests/LessonStageStepperLayoutTests.swift
git commit -m "feat: integrate the active lesson loop"
```

### Task 17: Finish beginner onboarding and recoverable local errors

**Files:**
- Modify: `Sources/SwiftTutorApprentice/Services/ProgressStore.swift`
- Modify: `Sources/SwiftTutorApprentice/Services/LessonStore.swift`
- Modify: `Sources/SwiftTutorApprentice/Views/WelcomeView.swift:20-84`
- Modify: `Sources/SwiftTutorApprentice/Views/LessonWorkspace.swift`
- Modify: `Sources/SwiftTutorApprentice/Views/LessonListSidebar.swift`
- Test: `Tests/SwiftTutorApprenticeTests/OnboardingAndErrorViewTests.swift`

- [ ] **Step 1: Write failing beginner-onboarding copy tests**

Assert the welcome surface says no experience is required, introduces Course
Home and the Watch → Recall → Modify → Practice/Run loop, names offline/local
execution and private progress, and uses `"Explore courses"` as its action.
Assert it does not promise certification or job outcomes. Host it inside a
680x520 proposal and assert the sheet is at most 500 points high, its action is
inside the visible frame, and the orientation steps use one bounded internal
scroll rather than the current fixed 560-point height.

- [ ] **Step 1a: Run onboarding tests red**

Run: `swift test --filter OnboardingAndErrorViewTests/testWelcomeOrientsANewBeginnerTruthfully`

Expected: FAIL against current Swift-only copy.

- [ ] **Step 2a: Update beginner welcome copy**

Keep `hasSeenWelcome` behavior and interactive-dismiss protection. Update only
the zero-experience, four-course, offline/private, and learning-loop content;
the action dismisses to Course Home and never opens a lesson directly.

- [ ] **Step 2b: Bound the Welcome layout at minimum window size**

Replace the fixed 560-point height with a maximum 500-point container. Put only
the orientation-step region in one vertical ScrollView, keep header/action
fixed inside the sheet, and tag the action for the hosting frame assertion.

- [ ] **Step 3: Run onboarding tests**

Run: `swift test --filter OnboardingAndErrorViewTests/testWelcomeOrientsANewBeginnerTruthfully`

Expected: PASS.

- [ ] **Step 4: Write failing corrupt/save-error action tests**

Host progress and lesson banners for unsupported, corrupt, and failed-save
states. Assert unsupported/corrupt are clearly read-only; save failure exposes
Retry and Reveal File; Retry calls `progress.retrySave()`; Reveal calls an
injected closure with the exact progress/lesson URL; and ordinary learning
surfaces remain available.

- [ ] **Step 4a: Run local-error action tests red**

Run: `swift test --filter OnboardingAndErrorViewTests/testLocalPersistenceErrorsAreRecoverableAndSpecific`

Expected: FAIL because current banners conflate errors and lack actions.

- [ ] **Step 5a: Expose read-only store persistence URLs**

Add read-only `persistenceURL` properties to both stores without changing their
write path or fail-closed behavior.

- [ ] **Step 5b: Generalize read-only and save-error banner copy**

Use the generalized lesson-content gate from Task 8 and `ProgressStore`'s
future/corrupt/save flags. Keep byte-preserving states nonmutating. Expose Retry
only for a retained in-memory save failure.

- [ ] **Step 5c: Wire Retry and injected Reveal File actions**

Inject Reveal File through the workspace/sidebar rather than calling
`NSWorkspace` in tests. Production passes the exact `persistenceURL` to
`NSWorkspace.shared.activateFileViewerSelecting`; tests use a capturing
closure. Retry calls only the appropriate retained-state save method.

- [ ] **Step 6a: Run error-view tests**

Run: `swift test --filter OnboardingAndErrorViewTests`

Expected: all copy, action, and availability tests PASS.

- [ ] **Step 6b: Run progress migration regressions**

Run: `swift test --filter ProgressStoreMigrationTests`

Expected: all byte-preservation and retry tests remain green.

- [ ] **Step 6c: Run lesson migration regressions**

Run: `swift test --filter LessonStoreMigrationTests`

Expected: all lesson preservation tests remain green.

- [ ] **Step 7: Commit onboarding and local recovery UI**

```bash
git add Sources/SwiftTutorApprentice/Views/WelcomeView.swift \
  Sources/SwiftTutorApprentice/Services/ProgressStore.swift \
  Sources/SwiftTutorApprentice/Services/LessonStore.swift \
  Sources/SwiftTutorApprentice/Views/LessonWorkspace.swift \
  Sources/SwiftTutorApprentice/Views/LessonListSidebar.swift \
  Tests/SwiftTutorApprenticeTests/OnboardingAndErrorViewTests.swift
git commit -m "feat: improve onboarding and local recovery"
```

## Chunk 5: Automated Gates, Real App Proof, Documentation, and Merge

### Task 18: Add repeatable open-source CI and bundle-freshness verification

**Files:**
- Modify: `Scripts/build-app.sh`
- Create: `.github/workflows/ci.yml`
- Create: `Scripts/verify-app-bundle.sh`
- Create: `Scripts/course-platform-smoke-state.sh`
- Create: `Tests/SwiftTutorApprenticeTests/Fixtures/future-progress.json`
- Create: `Tests/SwiftTutorApprenticeTests/Fixtures/corrupt-version-3-progress.json`
- Create: `Tests/SwiftTutorApprenticeTests/OfflineCoreContractTests.swift`

- [ ] **Step 1: Write and run the failing offline-core contract test**

Assert every bundled pilot presentation uses authored local states/transcript,
contains no `http://`, `https://`, media URL, or remote asset field, and can be
constructed/evaluated with no AI setting or API key. Assert Course Home and
all four catalog records also construct while networking is unavailable.

Run: `swift test --filter OfflineCoreContractTests`

Expected: FAIL until the test fixture and all new bundled content are wired.

- [ ] **Step 2: Make only the bundled core satisfy the offline contract**

Remove any accidental remote dependency from course catalog display,
presentation playback, narration, AI-code review, progress, and Swift
execution. Certification source URLs are inert reference strings and must not
be fetched by core UI. Keep the optional user-triggered `AICoach` behavior
separate and off by default.

- [ ] **Step 3: Run the offline-core and full suites**

Run: `swift test --filter OfflineCoreContractTests`

Expected: PASS.

Run: `swift test`

Expected: every test passes with 0 failures.

- [ ] **Step 4: Write the failing bundle-verifier shell checks**

Create `Scripts/verify-app-bundle.sh` with `set -euo pipefail`. Before the app
is built, run it and require a clear failure naming the missing bundle.

Run: `bash Scripts/verify-app-bundle.sh`

Expected: nonzero exit with `dist/SwiftTutor Apprentice.app is missing`.

- [ ] **Step 5: Implement deterministic bundle verification**

Update `build-app.sh` so it must:

- hash the release binary and copied bundle executable before signing and fail
  unless those hashes are identical;
- write both that unsigned SHA and `git rev-parse HEAD` to
  `Contents/Resources/BuildManifest.plist`;
- require ad-hoc `codesign` success instead of printing and continuing.

Then make the verifier:

- require the bundle, executable, Info.plist, and expected bundle ID;
- run `codesign --verify --deep --strict`;
- require the signed `BuildManifest.plist` and assert its source commit equals
  current `git rev-parse HEAD` and its unsigned SHA is a 64-digit hex value;
- use `codesign -d --verbose=4` plus signature verification to prove the signed
  executable/resources have not changed since that manifest was sealed;
- reject a bundle older than the current source commit;
- print the verified bundle path, signed executable SHA, manifest unsigned SHA,
  and source commit only after every check passes.

Do not compare the unsigned SwiftPM binary directly to the post-signing Mach-O.

- [ ] **Step 6: Build and verify the release bundle**

Run: `./Scripts/build-app.sh`

Expected: release build succeeds and assembles
`dist/SwiftTutor Apprentice.app`.

Run: `bash Scripts/verify-app-bundle.sh`

Expected: codesign, bundle ID, timestamp, and executable hash all PASS.

- [ ] **Step 7: Add public macOS CI**

Create one least-privilege GitHub Actions workflow triggered by pull requests
and pushes to `main`, with `permissions: contents: read`, concurrency
cancellation, a current `macos-14` runner, checkout, `swift test`,
`swift build -c release`, `./Scripts/build-app.sh`, and
`bash Scripts/verify-app-bundle.sh`. Do not add secrets or publish artifacts.

- [ ] **Step 7a: Implement guarded smoke-state commands and literal fixtures**

Create literal `future-progress.json` with a v4 incompatible payload and
`corrupt-version-3-progress.json` with a version-3 envelope plus deliberately
malformed payload. Implement these exact script commands:

```text
course-platform-smoke-state.sh backup
course-platform-smoke-state.sh clean <session>
course-platform-smoke-state.sh legacy <session>
course-platform-smoke-state.sh future-progress <session>
course-platform-smoke-state.sh future-lessons <session>
course-platform-smoke-state.sh corrupt-progress <session>
course-platform-smoke-state.sh snapshot <session> <app-state-file> <label>
course-platform-smoke-state.sh assert-unchanged <session> <app-state-file> <label>
course-platform-smoke-state.sh restore <session>
```

`backup` uses `mktemp -d "${TMPDIR%/}/SwiftTutorApprentice-smoke.XXXXXX"`,
immediately `chmod 700`, records a random session marker, copies data/workspace,
exports preferences, and prints only the absolute session path. Every mutating
command uses `set -euo pipefail`, rejects paths outside that system-temp prefix,
requires the marker, quits the app, and affects only the three documented app
surfaces. Fixture commands first install a deterministic `main.swift` and
defaults seed, then copy the named checked-in fixture. `restore` leaves the
backup in place on any copy/import/diff failure, normalizes and compares the
restored preferences, compares data/workspace recursively, and deletes the
session only after every comparison succeeds.
`snapshot` accepts only a file under the app's Application Support directory,
stores its SHA-256 under the protected session by a safe alphanumeric label,
and `assert-unchanged` recomputes and compares that snapshot in a fresh shell.

- [ ] **Step 8: Validate CI syntax and local commands**

Run: `bash -n Scripts/build-app.sh`

Expected: no output and exit status 0.

Run: `bash -n Scripts/verify-app-bundle.sh`

Expected: no output and exit status 0.

Run: `bash -n Scripts/course-platform-smoke-state.sh`

Expected: no output and exit status 0.

Run: `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci.yml")'`

Expected: no YAML syntax error and exit status 0.

Run: `git diff --check`

Expected: no output and exit status 0.

- [ ] **Step 9: Commit automated release gates**

```bash
git add .github/workflows/ci.yml \
  Scripts/build-app.sh \
  Scripts/verify-app-bundle.sh \
  Scripts/course-platform-smoke-state.sh \
  Tests/SwiftTutorApprenticeTests/Fixtures/future-progress.json \
  Tests/SwiftTutorApprenticeTests/Fixtures/corrupt-version-3-progress.json \
  Tests/SwiftTutorApprenticeTests/OfflineCoreContractTests.swift
git commit -m "ci: verify tests and app bundle"
```

### Task 19: Perform the backed-up real-app smoke test

**Files:**
- Create: `docs/testing/course-platform-milestone-1-smoke.md`

- [ ] **Step 1: Record the pre-smoke evidence and quit the app**

Run the complete gate from the worktree root:

```bash
swift test
swift build -c release
./Scripts/build-app.sh
bash Scripts/verify-app-bundle.sh
osascript -e 'tell application id "com.local.swifttutorapprentice" to quit' 2>/dev/null || true
```

Expected: tests/build/bundle verification pass and no app process remains.
Record commands, pass counts, commit SHA, bundle SHA, and date in the smoke doc.

- [ ] **Step 2: Back up all real learner state before fixture tests**

Create the permission-restricted system-temp backup and record the only printed
absolute session path in the smoke document:

```bash
bash Scripts/course-platform-smoke-state.sh backup
```

Expected: one path under `${TMPDIR}`; permissions are 700 and the script has
verified every existing learner surface was copied. Never paste its contents
or preference values into the smoke doc.

- [ ] **Step 2a: Install a truly clean disposable state**

Run with the recorded path:

```bash
bash Scripts/course-platform-smoke-state.sh clean "<recorded absolute session path>"
```

Expected: Application Support, Workspace, and app defaults are absent, while
the permission-restricted backup remains intact outside the repository.

- [ ] **Step 3: Verify clean first launch and Course Home**

With networking disabled, launch only
`dist/SwiftTutor Apprentice.app`. Complete Welcome if present and verify Course
Home appears, all four courses and credential targets are visible, Swift has a
truthful Start/Continue/Review action, Coming next cards show no percentage or
readiness, and no lesson or prior scroll position is restored as the root.
Capture the observed result in the smoke doc.

- [ ] **Step 4: Verify the real animated Lesson 1-3 loop offline**

Open Swift and check each of Lessons 1-3: the player is first and paused; Start
produces actual SwiftUI state changes; captions remain visible; Back/Next,
Play/Pause, Replay, transcript, narration, Reduce Motion, keyboard traversal,
and VoiceOver descriptions work; Read deeper is optional and never auto-opens;
Skip/completion hands off to Recall; Modify and Practice/Run remain usable; the
AI-code review gives local evidence without a network request.

- [ ] **Step 5: Reproduce the original scroll regression path**

At both minimum and default window sizes, repeatedly select first, last, first,
middle, and last lessons with mouse and arrow keys. After every selection,
confirm the course header, player, and first detail content are visible at the
top; the selected sidebar row is visible once; manual sidebar scrolling is not
pulled back; the footer never clips; and narrow panel changes stay at their own
top. Return Home, re-enter Swift, quit, and relaunch; confirm neither surface is
bottom-stuck or clipped.

- [ ] **Step 6: Verify migration and byte-preservation fixtures**

Quit, install copies of the checked-in legacy lesson/progress fixtures, and
launch the bundle. Verify custom/edited lessons, completion, Deep Lesson,
Modify, Recall, settings, and workspace code survive. Separately install future
and corrupt copies, attempt every mutation, quit, and compare SHA-256 hashes to
confirm exact bytes remain. Never use the backup itself as a fixture.

Run each scenario from a clean disposable state with the recorded session:

```bash
SESSION="<recorded absolute session path>"
STATE="$HOME/Library/Application Support/SwiftTutorApprentice"
bash Scripts/course-platform-smoke-state.sh legacy "$SESSION"
open "dist/SwiftTutor Apprentice.app"
```

Perform the legacy migration checks, quit, then run each protected case:

```bash
SESSION="<recorded absolute session path>"
STATE="$HOME/Library/Application Support/SwiftTutorApprentice"
bash Scripts/course-platform-smoke-state.sh future-progress "$SESSION"
bash Scripts/course-platform-smoke-state.sh snapshot "$SESSION" "$STATE/progress.json" future-progress
open "dist/SwiftTutor Apprentice.app"
```

Attempt completion, presentation, Recall, Modify, reset, and Retry in the real
app; quit, then require byte equality:

```bash
SESSION="<recorded absolute session path>"
STATE="$HOME/Library/Application Support/SwiftTutorApprentice"
osascript -e 'tell application id "com.local.swifttutorapprentice" to quit'
bash Scripts/course-platform-smoke-state.sh assert-unchanged "$SESSION" "$STATE/progress.json" future-progress
bash Scripts/course-platform-smoke-state.sh corrupt-progress "$SESSION"
bash Scripts/course-platform-smoke-state.sh snapshot "$SESSION" "$STATE/progress.json" corrupt-progress
open "dist/SwiftTutor Apprentice.app"
```

Repeat every mutation, quit, assert the protected corrupt snapshot unchanged,
then run the future-lesson case and protect `lessons.json` the same way:

```bash
SESSION="<recorded absolute session path>"
STATE="$HOME/Library/Application Support/SwiftTutorApprentice"
osascript -e 'tell application id "com.local.swifttutorapprentice" to quit'
bash Scripts/course-platform-smoke-state.sh assert-unchanged "$SESSION" "$STATE/progress.json" corrupt-progress
bash Scripts/course-platform-smoke-state.sh future-lessons "$SESSION"
bash Scripts/course-platform-smoke-state.sh snapshot "$SESSION" "$STATE/lessons.json" future-lessons
open "dist/SwiftTutor Apprentice.app"
```

Attempt add/edit/delete/move/restore, quit, then run in a fresh shell:

```bash
SESSION="<recorded absolute session path>"
STATE="$HOME/Library/Application Support/SwiftTutorApprentice"
osascript -e 'tell application id "com.local.swifttutorapprentice" to quit'
bash Scripts/course-platform-smoke-state.sh assert-unchanged "$SESSION" "$STATE/lessons.json" future-lessons
```

Expected: every `assert-unchanged` exits 0. Record only hashes and pass/fail,
never fixture contents containing learner data.

- [ ] **Step 7: Restore the original learner state even after a failed smoke**

Quit the app. Remove only the disposable test state; restore each marked data,
workspace, and defaults surface; compare restored hashes/file counts to the
backup; then delete the unique backup directory. If restoration verification
fails, stop and report the blocker—do not continue to merge.

Run with the recorded path substituted exactly:

```bash
bash Scripts/course-platform-smoke-state.sh restore "<recorded absolute session path>"
```

Expected: exit 0 only after data/workspace/preferences comparisons pass and the
session is deleted. Any nonzero exit leaves the backup untouched and blocks
merge.

- [ ] **Step 8: Relaunch the restored real app once**

Launch the bundle and confirm the user's original lessons/progress/settings are
present and the app still enters Course Home. Quit it, then mark every smoke
criterion pass/fail in `docs/testing/course-platform-milestone-1-smoke.md`.

- [ ] **Step 9: Commit the completed smoke evidence**

```bash
git add docs/testing/course-platform-milestone-1-smoke.md
git commit -m "test: record course platform app smoke"
```

### Task 20: Update public documentation, review, merge, and rebuild main

**Files:**
- Modify: `README.md`
- Modify: `docs/learning-evidence.md`
- Modify: `docs/superpowers/plans/2026-07-10-course-platform-milestone-1.md`

- [ ] **Step 1: Update user-facing shipped behavior only after smoke passes**

Replace the README's old auto-opening Deep Lesson pilot description with Course
Home, four-course roadmap, the embedded offline animated Swift Lessons 1-3,
Watch → Recall → Modify → Practice/Run, optional Read deeper, AI-code review,
private progress, and build/open instructions. Keep certification phrasing as
the approved end-state goal, not a Milestone 1 guarantee. Update learning
evidence with the implemented presentation/active-practice boundary.

- [ ] **Step 2: Mark this plan's completed checkboxes and evidence links**

Check only steps actually evidenced. Link the final smoke document and leave
the later full Web/Cybersecurity/Networking/certification program visibly
in-scope and unimplemented rather than shrinking the approved program.

- [ ] **Step 3: Run the final pre-review gate**

Run: `swift test`

Expected: 0 failures.

Run: `swift build -c release`

Expected: release build succeeds.

Run: `./Scripts/build-app.sh && bash Scripts/verify-app-bundle.sh`

Expected: the worktree bundle is freshly rebuilt and verified.

Run: `git diff --check && git status --short && git log --oneline --decorate -20`

Expected: no whitespace errors, only intended changes, and focused task commits.

- [ ] **Step 4: Request code and product review**

Use `@requesting-code-review` for the complete branch diff against `main`.
Resolve every validated issue test-first, rerun the final gate, and require the
reviewer to confirm migration safety, scroll stability, accessibility, offline
core behavior, and no scope shrinkage.

- [ ] **Step 5: Commit final documentation**

```bash
git add README.md docs/learning-evidence.md \
  docs/superpowers/plans/2026-07-10-course-platform-milestone-1.md
git commit -m "docs: explain course platform milestone one"
```

- [ ] **Step 5a: Rebuild the gate at the final documentation commit**

Run: `swift test`

Expected: 0 failures.

Run: `swift build -c release`

Expected: release build succeeds.

Run: `./Scripts/build-app.sh`

Expected: the bundle manifest records the new documentation commit at `HEAD`.

Run: `bash Scripts/verify-app-bundle.sh`

Expected: signature, sealed manifest source commit, and timestamp all match the
actual feature-branch tip that will be merged.

Run: `git status --short`

Expected: no tracked changes.

- [ ] **Step 6: Merge the reviewed implementation into local `main`**

Use `@finishing-a-development-branch`. Require clean worktree and green final
gate, fetch `origin`, update local `main` without destructive reset, and merge
`agent/course-platform-m1` with an explicit merge commit. If `origin/main`
advanced or conflicts occur, stop and reconcile without discarding either
side. Push `main` only after the local merge gate passes.

- [ ] **Step 7: Rebuild and verify the app from merged `main`**

From `/Users/andreelliott/Developer/SwiftTutorApprentice` run:

```bash
swift test
./Scripts/build-app.sh
bash Scripts/verify-app-bundle.sh
git status --short
```

Expected: main tests pass; `dist/SwiftTutor Apprentice.app` contains the same
verified release executable as merged main; and tracked files are clean. Launch
that exact main bundle once and confirm Course Home before reporting the app
updated.

- [ ] **Step 8: Push public main and verify GitHub state**

Push the reviewed merge, confirm
`https://github.com/0xFlan/SwiftTutorApprentice` remains public, the CI run is
green, the MIT license and contribution/security docs remain visible, and the
README describes the verified shipped milestone accurately.
