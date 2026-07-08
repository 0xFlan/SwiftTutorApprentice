// LessonPanel.swift
// ------------------------------------------------------------
// The left column. Shows the current lesson, the vocabulary terms
// (as clickable glossary chips), and the Syntax Lens.
// ------------------------------------------------------------

import SwiftUI

struct LessonPanel: View {
    let lesson: Lesson

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // --- Lesson header ---
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lesson \(lesson.id)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(lesson.title)
                        .font(.title2.bold())
                }

                // --- Goal ---
                section("Goal") {
                    Text(lesson.goal)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // --- What you will type ---
                section("What you will type") {
                    Text(lesson.codeToType)
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
                            Label(item, systemImage: "circle.fill")
                                .labelStyle(BulletLabelStyle())
                        }
                    }
                }

                Divider()

                // --- Terms (glossary chips) ---
                section("Terms") {
                    Text("Hover for a quick definition, click for more.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 6) {
                        ForEach(Glossary.displayOrder, id: \.self) { term in
                            GlossaryTermView(term: term)
                        }
                    }
                    .padding(.top, 2)
                }

                Divider()

                // --- Syntax Lens ---
                SyntaxLensView(
                    tokens: SyntaxLens.helloWorldTokens,
                    whyExplanation: SyntaxLens.whyExplanation
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

/// Renders a Label as a small bullet + text.
private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(.secondary)
            configuration.title
        }
    }
}
