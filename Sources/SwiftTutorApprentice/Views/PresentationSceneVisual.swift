import SwiftUI

struct PresentationSceneVisual: View {
    let scene: PresentationScene
    let phase: PresentationVisualPhase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var outputNamespace

    private var state: PresentationVisualState {
        phase == .before ? scene.before : scene.after
    }

    var body: some View {
        Group {
            switch scene.visualKind {
            case .codeExecution, .valueBinding:
                codeAndValues
            case .outputFlow:
                outputFlow
            case .branchChoice, .collectionChange, .webRender, .packetJourney,
                    .securityTimeline, .labeledDiagram:
                staticFallback
            }
        }
        .frame(maxWidth: .infinity, minHeight: 104, maxHeight: 176, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var codeAndValues: some View {
        HStack(alignment: .top, spacing: 18) {
            if state.codeTokens.isEmpty == false {
                tokenLane
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let code = state.code {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if state.values.isEmpty == false {
                valueLane
                    .frame(maxWidth: 230, alignment: .trailing)
            }
        }
    }

    private var tokenLane: some View {
        TokenFlowLayout(spacing: 2) {
            ForEach(state.codeTokens) { token in
                Text(token.text)
                    .font(.system(.body, design: .monospaced))
                    .padding(.vertical, 3)
                    .padding(.horizontal, token.text.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty ? 0 : 3)
                    .background(
                        tokenIsFocused(token.id)
                            ? Color.accentColor.opacity(0.18)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 5)
                    )
                    .overlay {
                        if tokenIsFocused(token.id) {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.accentColor, lineWidth: 2)
                        }
                    }
            }
        }
    }

    private var valueLane: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(state.values) { value in
                HStack(spacing: 10) {
                    Text(value.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value.value)
                        .font(.system(.body, design: .monospaced).bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    if valueIsFocused(value.id) {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor, lineWidth: 2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var outputFlow: some View {
        HStack(spacing: 14) {
            codeBlock
            Image(systemName: "arrow.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            outputCard
        }
    }

    private var codeBlock: some View {
        Text(state.code ?? "Code prepares its next result")
            .font(.system(.callout, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
    }

    @ViewBuilder
    private var outputCard: some View {
        let card = VStack(alignment: .leading, spacing: 4) {
            Text("OUTPUT")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(state.output ?? "Waiting for output")
                .font(.system(.title3, design: .monospaced).bold())
        }
        .frame(minWidth: 130, alignment: .leading)
        .padding(12)
        .background(Color.green.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            if outputIsFocused {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.green, lineWidth: 2)
            }
        }

        if reduceMotion {
            card
        } else {
            card.matchedGeometryEffect(id: state.outputTargetID ?? "output", in: outputNamespace)
                .animation(.easeOut(duration: 0.28), value: phase)
        }
    }

    private var staticFallback: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: fallbackSymbol)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(scene.title)
                    .font(.headline)
                Text(state.description.isEmpty ? scene.staticDescription : state.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var fallbackSymbol: String {
        switch scene.visualKind {
        case .branchChoice: "arrow.triangle.branch"
        case .collectionChange: "square.stack.3d.up"
        case .webRender: "macwindow"
        case .packetJourney: "point.3.connected.trianglepath.dotted"
        case .securityTimeline: "lock.shield"
        case .labeledDiagram: "rectangle.3.group"
        case .codeExecution, .valueBinding, .outputFlow: "play.rectangle"
        }
    }

    private func tokenIsFocused(_ id: String) -> Bool {
        scene.focusTargets.contains { $0.kind == .codeToken && $0.id == id }
    }

    private func valueIsFocused(_ id: String) -> Bool {
        scene.focusTargets.contains { $0.kind == .value && $0.id == id }
    }

    private var outputIsFocused: Bool {
        guard let outputTargetID = state.outputTargetID else { return false }
        return scene.focusTargets.contains {
            $0.kind == .output && $0.id == outputTargetID
        }
    }

    private var accessibilitySummary: String {
        let focused = scene.focusTargets.compactMap { target -> String? in
            switch target.kind {
            case .codeToken:
                guard let token = state.codeTokens.first(where: { $0.id == target.id }) else {
                    return nil
                }
                return "Focused code token: \(token.text)"
            case .value:
                guard let value = state.values.first(where: { $0.id == target.id }) else {
                    return nil
                }
                return "Focused value: \(value.name) equals \(value.value)"
            case .output:
                guard state.outputTargetID == target.id,
                      let output = state.output else { return nil }
                return "Focused output: \(output)"
            }
        }
        return ([scene.staticDescription] + focused + ["Result: \(state.description)"])
            .joined(separator: ". ")
    }
}

private struct TokenFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? 520
        var points: [CGPoint] = []
        var cursor = CGPoint.zero
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x > 0, cursor.x + size.width > width {
                cursor.x = 0
                cursor.y += lineHeight + spacing
                lineHeight = 0
            }
            points.append(cursor)
            cursor.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return (
            CGSize(width: width, height: cursor.y + lineHeight),
            points
        )
    }
}
