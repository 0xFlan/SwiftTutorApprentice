// CodeTextView.swift
// ------------------------------------------------------------
// A lightweight code editor with syntax highlighting.
//
// SwiftUI's TextEditor (on macOS 14) shows only plain text, so this
// wraps an AppKit NSTextView via NSViewRepresentable. Highlighting is
// applied to the text storage's ATTRIBUTES only — the characters and
// the selection are never replaced — so typing, the cursor, and undo
// all behave normally.
//
// The highlighter (below) is deliberately simple: it colors keywords,
// types, strings, comments, and numbers with a few regexes. It is not
// a full Swift parser, and it doesn't need to be.
// ------------------------------------------------------------

import SwiftUI
import AppKit

struct CodeTextView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = Self.baseFont
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 6, height: 8)

        // Turn off "smart" substitutions — they corrupt code (curly quotes, etc.).
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false

        // Standard NSTextView-in-scroll-view sizing.
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.applyHighlighting()

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        // Only overwrite when the text changed from OUTSIDE (lesson switch,
        // Insert starter, clear). While the user types, text already matches,
        // so we don't touch the string — preserving the cursor position.
        if textView.string != text {
            textView.string = text
            context.coordinator.applyHighlighting()
        }
    }

    static let baseFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: CodeTextView
        weak var textView: NSTextView?

        init(_ parent: CodeTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            applyHighlighting()
        }

        func applyHighlighting() {
            guard let storage = textView?.textStorage else { return }
            SwiftHighlighter.highlight(storage, baseFont: CodeTextView.baseFont)
        }
    }
}

/// Applies simple Swift syntax coloring to a text storage's attributes.
enum SwiftHighlighter {

    // Compiled once and reused.
    private static let keywordRegex = try! NSRegularExpression(
        pattern: "\\b(let|var|func|return|if|else|guard|for|in|while|switch|case|default|struct|class|enum|throws|throw|do|try|catch|import|true|false|nil|self|some)\\b")
    private static let typeRegex = try! NSRegularExpression(
        pattern: "\\b(String|Int|Double|Bool|Error|View|Void)\\b")
    private static let numberRegex = try! NSRegularExpression(
        pattern: "\\b[0-9]+(\\.[0-9]+)?\\b")
    private static let stringRegex = try! NSRegularExpression(
        pattern: "\"(\\\\.|[^\"\\\\])*\"")
    private static let commentRegex = try! NSRegularExpression(
        pattern: "//[^\n]*")

    static func highlight(_ storage: NSTextStorage, baseFont: NSFont) {
        let full = NSRange(location: 0, length: storage.length)
        let text = storage.string

        storage.beginEditing()
        // Reset everything to the base look first.
        storage.setAttributes([.font: baseFont, .foregroundColor: NSColor.labelColor], range: full)

        color(numberRegex, in: text, storage: storage, color: .systemPurple)
        color(keywordRegex, in: text, storage: storage, color: .systemPink)
        color(typeRegex, in: text, storage: storage, color: .systemTeal)
        // Strings and comments last so their contents override keyword coloring.
        color(stringRegex, in: text, storage: storage, color: .systemRed)
        color(commentRegex, in: text, storage: storage, color: .secondaryLabelColor)

        storage.endEditing()
    }

    private static func color(_ regex: NSRegularExpression, in text: String, storage: NSTextStorage, color: NSColor) {
        let full = NSRange(location: 0, length: (text as NSString).length)
        regex.enumerateMatches(in: text, range: full) { match, _, _ in
            if let range = match?.range {
                storage.addAttribute(.foregroundColor, value: color, range: range)
            }
        }
    }
}
