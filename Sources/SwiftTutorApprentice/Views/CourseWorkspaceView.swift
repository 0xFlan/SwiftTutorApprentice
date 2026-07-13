import SwiftUI

@MainActor
struct CourseHomeNavigationCommand {
    static let keyCharacter: Character = "h"
    static let modifiers: EventModifiers = [.command, .shift]

    let runtimeCommand: RuntimeNavigationCommand

    init(model: AppModel) {
        runtimeCommand = RuntimeNavigationCommand(
            identifier: "course-home-action",
            action: { model.goHome() }
        )
    }
}

struct CourseWorkspaceView: View {
    @ObservedObject var model: AppModel
    let canPresentLearningStages: Bool

    @State private var showingLessonEditor = false
    @State private var showingSettings = false
    @State private var canPresentWorkspaceLearningStages = true
    @StateObject private var scrollCoordinator = LessonScrollCoordinator()

    init(model: AppModel, canPresentLearningStages: Bool = true) {
        self.model = model
        self.canPresentLearningStages = canPresentLearningStages
    }

    var body: some View {
        let homeCommand = CourseHomeNavigationCommand(model: model)

        NavigationSplitView {
            LessonListSidebar(
                model: model,
                store: model.store,
                progress: model.progress,
                scrollCoordinator: scrollCoordinator,
                onManageLessons: {
                    canPresentWorkspaceLearningStages = false
                    showingLessonEditor = true
                },
                onOpenSettings: {
                    canPresentWorkspaceLearningStages = false
                    showingSettings = true
                }
            )
        } detail: {
            LessonWorkspace(
                model: model,
                settings: model.settings,
                progress: model.progress,
                scrollCoordinator: scrollCoordinator,
                canPresentLearningStages: canPresentLearningStages
                    && canPresentWorkspaceLearningStages
            )
            .navigationTitle("SwiftTutor Apprentice")
            .navigationSubtitle("Lesson \(model.currentDisplayNumber): \(model.currentLesson.title)")
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: homeCommand.runtimeCommand.invoke) {
                    Label("Course Home", systemImage: "house")
                }
                .keyboardShortcut(
                    KeyEquivalent(CourseHomeNavigationCommand.keyCharacter),
                    modifiers: CourseHomeNavigationCommand.modifiers
                )
                .help("Return to Course Home (Shift-Command-H)")
            }
        }
        .sheet(isPresented: $showingLessonEditor, onDismiss: {
            canPresentWorkspaceLearningStages = true
        }) {
            LessonEditorView(store: model.store, initialSelection: model.selectedLessonID)
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            canPresentWorkspaceLearningStages = true
        }) {
            SettingsView(settings: model.settings)
        }
        .onChange(of: model.store.lessons) {
            model.ensureSelectionValid()
        }
        .onAppear {
            synchronizeSelectionTransaction(model.lessonSelectionTransaction)
        }
        .onChange(of: model.lessonSelectionTransaction) { _, transaction in
            synchronizeSelectionTransaction(transaction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RuntimeViewMarker(identifier: "course-workspace-root")
        }
        .background {
            // The manual-hosting test environment does not mount SwiftUI
            // toolbars. Expose the toolbar's exact shared command on the
            // rendered workspace root so its production action remains
            // executable without a parallel test-only callback.
            RuntimeNavigationActionMarker(command: homeCommand.runtimeCommand)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("course-workspace-root")
    }

    private func synchronizeSelectionTransaction(
        _ transaction: LessonSelectionTransaction?
    ) {
        guard let transaction else { return }
        scrollCoordinator.select(transaction.key, origin: transaction.origin)
    }
}
