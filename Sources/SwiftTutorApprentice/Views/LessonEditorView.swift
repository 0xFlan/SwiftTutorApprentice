// LessonEditorView.swift
// ------------------------------------------------------------
// The in-app lesson editor. Everything about a lesson can be
// created and changed right here — no editing JSON files by hand
// and no leaving the app. Lessons are saved to disk automatically.
//
// Layout: a list of lessons on the left (add / reorder / delete),
// and a form for the selected lesson on the right.
// ------------------------------------------------------------

import SwiftUI

struct LessonEditorView: View {
    @ObservedObject var store: LessonStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Lesson

    init(store: LessonStore, initialSelection: Int) {
        self.store = store
        let start = store.lesson(id: initialSelection) ?? store.lessons.first ?? Curriculum.defaultLessons[0]
        _draft = State(initialValue: start)
    }

    /// The saved version of whatever we're editing (nil if it's brand new).
    private var storedVersion: Lesson? { store.lesson(id: draft.id) }
    private var hasUnsavedChanges: Bool { storedVersion != draft }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                lessonList
                Divider()
                editorForm
            }
        }
        .frame(minWidth: 860, minHeight: 620)
    }

    // MARK: - Header / toolbar

    private var header: some View {
        HStack {
            Text("Manage Lessons")
                .font(.title3.bold())
            Spacer()
            if hasUnsavedChanges {
                Text("Unsaved changes")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Button("Save") { commitDraft() }
                .disabled(!hasUnsavedChanges)
            Button("Done") {
                commitDraft()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(12)
    }

    // MARK: - Left: lesson list

    private var lessonList: some View {
        VStack(spacing: 0) {
            List(selection: Binding(
                get: { draft.id },
                set: { if let id = $0 { switchTo(id) } }
            )) {
                ForEach(Array(store.lessons.enumerated()), id: \.element.id) { index, lesson in
                    HStack {
                        Text("\(index + 1).")
                            .foregroundStyle(.secondary)
                            .font(.caption.monospaced())
                        Text(lesson.title.isEmpty ? "(untitled)" : lesson.title)
                            .lineLimit(1)
                    }
                    .tag(lesson.id)
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack(spacing: 6) {
                Button {
                    addLesson()
                } label: { Image(systemName: "plus") }
                    .help("Add a new lesson")

                Button {
                    store.move(id: draft.id, by: -1)
                } label: { Image(systemName: "arrow.up") }
                    .help("Move this lesson up")

                Button {
                    store.move(id: draft.id, by: 1)
                } label: { Image(systemName: "arrow.down") }
                    .help("Move this lesson down")

                Spacer()

                Button(role: .destructive) {
                    deleteLesson()
                } label: { Image(systemName: "trash") }
                    .help("Delete this lesson")
                    .disabled(store.lessons.count <= 1)
            }
            .buttonStyle(.borderless)
            .padding(8)

            Divider()

            Button {
                store.restoreDefaults()
                if let first = store.lessons.first { draft = first }
            } label: {
                Label("Restore default lessons", systemImage: "arrow.counterclockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .padding(8)
        }
        .frame(width: 240)
    }

    // MARK: - Right: the form

    private var editorForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                field("Title") {
                    TextField("Lesson title", text: $draft.title)
                }

                field("Goal") {
                    TextField("One sentence: what will the learner achieve?", text: $draft.goal, axis: .vertical)
                        .lineLimit(2...4)
                }

                field("Starter code (what the learner types)") {
                    codeEditor(text: $draft.starterCode, minHeight: 90)
                }

                field("Expected output (used to auto-complete the lesson)") {
                    codeEditor(text: $draft.expectedOutput, minHeight: 44)
                }

                twoColumn(
                    left: ("What this teaches (one per line)", linesBinding(\.teaches)),
                    right: ("Glossary terms to show (one per line)", linesBinding(\.glossaryTerms))
                )

                field("Coach success markers — all must appear for \"looks right\" (one per line)") {
                    codeEditor(text: linesBinding(\.successMarkers), minHeight: 60)
                }

                field("Coach message when the code looks right") {
                    TextField("Success message", text: $draft.successMessage, axis: .vertical)
                        .lineLimit(2...6)
                }

                field("Coach hint when the code isn't there yet") {
                    TextField("Hint", text: $draft.hint, axis: .vertical)
                        .lineLimit(2...6)
                }

                field("Why the syntax? (shown under the Syntax Lens)") {
                    TextField("Explanation", text: $draft.syntaxWhy, axis: .vertical)
                        .lineLimit(3...8)
                }

                syntaxTokensEditor

                Spacer(minLength: 0)
            }
            .textFieldStyle(.roundedBorder)
            .padding(16)
        }
    }

    private var syntaxTokensEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Syntax Lens tokens")
                    .font(.headline)
                Spacer()
                Button {
                    let nextID = (draft.syntaxTokens.map(\.id).max() ?? -1) + 1
                    draft.syntaxTokens.append(SyntaxToken(id: nextID, display: "", explanation: ""))
                } label: {
                    Label("Add token", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            Text("Break the key line into pieces the learner can tap. Left = what shows on the chip; right = the explanation.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach($draft.syntaxTokens) { $token in
                HStack(alignment: .top, spacing: 8) {
                    TextField("chip", text: $token.display)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 140)
                    TextField("explanation", text: $token.explanation, axis: .vertical)
                        .lineLimit(1...4)
                    Button(role: .destructive) {
                        draft.syntaxTokens.removeAll { $0.id == token.id }
                    } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    // MARK: - Small view helpers

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline.bold())
            content()
        }
    }

    private func twoColumn(
        left: (String, Binding<String>),
        right: (String, Binding<String>)
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            field(left.0) { codeEditor(text: left.1, minHeight: 90) }
            field(right.0) { codeEditor(text: right.1, minHeight: 90) }
        }
    }

    private func codeEditor(text: Binding<String>, minHeight: CGFloat) -> some View {
        TextEditor(text: text)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: minHeight)
            .padding(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
    }

    /// Bridges a [String] property to a single newline-separated text field.
    private func linesBinding(_ keyPath: WritableKeyPath<Lesson, [String]>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath].joined(separator: "\n") },
            set: { newValue in
                draft[keyPath: keyPath] = newValue
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    // MARK: - Actions

    private func commitDraft() {
        if store.lesson(id: draft.id) != nil {
            store.update(draft)
        }
    }

    private func switchTo(_ id: Int) {
        guard id != draft.id else { return }
        commitDraft()
        if let lesson = store.lesson(id: id) { draft = lesson }
    }

    private func addLesson() {
        commitDraft()
        let new = Lesson(
            id: store.nextAvailableID,
            title: "New Lesson",
            goal: "",
            starterCode: "print(\"…\")",
            teaches: [],
            glossaryTerms: [],
            syntaxTokens: [],
            syntaxWhy: "",
            expectedOutput: "",
            successMarkers: [],
            successMessage: "",
            hint: "Type the starter code above."
        )
        store.add(new)
        draft = new
    }

    private func deleteLesson() {
        let idToDelete = draft.id
        store.delete(id: idToDelete)
        if let first = store.lessons.first { draft = first }
    }
}
