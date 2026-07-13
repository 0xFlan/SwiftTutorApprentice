// LessonPanel.swift
// ------------------------------------------------------------
// The left column of the work area. Shows the current lesson's
// title, goal, the code to type, what it teaches, the vocabulary
// terms for THIS lesson (as clickable glossary chips), and the
// Syntax Lens for the lesson's key line.
//
// Everything here comes from the Lesson data — this view doesn't
// know anything about a specific lesson.
// ------------------------------------------------------------

import SwiftUI

struct LessonPanel: View {
    let lesson: Lesson

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // --- What you will type ---
                section("What you will type") {
                    Text(lesson.starterCode)
                        .font(.system(.body, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // --- What this teaches ---
                section("What this teaches") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(lesson.teaches, id: \.self) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 5))
                                    .foregroundStyle(.secondary)
                                Text(item)
                            }
                        }
                    }
                }

                Divider()

                // --- Terms (glossary chips for this lesson) ---
                section("Terms") {
                    Text("Hover for a quick definition, click for more.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 6) {
                        ForEach(lesson.glossaryTerms, id: \.self) { term in
                            GlossaryTermView(term: term)
                        }
                    }
                    .padding(.top, 2)
                }

                Divider()

                // --- Syntax Lens for this lesson's key line ---
                // Use the lesson's curated tokens if present; otherwise generate
                // a breakdown automatically from the starter code.
                SyntaxLensView(
                    tokens: lesson.syntaxTokens.isEmpty
                        ? SyntaxTokenizer.tokenize(lesson.starterCode)
                        : lesson.syntaxTokens,
                    whyExplanation: lesson.syntaxWhy.isEmpty
                        ? SyntaxTokenizer.autoWhy
                        : lesson.syntaxWhy
                )

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    // A small helper to render a titled section consistently.
    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}
