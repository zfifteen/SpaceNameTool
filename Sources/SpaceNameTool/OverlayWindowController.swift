//
//  OverlayWindowController.swift
//  SpaceNameTool
//
//  Heads-Up bezel (FR-3). Lives only in this process.
//

import AppKit
import SpaceNameToolCore

/// Floating overlay for Space name display after a switch.
@MainActor
final class OverlayWindowController: NSWindowController {
    private var dismissWorkItem: DispatchWorkItem?
    private let label = NSTextField(labelWithString: "")

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 72),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) - 1)
        panel.ignoresMouseEvents = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let effect = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        effect.autoresizingMask = [.width, .height]
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true

        let label = NSTextField(labelWithString: "")
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        effect.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: effect.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: effect.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: effect.trailingAnchor, constant: -24)
        ])

        panel.contentView = effect
        self.init(window: panel)
        self.label.stringValue = ""
        // Keep reference via associated storage on panel content.
        self.storedLabel = label
    }

    private var storedLabel: NSTextField?

    func present(for space: SpaceRecord) {
        guard let window else { return }
        let text = space.displayName
        storedLabel?.stringValue = text
        storedLabel?.setAccessibilityLabel("Current Space: \(text)")

        // Size to fit text.
        storedLabel?.sizeToFit()
        let width = max(200, (storedLabel?.fittingSize.width ?? 120) + 48)
        var frame = window.frame
        frame.size = NSSize(width: width, height: 72)

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            frame.origin.x = visible.midX - frame.width / 2
            frame.origin.y = visible.midY - frame.height / 2
        }
        window.setFrame(frame, display: true)
        window.alphaValue = 0
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            window.animator().alphaValue = 1
        }

        dismissWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.fadeOut()
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    func dismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        window?.orderOut(nil)
        window?.alphaValue = 1
    }

    private func fadeOut() {
        guard let window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
            self?.window?.alphaValue = 1
        })
    }
}
