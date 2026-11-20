import AppKit
import Quartz
import SwiftUI

/// Drives `QLPreviewPanel`. The panel needs a controller in the responder chain, which is provided by
/// `QuickLookHost` (an invisible NSView placed in the window via `QuickLookPreview`).
@MainActor
final class QuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    var urls: [URL] = []
    weak var hostView: NSView?

    func toggle(urls: [URL]) {
        guard let panel = QLPreviewPanel.shared() else { return }
        if QLPreviewPanel.sharedPreviewPanelExists() && panel.isVisible {
            panel.orderOut(nil)
            return
        }
        guard !urls.isEmpty else { return }
        self.urls = urls
        if let host = hostView, let window = host.window {
            window.makeFirstResponder(host)
        }
        panel.updateController()
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated { urls.count }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        MainActor.assumeIsolated { urls[index] as NSURL }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard let event, event.type == .keyDown, event.charactersIgnoringModifiers == " " else { return false }
        MainActor.assumeIsolated { panel.orderOut(nil) }
        return true
    }
}

final class QuickLookHost: NSView {
    weak var controller: QuickLookController?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = controller
        panel.delegate = controller
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " ", let controller {
            controller.toggle(urls: controller.urls)
        } else {
            super.keyDown(with: event)
        }
    }
}

struct QuickLookPreview: NSViewRepresentable {
    let controller: QuickLookController

    func makeNSView(context: Context) -> QuickLookHost {
        let view = QuickLookHost()
        view.controller = controller
        controller.hostView = view
        return view
    }

    func updateNSView(_ nsView: QuickLookHost, context: Context) {
        nsView.controller = controller
        controller.hostView = nsView
    }
}
