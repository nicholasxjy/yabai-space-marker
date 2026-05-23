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
import ServiceManagement

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
final class AppSettings: ObservableObject {
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginDescription = ""
    @Published private(set) var launchAtLoginError: String?

    init(
        refreshLaunchAtLoginStatus: Bool = true
    ) {
        if refreshLaunchAtLoginStatus {
            refreshLaunchAtLoginStatusState()
        } else {
            launchAtLoginDescription = "Preview mode"
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = error.localizedDescription
        }

        refreshLaunchAtLoginStatusState()
    }

    func refreshLaunchAtLoginStatusState() {
        launchAtLoginError = nil

        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLoginEnabled = true
            launchAtLoginDescription = "Space Marker will launch automatically when you log in."
        case .requiresApproval:
            launchAtLoginEnabled = true
            launchAtLoginDescription = "macOS may still need approval in System Settings → Login Items."
        case .notRegistered:
            launchAtLoginEnabled = false
            launchAtLoginDescription = "Disabled. Launch manually whenever you need it."
        case .notFound:
            launchAtLoginEnabled = false
            launchAtLoginDescription = "Launch at login is unavailable for this build."
        @unknown default:
            launchAtLoginEnabled = false
            launchAtLoginDescription = "Unable to determine the current login item state."
        }
    }

}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLoginEnabled },
            set: { settings.setLaunchAtLogin($0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsHeroHeader()

                SettingsCard(
                    icon: "desktopcomputer",
                    title: "System",
                    description: "Control how Space Marker integrates with macOS."
                ) {
                    SettingsRow {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 16) {
                                SettingsRowHeader(
                                    title: "Launch at login",
                                    description: "Start Space Marker automatically after you sign in."
                                )

                                Spacer(minLength: 12)

                                Toggle("", isOn: launchAtLoginBinding)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }

                            Text(settings.launchAtLoginDescription)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            if let launchAtLoginError = settings.launchAtLoginError {
                                Text(launchAtLoginError)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                SettingsCard(
                    icon: "app.badge",
                    title: "App",
                    description: "Session-level controls for the current Space Marker app."
                ) {
                    SettingsRow {
                        HStack(alignment: .top, spacing: 16) {
                            SettingsRowHeader(
                                title: "Quit Space Marker",
                                description: "Close the floating panel and stop background refresh."
                            )

                            Spacer(minLength: 12)

                            Button("Quit", role: .destructive) {
                                NSApp.terminate(nil)
                            }
                            .controlSize(.large)
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(width: 560, height: 360)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            settings.refreshLaunchAtLoginStatusState()
        }
    }
}

private struct SettingsHeroHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.92),
                            Color.accentColor.opacity(0.62)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 28, weight: .semibold))

                Text("Adjust how Space Marker looks and integrates with your Mac.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let icon: String
    let title: String
    let description: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                SettingsSectionIcon(systemImage: icon)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))

                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            Divider()

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
    }
}

private struct SettingsSectionIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 30, height: 30)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct SettingsRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
    }
}

private struct SettingsRowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 18)
    }
}

private struct SettingsRowHeader: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))

            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    let settings = AppSettings()

    private lazy var monitor = YabaiSpacesMonitor(settings: settings)
    private var window: FloatingPanel?
    private var settingsWindowController: SettingsWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var isApplyingManagedWindowFrame = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
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

    func showSettingsWindow() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settings: settings)
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
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
        panel.level = .popUpMenu
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

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        hostingView.layer?.masksToBounds = false

        panel.contentView = hostingView
        panel.orderFrontRegardless()

        window = panel
        updateWindowFrame(animated: false)
    }

    private func bindWindowLayout() {
        monitor.$spaces
            .combineLatest(monitor.$errorMessage)
            .map { [weak self] _, _ in self?.panelSize() ?? .zero }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateWindowFrame(animated: true)
                }
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
                self?.monitor.refresh(trigger: .spaceChange)
            }
        }))

        observers.append((workspaceCenter, workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.monitor.suspendRefreshing()
            }
        }))

        observers.append((workspaceCenter, workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.monitor.resumeRefreshing()
            }
        }))

        if let window {
            observers.append((defaultCenter, defaultCenter.addObserver(
                forName: NSWindow.didMoveNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleWindowDidMove()
                }
            }))
        }
    }

    private func updateWindowFrame(animated: Bool) {
        guard let window else { return }

        let requestedSize = panelSize()
        let frame = resolvedWindowFrame(for: requestedSize, fallbackScreen: window.screen)

        if window.frame.integral == frame.integral {
            return
        }

        applyWindowFrame(frame)
    }

    private func panelSize() -> NSSize {
        NSSize(
            width: FloatingPanelMetrics.notchWidth + (FloatingPanelMetrics.notchAnimationInset * 2),
            height: FloatingPanelMetrics.notchHeight
        )
    }

    private func resolvedWindowFrame(for requestedSize: NSSize, fallbackScreen: NSScreen?) -> CGRect {
        let screen = anchorScreen() ?? fallbackScreen ?? NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.frame ?? CGRect(x: 0, y: 0, width: requestedSize.width, height: requestedSize.height)

        let width = min(requestedSize.width, max(220, screenFrame.width - (FloatingPanelMetrics.horizontalInset * 2)))
        let height = min(requestedSize.height, max(FloatingPanelMetrics.notchHeight, screenFrame.height - (FloatingPanelMetrics.topInset * 2)))
        let x = screenFrame.midX - (width / 2)
        let y = screenFrame.maxY - FloatingPanelMetrics.topInset - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func applyWindowFrame(_ frame: CGRect) {
        guard let window else { return }

        // Always set the window frame immediately — no NSAnimationContext.
        //
        // Using window.animator().setFrame() alongside SwiftUI’s spring transitions
        // causes a constraint-update feedback loop:
        //   NSAnimationContext frame tick → NSHostingView relayout
        //   → setNeedsUpdateConstraints → another frame tick → …
        // This overflows AppKit’s per-cycle constraint-pass budget and raises
        // NSGenericException: “more Update Constraints passes than views”.
        //
        // The SwiftUI jelly-spring transition already provides the visual motion;
        // the window only needs to be at the correct size for the content to render.
        isApplyingManagedWindowFrame = true
        window.setFrame(frame, display: false)
        isApplyingManagedWindowFrame = false
    }

    private func handleWindowDidMove() {
        guard let window, !isApplyingManagedWindowFrame else { return }

        let resolvedFrame = resolvedWindowFrame(for: panelSize(), fallbackScreen: window.screen)

        if resolvedFrame.integral != window.frame.integral {
            applyWindowFrame(resolvedFrame)
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

@MainActor
final class SettingsWindowController: NSWindowController {
    init(settings: AppSettings) {
        let hostingController = NSHostingController(rootView: SettingsView(settings: settings))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 560, height: 380))
        window.center()
        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
func openAppSettings() {
    AppDelegate.shared?.showSettingsWindow()
}
