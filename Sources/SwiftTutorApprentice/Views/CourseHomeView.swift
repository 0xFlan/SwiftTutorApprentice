import AppKit
import SwiftUI

/// A non-accessibility runtime identity attached to the view that actually
/// renders. Hosted layout tests use the AppKit identifier and geometry even
/// when XCTest's asynchronous SwiftUI accessibility bridge is unavailable.
struct RuntimeViewMarker: NSViewRepresentable {
    let identifier: String

    func makeNSView(context: Context) -> NSView {
        RuntimeMarkerNSView(identifier: identifier)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.identifier = NSUserInterfaceItemIdentifier(identifier)
    }
}

private final class RuntimeMarkerNSView: NSView {
    init(identifier: String) {
        super.init(frame: .zero)
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct RuntimeNavigationCommand {
    let identifier: String
    private let action: @MainActor () -> Void

    init(identifier: String, action: @escaping @MainActor () -> Void) {
        self.identifier = identifier
        self.action = action
    }

    @MainActor
    func invoke() { action() }
}

struct RuntimeNavigationActionMarker: NSViewRepresentable {
    let command: RuntimeNavigationCommand

    func makeNSView(context: Context) -> RuntimeNavigationActionView {
        RuntimeNavigationActionView(command: command)
    }

    func updateNSView(_ nsView: RuntimeNavigationActionView, context: Context) {
        nsView.command = command
        nsView.identifier = NSUserInterfaceItemIdentifier(command.identifier)
    }
}

final class RuntimeNavigationActionView: NSView {
    var command: RuntimeNavigationCommand

    init(command: RuntimeNavigationCommand) {
        self.command = command
        super.init(frame: .zero)
        identifier = NSUserInterfaceItemIdentifier(command.identifier)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func invoke() { command.invoke() }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct CourseHomeView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 24) {
                orientation

                AdaptiveCourseGrid(minimumColumnWidth: 420, spacing: 18) {
                    ForEach(cardModels) { card in
                        CourseCard(
                            card: card,
                            command: RuntimeNavigationCommand(
                                identifier: "course-action-\(card.id.rawValue)",
                                action: { model.openCourse(card.id) }
                            )
                        )
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("course-card-\(card.id.rawValue)")
                        .background {
                            RuntimeViewMarker(identifier: "course-card-\(card.id.rawValue)")
                        }
                    }
                }

                if let error = model.courseOpenError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Course unavailable: \(error)")
                }
            }
            .frame(maxWidth: 1260, alignment: .leading)
            .padding(28)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("course-home-scroll")
        .background {
            RuntimeViewMarker(identifier: "course-home-scroll")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .background {
            RuntimeViewMarker(identifier: "course-home-root")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("course-home-root")
    }

    private var orientation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("SwiftTutor Apprentice", systemImage: "graduationcap.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Understand the code you build")
                .font(.largeTitle.bold())

            Text("Start with no experience. Each course explains what the code does, lets you practice it locally, and builds toward the listed certification knowledge.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Label(
                "Your progress stays private on this Mac and is never posted to a leaderboard.",
                systemImage: "lock.fill"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var cardModels: [CourseHomeCardModel] {
        model.courseHomeCards()
    }
}

/// A non-lazy adaptive grid. Course Home has only four cards, and keeping all
/// four mounted gives routing, testing, and assistive technology one stable
/// rendered identity per catalog course even when a card is below the fold.
private struct AdaptiveCourseGrid: Layout {
    let minimumColumnWidth: CGFloat
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = max(proposal.width ?? minimumColumnWidth, minimumColumnWidth)
        let metrics = metrics(for: width, subviews: subviews)
        return CGSize(width: width, height: metrics.totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let metrics = metrics(for: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in metrics.rows.indices {
            for column in metrics.rows[row].indices {
                let index = row * metrics.columnCount + column
                subviews[index].place(
                    at: CGPoint(
                        x: bounds.minX + CGFloat(column) * (metrics.columnWidth + spacing),
                        y: y
                    ),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: metrics.columnWidth, height: nil)
                )
            }
            y += metrics.rowHeights[row] + spacing
        }
    }

    private func metrics(for width: CGFloat, subviews: Subviews) -> Metrics {
        let columnCount = max(
            1,
            Int((width + spacing) / (minimumColumnWidth + spacing))
        )
        let columnWidth = (width - CGFloat(columnCount - 1) * spacing)
            / CGFloat(columnCount)
        let rows = stride(from: 0, to: subviews.count, by: columnCount).map { start in
            Array(start..<min(start + columnCount, subviews.count))
        }
        let rowHeights = rows.map { row in
            row.map { index in
                subviews[index].sizeThatFits(
                    ProposedViewSize(width: columnWidth, height: nil)
                ).height
            }.max() ?? 0
        }
        return Metrics(
            columnCount: columnCount,
            columnWidth: columnWidth,
            rows: rows,
            rowHeights: rowHeights,
            totalHeight: rowHeights.reduce(0, +)
                + CGFloat(max(0, rowHeights.count - 1)) * spacing
        )
    }

    private struct Metrics {
        let columnCount: Int
        let columnWidth: CGFloat
        let rows: [[Int]]
        let rowHeights: [CGFloat]
        let totalHeight: CGFloat
    }
}

private struct CourseCard: View {
    let card: CourseHomeCardModel
    let command: RuntimeNavigationCommand

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: card.symbolName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 36, height: 36)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.title2.bold())
                    Text(card.availabilityText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(card.isPrimaryActionEnabled ? accentColor : .secondary)
                }
                Spacer(minLength: 0)
            }

            Text(card.purpose)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Certification target")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(card.targetCredentialText)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let progress = card.progressText {
                Label(progress, systemImage: "chart.bar.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button(action: command.invoke) {
                Text(card.primaryActionLabel)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
            .disabled(!card.isPrimaryActionEnabled)
            .accessibilityHint(
                card.isPrimaryActionEnabled
                    ? "Open the \(card.title) course"
                    : "This course is not released yet"
            )
            .background {
                RuntimeNavigationActionMarker(command: command)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var accentColor: Color {
        switch card.accentName {
        case "swiftOrange": .orange
        case "webBlue": .blue
        case "securityGreen": .green
        case "networkPurple": .purple
        default: .accentColor
        }
    }
}
