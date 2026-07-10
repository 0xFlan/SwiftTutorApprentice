// SyntaxMicroscopeView.swift
// ------------------------------------------------------------
// A detailed, read-only explanation of the syntax used by a
// Deep Lesson. Every token stays in the author-provided order.
// ------------------------------------------------------------

import SwiftUI

struct SyntaxMicroscopeView: View {
    let tokens: [SyntaxMicroscopeToken]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Syntax Microscope")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)

                Text("Look closely at what each part does, whether Swift requires it, and what changes when you edit it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                    if index > 0 {
                        Divider()
                    }

                    tokenItem(token)
                }
            }
        }
    }

    private func tokenItem(_ token: SyntaxMicroscopeToken) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    tokenDisplay(token)
                        .fixedSize(horizontal: true, vertical: false)

                    Spacer(minLength: 8)

                    requirementBadge(token.requirement)
                        .fixedSize(horizontal: true, vertical: false)
                }

                VStack(alignment: .leading, spacing: 8) {
                    tokenDisplay(token)
                    requirementBadge(token.requirement)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Role")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(token.role)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(token.explanation)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 3) {
                Text("If you change it")
                    .font(.subheadline.bold())
                Text(token.ifChanged)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                "\(token.display). Role: \(token.role). "
                + "Requirement: \(token.requirement.label). "
                + "\(token.explanation). If you change it: \(token.ifChanged)"
            )
        )
    }

    private func tokenDisplay(_ token: SyntaxMicroscopeToken) -> some View {
        Text(token.display)
            .font(.system(.title3, design: .monospaced).weight(.semibold))
            .textSelection(.enabled)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func requirementBadge(_ requirement: SyntaxRequirement) -> some View {
        Label(requirement.label, systemImage: requirement.symbol)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.10))
            .clipShape(Capsule())
    }
}

private extension SyntaxRequirement {
    var label: String {
        switch self {
        case .required:
            "Required by Swift"
        case .convention:
            "Convention"
        case .contextual:
            "Depends on context"
        }
    }

    var symbol: String {
        switch self {
        case .required:
            "checkmark.seal.fill"
        case .convention:
            "paintbrush.fill"
        case .contextual:
            "questionmark.circle.fill"
        }
    }
}
