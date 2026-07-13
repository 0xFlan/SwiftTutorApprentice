import AppKit
import SwiftUI

/// Gives a hosted test a stable, non-accessibility identity for the native
/// viewport SwiftUI creates. The probe never reads or changes the viewport's
/// scroll position.
struct ScrollViewportProbe: NSViewRepresentable {
    let identifier: String

    func makeNSView(context: Context) -> ScrollViewportProbeView {
        ScrollViewportProbeView(identifier: identifier)
    }

    func updateNSView(_ nsView: ScrollViewportProbeView, context: Context) {
        nsView.viewportIdentifier = identifier
        nsView.tagNearestScrollView()
    }
}

final class ScrollViewportProbeView: NSView {
    var viewportIdentifier: String

    init(identifier: String) {
        viewportIdentifier = identifier
        super.init(frame: .zero)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        tagNearestScrollView()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        tagNearestScrollView()
        DispatchQueue.main.async { [weak self] in
            self?.tagNearestScrollView()
        }
    }

    func tagNearestScrollView() {
        var ancestor = superview
        while let view = ancestor {
            if let scrollView = view as? NSScrollView {
                scrollView.identifier = NSUserInterfaceItemIdentifier(viewportIdentifier)
                return
            }
            ancestor = view.superview
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
