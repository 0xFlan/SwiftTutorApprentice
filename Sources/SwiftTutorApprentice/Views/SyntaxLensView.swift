// SyntaxLensView.swift
// ------------------------------------------------------------
// The "Syntax Lens" shows a line of code broken into tokens.
// Each token is a chip the learner can click to read what that
// piece means. Below the tokens we explain WHY Swift needs the
// parentheses and quotation marks.
// ------------------------------------------------------------

import SwiftUI

struct SyntaxLensView: View {
    let tokens: [SyntaxToken]
    let whyExplanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Syntax Lens")
                .font(.headline)

            Text("Tap a piece to see what it means:")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Lay the token chips out in rows that wrap.
            FlowLayout(spacing: 6) {
                ForEach(tokens) { token in
                    SyntaxTokenChip(token: token)
                }
            }

            Divider()
                .padding(.vertical, 2)

            Text("Why the syntax?")
                .font(.subheadline.bold())
            Text(whyExplanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One clickable token chip with a popover explanation.
private struct SyntaxTokenChip: View {
    let token: SyntaxToken
    @State private var showing = false

    var body: some View {
        Button {
            showing.toggle()
        } label: {
            Text(token.display)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(token.explanation)
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(token.display)
                    .font(.system(.title3, design: .monospaced).bold())
                Text(token.explanation)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 300, alignment: .leading)
        }
    }
}

// MARK: - A simple layout that wraps chips onto multiple lines.
//
// SwiftUI doesn't have a built-in "wrapping HStack", so this small
// Layout arranges its children left-to-right and wraps to a new row
// when it runs out of width. You don't need to fully understand this
// yet — think of it as "flow the chips like words in a paragraph."

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
