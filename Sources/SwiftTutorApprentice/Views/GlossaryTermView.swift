// GlossaryTermView.swift
// ------------------------------------------------------------
// A small, reusable view that shows a glossary term the learner
// can interact with:
//   • Hover  -> a short tooltip (via .help)
//   • Click  -> a popover card with the deeper explanation
//
// If the term isn't in the glossary, it's shown as plain text.
// ------------------------------------------------------------

import SwiftUI

struct GlossaryTermView: View {
    let term: String

    @State private var showingCard = false

    private var entry: GlossaryEntry? {
        Glossary.entry(for: term)
    }

    var body: some View {
        if let entry {
            Button {
                showingCard.toggle()
            } label: {
                Text(entry.term)
                    .font(.callout)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            // Hover tooltip = the short definition.
            .help(entry.short)
            // Click = deeper explanation card.
            .popover(isPresented: $showingCard, arrowEdge: .bottom) {
                deepCard(entry)
            }
        } else {
            // Unknown term: just show it plainly.
            Text(term)
                .font(.callout)
        }
    }

    /// The card shown when the term is clicked.
    private func deepCard(_ entry: GlossaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.term)
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 4) {
                Text("Short")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(entry.short)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Deep")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(entry.deep)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 340, alignment: .leading)
    }
}
