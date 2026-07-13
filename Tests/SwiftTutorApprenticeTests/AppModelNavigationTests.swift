import XCTest
@testable import SwiftTutorApprentice

@MainActor
final class AppModelNavigationTests: XCTestCase {
    func testCourseHomeProjectionFailsClosedWhenInjectedSwiftProviderIsMissing() throws {
        let fixture = try ModelFixture()
        let model = AppModel(
            store: fixture.lessons,
            progress: fixture.progress,
            settings: fixture.settings,
            contentRegistry: CourseContentRegistry(providers: [:])
        )

        let swiftCard = try XCTUnwrap(
            model.courseHomeCards().first { $0.id == .swiftDevelopment }
        )
        XCTAssertEqual(swiftCard.availabilityText, "Content unavailable")
        XCTAssertEqual(swiftCard.primaryActionLabel, "Unavailable")
        XCTAssertFalse(swiftCard.isPrimaryActionEnabled)
        XCTAssertNil(swiftCard.progressText)
        XCTAssertNil(swiftCard.destination)

        model.openCourse(.swiftDevelopment)
        XCTAssertEqual(model.route, .courseHome)
        XCTAssertEqual(model.courseOpenError, "Swift Development content is unavailable.")
    }

    func testEveryNewModelStartsAtCourseHomeWithoutMutation() throws {
        let fixture = try ModelFixture()
        fixture.progress.markComplete(.swift(2))

        let lessonBytes = try Data(contentsOf: fixture.lessonURL)
        let progressBytes = try Data(contentsOf: fixture.progressURL)
        let settingsBefore = fixture.defaults.dictionaryRepresentation()

        let model = AppModel(
            store: fixture.lessons,
            progress: fixture.progress,
            settings: fixture.settings,
            contentRegistry: fixture.registry
        )

        XCTAssertEqual(model.route, .courseHome)
        XCTAssertNil(model.selectedLessonKey)
        XCTAssertEqual(model.code, "")
        XCTAssertEqual(model.prediction, "")
        XCTAssertEqual(try Data(contentsOf: fixture.lessonURL), lessonBytes)
        XCTAssertEqual(try Data(contentsOf: fixture.progressURL), progressBytes)
        XCTAssertEqual(fixture.defaults.dictionaryRepresentation() as NSDictionary,
                       settingsBefore as NSDictionary)
    }

    func testOpenCourseUsesDeterministicDestination() throws {
        let start = try ModelFixture()
        let startModel = start.makeModel()
        startModel.openCourse(.swiftDevelopment)
        XCTAssertEqual(startModel.route, .course(.swiftDevelopment))
        XCTAssertEqual(startModel.selectedLessonKey, .swift(1))
        XCTAssertEqual(startModel.lessonSelectionTransaction?.origin, .courseEntry)
        XCTAssertFalse(start.progress.hasMeaningfulActivity(in: .swiftDevelopment))

        let unfinished = try ModelFixture()
        unfinished.progress.recordSavedWorkspaceActivity(for: .swift(2))
        let unfinishedBytes = try Data(contentsOf: unfinished.progressURL)
        let unfinishedModel = unfinished.makeModel()
        unfinishedModel.openCourse(.swiftDevelopment)
        XCTAssertEqual(unfinishedModel.selectedLessonKey, .swift(2))
        XCTAssertEqual(
            unfinishedModel.lessonSelectionTransaction?.origin,
            .programmatic,
            "Continue destinations must request one programmatic visibility scroll."
        )
        XCTAssertEqual(try Data(contentsOf: unfinished.progressURL), unfinishedBytes)

        let completedLast = try ModelFixture()
        completedLast.progress.markComplete(.swift(1))
        let completedLastModel = completedLast.makeModel()
        completedLastModel.openCourse(.swiftDevelopment)
        XCTAssertEqual(completedLastModel.selectedLessonKey, .swift(2))

        let allComplete = try ModelFixture()
        for lesson in allComplete.lessons.lessons {
            allComplete.progress.markComplete(.swift(lesson.id))
        }
        allComplete.progress.recordSavedWorkspaceActivity(for: .swift(2))
        let allCompleteModel = allComplete.makeModel()
        allCompleteModel.openCourse(.swiftDevelopment)
        XCTAssertEqual(allCompleteModel.selectedLessonKey, .swift(2))
        XCTAssertEqual(
            allCompleteModel.lessonSelectionTransaction?.origin,
            .programmatic,
            "Review destinations must request one programmatic visibility scroll."
        )

        let invalidLast = try ModelFixture()
        invalidLast.progress.recordSavedWorkspaceActivity(for: .swift(999))
        let invalidLastModel = invalidLast.makeModel()
        invalidLastModel.openCourse(.swiftDevelopment)
        XCTAssertEqual(invalidLastModel.selectedLessonKey, .swift(1))

        let unavailable = try ModelFixture()
        let unavailableBytes = try? Data(contentsOf: unavailable.progressURL)
        let unavailableModel = unavailable.makeModel()
        unavailableModel.openCourse(.webDevelopment)
        XCTAssertEqual(unavailableModel.route, .courseHome)
        XCTAssertNil(unavailableModel.selectedLessonKey)
        XCTAssertEqual(unavailableModel.courseOpenError, "Web Development is coming next.")
        XCTAssertEqual(try? Data(contentsOf: unavailable.progressURL), unavailableBytes)
    }

    func testNavigationCancelsTransientLessonWork() async throws {
        let fixture = try ModelFixture()
        fixture.settings.aiEnabled = true
        fixture.progress.markComplete(.swift(1))
        let runStarted = expectation(description: "run started")
        let runCancelled = expectation(description: "run cancelled")
        let aiStarted = expectation(description: "AI started")
        let aiCancelled = expectation(description: "AI cancelled")

        let model = fixture.makeModel(
            runCode: { _ in
                runStarted.fulfill()
                do { try await Task.sleep(nanoseconds: 60_000_000_000) }
                catch { runCancelled.fulfill() }
                return RunResult(
                    stdout: "stale run",
                    stderr: "",
                    exitCode: 0,
                    launchError: nil,
                    workspaceWasSaved: true
                )
            },
            requestAI: { request in
                XCTAssertEqual(request.provider, "cli")
                aiStarted.fulfill()
                do { try await Task.sleep(nanoseconds: 60_000_000_000) }
                catch { aiCancelled.fulfill() }
                return AIResult(text: "stale AI", errorMessage: nil)
            }
        )
        model.openCourse(.swiftDevelopment)
        model.code = "persist this edit"
        model.prediction = "a prediction"

        var firstRegistrationCancelled = false
        _ = model.registerWorkspaceCancellation { firstRegistrationCancelled = true }
        XCTAssertFalse(firstRegistrationCancelled)
        var activeRegistrationSawOldKey = false
        let activeRegistration = model.registerWorkspaceCancellation {
            activeRegistrationSawOldKey = model.selectedLessonKey == .swift(2)
        }
        XCTAssertTrue(firstRegistrationCancelled)

        model.run()
        model.askAI()
        await fulfillment(of: [runStarted, aiStarted], timeout: 5)
        model.selectLesson(.swift(3), origin: .direct)
        await fulfillment(of: [runCancelled, aiCancelled], timeout: 5)
        await Task.yield()

        XCTAssertTrue(activeRegistrationSawOldKey)
        XCTAssertEqual(model.selectedLessonKey, .swift(3))
        XCTAssertEqual(model.code, "")
        XCTAssertEqual(model.prediction, "")
        XCTAssertNil(model.runResult)
        XCTAssertNil(model.aiResponse)
        XCTAssertNil(model.aiError)
        XCTAssertFalse(model.isRunning)
        XCTAssertFalse(model.isAskingAI)
        XCTAssertTrue(fixture.progress.isComplete(.swift(1)))
        XCTAssertEqual(fixture.progress.lastLessonKey(in: .swiftDevelopment), .swift(1))

        model.unregisterWorkspaceCancellation(activeRegistration)
        model.goHome()
        XCTAssertEqual(model.route, .courseHome)
        XCTAssertNil(model.selectedLessonKey)
        XCTAssertNil(model.lessonSelectionTransaction)
    }

    func testRepeatedAsyncRequestsCancelPriorWorkAndSuppressStaleResults() async throws {
        let fixture = try ModelFixture()
        fixture.settings.aiEnabled = true
        fixture.settings.aiProvider = "api"
        fixture.settings.apiKey = "test-key"
        fixture.settings.apiModel = "test-model"

        let firstRunStarted = expectation(description: "first run started")
        let firstRunCancelled = expectation(description: "first run cancelled")
        let secondRunReturned = expectation(description: "second run returned")
        let firstAIStarted = expectation(description: "first AI started")
        let firstAICancelled = expectation(description: "first AI cancelled")
        let secondAIReturned = expectation(description: "second AI returned")
        var runCalls = 0
        var aiCalls = 0
        var capturedSecondRequest: AICoachRequest?

        let model = fixture.makeModel(
            runCode: { code in
                runCalls += 1
                if runCalls == 1 {
                    XCTAssertEqual(code, "first run")
                    firstRunStarted.fulfill()
                    do { try await Task.sleep(nanoseconds: 60_000_000_000) }
                    catch { firstRunCancelled.fulfill() }
                    return RunResult(
                        stdout: "stale run",
                        stderr: "",
                        exitCode: 0,
                        launchError: nil,
                        workspaceWasSaved: true
                    )
                }
                XCTAssertEqual(code, "second run")
                secondRunReturned.fulfill()
                return RunResult(
                    stdout: "current run",
                    stderr: "",
                    exitCode: 1,
                    launchError: nil,
                    workspaceWasSaved: false
                )
            },
            requestAI: { request in
                aiCalls += 1
                if aiCalls == 1 {
                    firstAIStarted.fulfill()
                    do { try await Task.sleep(nanoseconds: 60_000_000_000) }
                    catch { firstAICancelled.fulfill() }
                    return AIResult(text: "stale AI", errorMessage: nil)
                }
                capturedSecondRequest = request
                secondAIReturned.fulfill()
                return AIResult(text: "current AI", errorMessage: nil)
            }
        )
        model.openCourse(.swiftDevelopment)

        model.code = "first run"
        model.run()
        await fulfillment(of: [firstRunStarted], timeout: 5)
        model.code = "second run"
        model.run()
        await fulfillment(of: [firstRunCancelled, secondRunReturned], timeout: 5)
        await waitUntil { model.runResult?.stdout == "current run" }

        XCTAssertEqual(runCalls, 2)
        XCTAssertEqual(model.runResult?.stdout, "current run")
        XCTAssertFalse(model.isRunning)
        XCTAssertFalse(fixture.progress.hasMeaningfulActivity(in: .swiftDevelopment))

        model.code = "first AI"
        model.askAI()
        await fulfillment(of: [firstAIStarted], timeout: 5)
        model.code = "second AI"
        model.askAI()
        await fulfillment(of: [firstAICancelled, secondAIReturned], timeout: 5)
        await waitUntil { model.aiResponse == "current AI" }

        XCTAssertEqual(aiCalls, 2)
        XCTAssertEqual(model.aiResponse, "current AI")
        XCTAssertNil(model.aiError)
        XCTAssertFalse(model.isAskingAI)
        XCTAssertEqual(capturedSecondRequest?.code, "second AI")
        XCTAssertEqual(capturedSecondRequest?.lesson.id, 1)
        XCTAssertEqual(capturedSecondRequest?.provider, "api")
        XCTAssertEqual(capturedSecondRequest?.apiKey, "test-key")
        XCTAssertEqual(capturedSecondRequest?.model, "test-model")
    }

    func testProgrammaticSelectionRepairUsesCancellationBoundary() async throws {
        let fixture = try ModelFixture()
        let runStarted = expectation(description: "run started")
        let runCancelled = expectation(description: "run cancelled")
        let model = fixture.makeModel(runCode: { _ in
            runStarted.fulfill()
            do { try await Task.sleep(nanoseconds: 60_000_000_000) }
            catch { runCancelled.fulfill() }
            return RunResult(
                stdout: "stale",
                stderr: "",
                exitCode: 0,
                launchError: nil,
                workspaceWasSaved: true
            )
        })
        model.openCourse(.swiftDevelopment)
        let oldGeneration = try XCTUnwrap(model.lessonSelectionTransaction?.generation)
        var cancellationSawOldIdentity = false
        _ = model.registerWorkspaceCancellation {
            cancellationSawOldIdentity = model.selectedLessonKey == .swift(1)
        }

        model.run()
        await fulfillment(of: [runStarted], timeout: 5)
        fixture.lessons.delete(id: 1)
        model.ensureSelectionValid()
        await fulfillment(of: [runCancelled], timeout: 5)

        XCTAssertTrue(cancellationSawOldIdentity)
        XCTAssertEqual(model.selectedLessonKey, .swift(2))
        XCTAssertEqual(model.lessonSelectionTransaction?.origin, .programmatic)
        XCTAssertGreaterThan(model.lessonSelectionTransaction?.generation ?? 0, oldGeneration)
        XCTAssertNil(model.runResult)
        XCTAssertFalse(model.isRunning)
        XCTAssertFalse(fixture.progress.hasMeaningfulActivity(in: .swiftDevelopment))
    }

    func testCourseOpeningAndHomeCancelWorkspaceBeforeRouteMutation() throws {
        let fixture = try ModelFixture()
        let model = fixture.makeModel()
        model.openCourse(.swiftDevelopment)

        var courseOpenSawOldIdentity = false
        _ = model.registerWorkspaceCancellation {
            courseOpenSawOldIdentity = model.route == .course(.swiftDevelopment)
                && model.selectedLessonKey == .swift(1)
        }
        model.openCourse(.swiftDevelopment)
        XCTAssertTrue(courseOpenSawOldIdentity)

        var homeSawOldIdentity = false
        _ = model.registerWorkspaceCancellation {
            homeSawOldIdentity = model.route == .course(.swiftDevelopment)
                && model.selectedLessonKey == .swift(1)
        }
        model.goHome()
        XCTAssertTrue(homeSawOldIdentity)
        XCTAssertEqual(model.route, .courseHome)
        XCTAssertNil(model.selectedLessonKey)
    }

    func testWorkspaceCancellationIsExactOnceReleasedAndReentrantSafe() throws {
        let fixture = try ModelFixture()
        let model = fixture.makeModel()
        model.openCourse(.swiftDevelopment)

        var firstCount = 0
        var replacementCount = 0
        var nestedCount = 0
        var didReenter = false
        _ = model.registerWorkspaceCancellation {
            firstCount += 1
            if !didReenter {
                didReenter = true
                _ = model.registerWorkspaceCancellation { nestedCount += 1 }
            }
        }
        _ = model.registerWorkspaceCancellation { replacementCount += 1 }

        XCTAssertEqual(firstCount, 1)
        XCTAssertEqual(replacementCount, 1)
        XCTAssertEqual(nestedCount, 0)

        model.goHome()
        XCTAssertEqual(nestedCount, 1)
        model.goHome()
        XCTAssertEqual(nestedCount, 1)

        var token: WorkspaceCaptureToken? = WorkspaceCaptureToken()
        weak var weakToken = token
        _ = model.registerWorkspaceCancellation { [token] in _ = token }
        token = nil
        XCTAssertNotNil(weakToken)
        model.goHome()
        XCTAssertNil(weakToken)
    }

    private func waitUntil(
        timeout: TimeInterval = 5,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            await Task.yield()
        }
        XCTAssertTrue(condition())
    }
}

private final class WorkspaceCaptureToken {}

private final class ModelFixture {
    let root: URL
    let lessonURL: URL
    let progressURL: URL
    let defaults: UserDefaults
    let lessons: LessonStore
    let progress: ProgressStore
    let settings: AppSettings
    let registry: CourseContentRegistry

    init(defaultLessons: [Lesson] = Curriculum.defaultLessons) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppModelNavigationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        lessonURL = root.appendingPathComponent("lessons.json")
        progressURL = root.appendingPathComponent("progress.json")
        try JSONEncoder().encode(defaultLessons).write(to: lessonURL)

        let suite = "AppModelNavigationTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        lessons = LessonStore(fileURL: lessonURL, defaults: defaultLessons)
        progress = ProgressStore(fileURL: progressURL, now: { Date(timeIntervalSince1970: 1_700_000_000) })
        settings = AppSettings(userDefaults: defaults)
        registry = CourseContentRegistry(
            providers: [.swiftDevelopment: LegacySwiftCourseProvider(store: lessons)]
        )
    }

    @MainActor
    func makeModel(
        runCode: ((String) async -> RunResult)? = nil,
        requestAI: ((AICoachRequest) async -> AIResult)? = nil
    ) -> AppModel {
        AppModel(
            store: lessons,
            progress: progress,
            settings: settings,
            contentRegistry: registry,
            runCode: runCode,
            requestAI: requestAI
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }
}
