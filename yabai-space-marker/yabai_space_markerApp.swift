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

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }

    nonisolated static func resolve() -> AppAppearance {
        if let stored = UserDefaults.standard.string(forKey: "appearance")?.lowercased(),
           let appearance = AppAppearance(rawValue: stored) {
            return appearance
        }
        return .system
    }
}

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
    enum Keys {
        static let position = "position"
        static let autoCollapseDelay = "autoCollapseDelay"
        static let appearance = "appearance"
    }

    static let minimumAutoCollapseDelay = 0.5
    static let maximumAutoCollapseDelay = 10.0

    @Published var position: FloatingPanelPosition {
        didSet {
            guard oldValue != position else { return }
            UserDefaults.standard.set(position.rawValue, forKey: Keys.position)
        }
    }

    @Published var appearance: AppAppearance {
        didSet {
            guard oldValue != appearance else { return }
            UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance)
        }
    }

    @Published var autoCollapseDelay: Double {
        didSet {
            let clamped = Self.clampAutoCollapseDelay(autoCollapseDelay)
            if abs(autoCollapseDelay - clamped) > 0.001 {
                autoCollapseDelay = clamped
                return
            }

            UserDefaults.standard.set(clamped, forKey: Keys.autoCollapseDelay)
        }
    }

    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginDescription = ""
    @Published private(set) var launchAtLoginError: String?

    var preferredColorScheme: ColorScheme? {
        appearance.colorScheme
    }

    var windowAppearance: NSAppearance? {
        appearance.nsAppearance
    }

    init(
        position: FloatingPanelPosition = FloatingPanelPosition.resolve(),
        appearance: AppAppearance = AppAppearance.resolve(),
        autoCollapseDelay: Double? = nil,
        refreshLaunchAtLoginStatus: Bool = true
    ) {
        let storedDelay = UserDefaults.standard.object(forKey: Keys.autoCollapseDelay) as? Double
        self.position = position
        self.appearance = appearance
        self.autoCollapseDelay = Self.clampAutoCollapseDelay(autoCollapseDelay ?? storedDelay ?? FloatingPanelMetrics.defaultAutoCollapseDelay)

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

    private static func clampAutoCollapseDelay(_ value: Double) -> Double {
        min(max(value, minimumAutoCollapseDelay), maximumAutoCollapseDelay)
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
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Settings")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))

                    Text("Tune the floating space switcher position and how it launches.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                SettingsCard(title: "Panel") {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            SettingsRowHeader(
                                title: "Appearance",
                                description: "Choose whether the panel follows macOS or stays light/dark."
                            )

                            Picker("Appearance", selection: $settings.appearance) {
                                ForEach(AppAppearance.allCases) { appearance in
                                    Text(appearance.title).tag(appearance)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            SettingsRowHeader(
                                title: "Position",
                                description: "Choose whether the panel stays at the top or bottom of the current screen."
                            )

                            Picker("Position", selection: $settings.position) {
                                ForEach(FloatingPanelPosition.allCases) { position in
                                    Text(position.title).tag(position)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                SettingsRowHeader(
                                    title: "Auto-collapse timeout",
                                    description: "How long the panel stays expanded after interaction."
                                )

                                Spacer(minLength: 12)

                                Text("\(settings.autoCollapseDelay, specifier: "%.1f")s")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.quaternary.opacity(0.45), in: Capsule())
                            }

                            Slider(
                                value: $settings.autoCollapseDelay,
                                in: AppSettings.minimumAutoCollapseDelay...AppSettings.maximumAutoCollapseDelay,
                                step: 0.1
                            )
                        }
                    }
                }

                SettingsCard(title: "System") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: launchAtLoginBinding) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Launch at login")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                                Text("Start Space Marker automatically after you sign in.")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        Text(settings.launchAtLoginDescription)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        if let launchAtLoginError = settings.launchAtLoginError {
                            Text(launchAtLoginError)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.red)
                        }
                    }
                }

                SettingsCard(title: "App") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Quit Space Marker")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))

                            Text("Close the floating panel and stop background refresh.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 12)

                        Button("Quit", role: .destructive) {
                            NSApp.terminate(nil)
                        }
                        .controlSize(.large)
                    }
                }
            }
            .padding(20)
        }
        .frame(width: 480, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(settings.preferredColorScheme)
        .onAppear {
            settings.refreshLaunchAtLoginStatusState()
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct SettingsRowHeader: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))

            Text(description)
                .font(.system(size: 12, weight: .medium, design: .rounded))
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

        settingsWindowController?.applyAppearance(settings.windowAppearance)
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

        let rootView = ContentView(monitor: monitor, settings: settings)
            .background(Color.clear)

        panel.appearance = settings.windowAppearance

        panel.contentView = NSHostingView(rootView: rootView)
        panel.orderFrontRegardless()

        window = panel
        updateWindowFrame(animated: false)
    }

    private func bindWindowLayout() {
        monitor.$panelPresentation
            .combineLatest(monitor.$spaces, monitor.$errorMessage)
            .map { [weak self] _, _, _ in
                self?.panelSize() ?? .zero
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWindowFrame(animated: true)
            }
            .store(in: &cancellables)

        settings.$appearance
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyAppearance()
            }
            .store(in: &cancellables)

        settings.$position
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
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
    }

    private func applyAppearance() {
        window?.appearance = settings.windowAppearance
        settingsWindowController?.applyAppearance(settings.windowAppearance)
    }

    private func updateWindowFrame(animated: Bool) {
        guard let window else { return }

        let requestedSize = panelSize()
        let screen = window.screen ?? anchorScreen() ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: requestedSize.width, height: requestedSize.height)

        let width = min(requestedSize.width, max(220, visibleFrame.width - (FloatingPanelMetrics.horizontalInset * 2)))
        let height = min(requestedSize.height, max(60, visibleFrame.height - (FloatingPanelMetrics.topInset * 2)))

        let x = visibleFrame.midX - (width / 2)
        let y: CGFloat
        switch settings.position {
        case .top:
            y = visibleFrame.maxY - FloatingPanelMetrics.topInset - height
        case .bottom:
            y = visibleFrame.minY + FloatingPanelMetrics.topInset
        }
        let frame = NSRect(x: x, y: y, width: width, height: height)

        if window.frame.integral == frame.integral {
            return
        }

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
        window.setFrame(frame, display: false)
    }

    private func panelSize() -> NSSize {
        switch monitor.effectivePresentation {
        case .collapsed:
            return NSSize(
                width: FloatingPanelMetrics.collapsedWidth,
                height: FloatingPanelMetrics.collapsedHeight
            )
        case .expanded:
            return NSSize(
                width: FloatingPanelMetrics.expandedWidth,
                height: FloatingPanelMetrics.expandedHeight
            )
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
        window.setContentSize(NSSize(width: 480, height: 420))
        window.center()
        super.init(window: window)
        shouldCascadeWindows = false
    }

    func applyAppearance(_ appearance: NSAppearance?) {
        window?.appearance = appearance
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
