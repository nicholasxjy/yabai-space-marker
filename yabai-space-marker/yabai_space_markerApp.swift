//
//  yabai_space_markerApp.swift
//  yabai-space-marker
//
//  Created by 薛晶义 on 2026/5/15.
//

import SwiftUI
import AppKit
import Combine
import QuartzCore

@main
struct yabai_space_markerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = YabaiSpacesMonitor()
    private var window: FloatingPanel?
    private var cancellables = Set<AnyCancellable>()
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createWindow()
        bindWindowLayout()
        observeSystemChanges()
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        for (center, token) in observers {
            center.removeObserver(token)
        }
    }

    private func createWindow() {
        let initialSize = panelSize()
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: initialSize.width, height: initialSize.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = false
        panel.animationBehavior = .none
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false

        let rootView = ContentView(monitor: monitor)
            .background(Color.clear)

        panel.contentView = NSHostingView(rootView: rootView)
        panel.orderFrontRegardless()

        window = panel
        updateWindowFrame(animated: false)
    }

    private func bindWindowLayout() {
        monitor.$panelPresentation
            .combineLatest(monitor.$spaces, monitor.$errorMessage, monitor.$isLoading)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
                self?.updateWindowFrame(animated: true)
            }
            .store(in: &cancellables)
    }

    private func observeSystemChanges() {
        let defaultCenter = NotificationCenter.default
        observers.append((defaultCenter, defaultCenter.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateWindowFrame(animated: false)
            }
        }))

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        observers.append((workspaceCenter, workspaceCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.window?.orderFrontRegardless()
                self?.monitor.revealPanelTemporarily()
                self?.monitor.refresh(trigger: .spaceChange)
            }
        }))
    }

    private func updateWindowFrame(animated: Bool) {
        guard let window else { return }

        let size = panelSize()
        let screen = anchorScreen() ?? window.screen ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: size.width, height: size.height)

        let x = visibleFrame.minX + FloatingPanelMetrics.horizontalInset
        let y = visibleFrame.midY - (size.height / 2)
        let frame = NSRect(x: x, y: y, width: size.width, height: size.height)

        guard animated else {
            window.setFrame(frame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = FloatingPanelMetrics.frameAnimationDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.9, 0.22, 1.0)
            window.animator().setFrame(frame, display: true)
        }
    }

    private func panelSize() -> NSSize {
        switch monitor.effectivePresentation {
        case .collapsed:
            return NSSize(
                width: FloatingPanelMetrics.collapsedWidth,
                height: FloatingPanelMetrics.collapsedHeight
            )
        case .expanded:
            let bodyHeight: CGFloat

            if monitor.errorMessage != nil || monitor.spaces.isEmpty {
                bodyHeight = FloatingPanelMetrics.statusHeight
            } else {
                let itemCount = CGFloat(monitor.spaces.count)
                let spacingCount = CGFloat(max(monitor.spaces.count - 1, 0))
                bodyHeight = (itemCount * FloatingPanelMetrics.itemHeight) + (spacingCount * FloatingPanelMetrics.itemSpacing)
            }

            let height = max(
                FloatingPanelMetrics.expandedMinimumHeight,
                (FloatingPanelMetrics.verticalPadding * 2)
                    + FloatingPanelMetrics.headerHeight
                    + FloatingPanelMetrics.footerHeight
                    + (FloatingPanelMetrics.bodySpacing * 2)
                    + bodyHeight
            )

            return NSSize(width: FloatingPanelMetrics.expandedWidth, height: height)
        }
    }

    private func anchorScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }
}

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
