//
//  ContentView.swift
//  yabai-space-marker
//
//  Created by 薛晶义 on 2026/5/15.
//

import SwiftUI
import Foundation
import AppKit
import Combine

enum FloatingPanelMetrics {
    static let notchWidth: CGFloat = 330
    static let notchHeight: CGFloat = 54
    static let notchAnimationInset: CGFloat = 12
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 10
    static let panelCornerRadius: CGFloat = 24
    static let controlButtonSize: CGFloat = 26

    static let refreshIntervalInteractive: TimeInterval = 2.0
    static let refreshIntervalIdle: TimeInterval = 10.0
    static let refreshIntervalLoading: TimeInterval = 1.25
    static let refreshIntervalError: TimeInterval = 8.0
    static let refreshTimerToleranceRatio: Double = 0.25
    static let focusRefreshDelay: TimeInterval = 0.18
    static let hoverRefreshStalenessThreshold: TimeInterval = 1.2
    static let eventRefreshDebounce: TimeInterval = 0.35
    static let queryCommandTimeout: TimeInterval = 1.0
    static let focusCommandTimeout: TimeInterval = 1.5
    static let processTerminationGracePeriod: TimeInterval = 0.12

    static let panelAnimation = Animation.spring(response: 0.28, dampingFraction: 0.78, blendDuration: 0.05)
    static let jellyAnimation = Animation.interpolatingSpring(mass: 0.85, stiffness: 360, damping: 18, initialVelocity: 0.35)
    static let contentAnimation = Animation.easeOut(duration: 0.16)
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var monitor: YabaiSpacesMonitor
    @ObservedObject var settings: AppSettings

    @State private var isPointerHovering = false
    @State private var isSwitchPulsing = false
    @State private var isContentSettled = true
    @State private var borderFlowPhase = false

    private var theme: FloatingTheme {
        .resolve(for: colorScheme)
    }

    private var focusedSpaceID: Int? {
        monitor.focusedSpace?.id
    }

    var body: some View {
        NotchSpacePanel(
            focusedSpace: monitor.focusedSpace,
            totalSpaces: monitor.spaces.count,
            isLoading: monitor.isLoading,
            errorMessage: monitor.errorMessage,
            isSwitchPulsing: isSwitchPulsing,
            isContentSettled: isContentSettled,
            isPointerHovering: isPointerHovering,
            borderFlowPhase: borderFlowPhase,
            theme: theme,
            openSettings: {
                openAppSettings()
            },
            quit: {
                NSApplication.shared.terminate(nil)
            }
        )
        .frame(width: FloatingPanelMetrics.notchWidth, height: FloatingPanelMetrics.notchHeight)
        .padding(.horizontal, FloatingPanelMetrics.notchAnimationInset)
        .frame(
            width: FloatingPanelMetrics.notchWidth + (FloatingPanelMetrics.notchAnimationInset * 2),
            height: FloatingPanelMetrics.notchHeight
        )
        .contentShape(RoundedRectangle(cornerRadius: FloatingPanelMetrics.panelCornerRadius, style: .continuous))
        .onHover { isHovering in
            isPointerHovering = isHovering
            monitor.setPointerInside(isHovering)
        }
        .onChange(of: focusedSpaceID) { oldValue, newValue in
            guard oldValue != newValue else { return }
            playSpaceSwitchAnimation()
        }
        .animation(FloatingPanelMetrics.panelAnimation, value: isPointerHovering)
        .contextMenu {
            Button("Settings...") {
                openAppSettings()
            }

            Button("Refresh") {
                monitor.refresh(trigger: .manual)
            }

            Divider()

            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        }
        .preferredColorScheme(settings.preferredColorScheme)
    }

    private func playSpaceSwitchAnimation() {
        withAnimation(.easeOut(duration: 0.08)) {
            isContentSettled = false
            isSwitchPulsing = true
            borderFlowPhase.toggle()
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 90_000_000)
            withAnimation(FloatingPanelMetrics.jellyAnimation) {
                isContentSettled = true
            }

            try? await Task.sleep(nanoseconds: 260_000_000)
            withAnimation(.easeOut(duration: 0.22)) {
                isSwitchPulsing = false
            }
        }
    }
}

private struct NotchSpacePanel: View {
    let focusedSpace: YabaiSpace?
    let totalSpaces: Int
    let isLoading: Bool
    let errorMessage: String?
    let isSwitchPulsing: Bool
    let isContentSettled: Bool
    let isPointerHovering: Bool
    let borderFlowPhase: Bool
    let theme: FloatingTheme
    let openSettings: () -> Void
    let quit: () -> Void

    private var hasError: Bool {
        errorMessage != nil
    }

    private var title: String {
        if let focusedSpace {
            return focusedSpace.title
        }
        if hasError {
            return "yabai unavailable"
        }
        return isLoading ? "Syncing spaces" : "Space Marker"
    }

    private var subtitle: String {
        if let focusedSpace {
            return totalSpaces > 0
                ? "Display \(focusedSpace.display) · \(totalSpaces) spaces"
                : "Display \(focusedSpace.display)"
        }
        if hasError {
            return "Check permissions"
        }
        return "Waiting for data"
    }

    private var statusText: String {
        if hasError {
            return "ERR"
        }
        if isLoading {
            return "SYNC"
        }
        return "LIVE"
    }

    private var accent: Color {
        hasError ? theme.errorAccent : theme.accentStart
    }

    var body: some View {
        HStack(spacing: 11) {
            spaceBadge

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    statusDot

                    Text(statusText)
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(hasError ? theme.errorAccent : theme.accentEnd)
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(hasError ? theme.errorText : theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .id(focusedSpace?.id ?? -1)
                    .transition(.opacity)

                Text(subtitle)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(isContentSettled ? 1 : 0.62)
            .blur(radius: isContentSettled ? 0 : 1.3)

            rightControls
        }
        .padding(.leading, 13)
        .padding(.trailing, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: FloatingPanelMetrics.panelCornerRadius, style: .continuous))
        .overlay(panelOverlay)
        .scaleEffect(x: isSwitchPulsing ? 1.045 : (isPointerHovering ? 1.015 : 1.0), y: isSwitchPulsing ? 0.965 : 1.0)
        .shadow(color: theme.panelShadow.opacity(theme.panelShadowOpacity), radius: 13, x: 0, y: 8)
    }

    private var spaceBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(hasError ? 0.82 : 0.95),
                            (hasError ? theme.errorAccent : theme.accentEnd).opacity(0.62)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let focusedSpace {
                Text("\(focusedSpace.index)")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.focusText)
                    .contentTransition(.numericText())
            } else {
                Image(systemName: hasError ? "exclamationmark" : "rectangle.3.group.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.focusText)
            }
        }
        .frame(width: 39, height: 38)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.highlightBase.opacity(0.34), lineWidth: 0.8)
        )
        .shadow(color: accent.opacity(isSwitchPulsing ? 0.42 : 0.22), radius: isSwitchPulsing ? 12 : 7, x: 0, y: 0)
    }

    private var statusDot: some View {
        Circle()
            .fill(accent)
            .frame(width: 5, height: 5)
            .shadow(color: accent.opacity(theme.statusDotGlowOpacity), radius: 5, x: 0, y: 0)
    }

    private var rightControls: some View {
        HStack(spacing: 11) {
            totalSpacesBadge

            VStack(spacing: 4) {
                Button(action: openSettings) {
                    NotchIconButton(systemImage: "gearshape.fill", foreground: theme.primaryText, tint: theme.neutralTint, theme: theme)
                }
                .buttonStyle(.plain)
                .help("Open settings")

                Button(action: quit) {
                    NotchIconButton(systemImage: "power", foreground: theme.errorText, tint: theme.errorAccent, theme: theme)
                }
                .buttonStyle(.plain)
                .help("Quit Space Marker")
            }
        }
    }

    private var totalSpacesBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.neutralTint.opacity(0.92),
                            theme.accentGlow.opacity(0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.46)
                    .tint(theme.accentEnd)
                    .frame(width: 14, height: 14)
            } else {
                Text("\(totalSpaces)")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(hasError ? theme.errorText : theme.primaryText)
                    .contentTransition(.numericText())
            }
        }
        .frame(width: 39, height: 38)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.highlightBase.opacity(0.26), lineWidth: 0.8)
        )
        .overlay(alignment: .bottom) {
            Text("ALL")
                .font(.system(size: 5, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.secondaryText)
                .padding(.bottom, 3)
        }
        .shadow(color: theme.accentGlow.opacity(isSwitchPulsing ? 0.28 : 0.14), radius: isSwitchPulsing ? 10 : 6, x: 0, y: 0)
    }

    private var panelBackground: some View {
        LiquidGlassSurface(
            cornerRadius: FloatingPanelMetrics.panelCornerRadius,
            tint: accent,
            tintStrength: hasError ? 0.14 : (isSwitchPulsing ? 0.22 : 0.11),
            fillOpacity: isPointerHovering ? 0.24 : 0.2,
            highlightOpacity: isSwitchPulsing ? 0.9 : 0.74,
            theme: theme
        )
    }

    private var cyberCyan: Color {
        Color(red: 0.00, green: 0.92, blue: 1.00)
    }

    private var cyberPink: Color {
        Color(red: 1.00, green: 0.18, blue: 0.82)
    }

    private var cyberYellow: Color {
        Color(red: 1.00, green: 0.96, blue: 0.18)
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: borderFlowPhase
                ? [
                    cyberPink.opacity(isSwitchPulsing ? 0.92 : 0.34),
                    cyberYellow.opacity(isSwitchPulsing ? 0.86 : 0.22),
                    cyberCyan.opacity(isSwitchPulsing ? 0.96 : 0.36),
                    accent.opacity(isSwitchPulsing ? 0.66 : 0.20),
                    cyberPink.opacity(isSwitchPulsing ? 0.90 : 0.30)
                ]
                : [
                    cyberCyan.opacity(isSwitchPulsing ? 0.96 : 0.36),
                    accent.opacity(isSwitchPulsing ? 0.66 : 0.20),
                    cyberPink.opacity(isSwitchPulsing ? 0.92 : 0.34),
                    cyberYellow.opacity(isSwitchPulsing ? 0.86 : 0.22),
                    cyberCyan.opacity(isSwitchPulsing ? 0.92 : 0.30)
                ],
            startPoint: borderFlowPhase ? .topTrailing : .topLeading,
            endPoint: borderFlowPhase ? .bottomLeading : .bottomTrailing
        )
    }

    private var panelOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: FloatingPanelMetrics.panelCornerRadius, style: .continuous)
                .stroke(borderGradient, lineWidth: isSwitchPulsing ? 4.0 : 1.4)
                .blur(radius: isSwitchPulsing ? 3.2 : 1.0)
                .opacity(isSwitchPulsing ? 0.96 : (isPointerHovering ? 0.38 : 0.22))

            RoundedRectangle(cornerRadius: FloatingPanelMetrics.panelCornerRadius, style: .continuous)
                .stroke(borderGradient, lineWidth: isSwitchPulsing ? 1.8 : 0.9)
                .shadow(color: cyberCyan.opacity(isSwitchPulsing ? 0.46 : 0.10), radius: isSwitchPulsing ? 8 : 2, x: 0, y: 0)
                .shadow(color: cyberPink.opacity(isSwitchPulsing ? 0.40 : 0.08), radius: isSwitchPulsing ? 10 : 2, x: 0, y: 0)

            VStack(spacing: 0) {
                Spacer()

                LinearGradient(
                    colors: [
                        Color.black.opacity(theme.bottomShadowOpacity),
                        Color.black.opacity(0.0)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: FloatingPanelMetrics.panelCornerRadius, style: .continuous))
            .allowsHitTesting(false)
        }
    }
}

private struct NotchIconButton: View {
    let systemImage: String
    let foreground: Color
    let tint: Color
    let theme: FloatingTheme

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 8.5, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: 18, height: 17)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.34),
                                tint.opacity(0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(theme.highlightBase.opacity(0.30))
                    .frame(width: 9, height: 1)
                    .padding(.top, 3)
            }
    }
}

private struct FloatingTheme: Equatable {
    let id: Int
    let accentStart: Color
    let accentEnd: Color
    let accentGlow: Color

    let neutralTint: Color
    let panelBase: Color
    let primaryText: Color
    let secondaryText: Color

    let lineStrong: Color
    let focusText: Color

    let errorAccent: Color
    let errorText: Color

    let materialTail: Color
    let highlightBase: Color
    let panelShadow: Color
    let previewBackground: Color

    let statusDotGlowOpacity: Double
    let panelShadowOpacity: Double
    let bottomShadowOpacity: Double

    static func resolve(for colorScheme: ColorScheme) -> FloatingTheme {
        colorScheme == .dark ? .dark : .light
    }

    static let light = FloatingTheme(
        id: 0,
        accentStart: Color(red: 0.10, green: 0.86, blue: 1.00),
        accentEnd: Color(red: 0.48, green: 0.43, blue: 1.00),
        accentGlow: Color(red: 0.76, green: 0.98, blue: 1.00),
        neutralTint: Color(red: 0.86, green: 0.92, blue: 1.00),
        panelBase: Color(red: 0.86, green: 0.90, blue: 0.99),
        primaryText: Color(red: 0.05, green: 0.07, blue: 0.12),
        secondaryText: Color(red: 0.25, green: 0.33, blue: 0.46),
        lineStrong: Color.white.opacity(0.96),
        focusText: Color.white.opacity(0.97),
        errorAccent: Color(red: 0.97, green: 0.31, blue: 0.36),
        errorText: Color(red: 0.52, green: 0.11, blue: 0.14),
        materialTail: Color(red: 0.93, green: 0.90, blue: 1.00),
        highlightBase: .white,
        panelShadow: .black,
        previewBackground: Color(red: 0.90, green: 0.94, blue: 1.00),
        statusDotGlowOpacity: 0.52,
        panelShadowOpacity: 0.10,
        bottomShadowOpacity: 0.10
    )

    static let dark = FloatingTheme(
        id: 1,
        accentStart: Color(red: 0.00, green: 0.88, blue: 1.00),
        accentEnd: Color(red: 0.42, green: 0.28, blue: 1.00),
        accentGlow: Color(red: 0.38, green: 0.97, blue: 1.00),
        neutralTint: Color(red: 0.08, green: 0.10, blue: 0.17),
        panelBase: Color(red: 0.03, green: 0.05, blue: 0.12),
        primaryText: Color(red: 0.92, green: 0.97, blue: 1.00),
        secondaryText: Color(red: 0.61, green: 0.74, blue: 0.92),
        lineStrong: Color.white.opacity(0.28),
        focusText: Color.white.opacity(0.98),
        errorAccent: Color(red: 1.00, green: 0.35, blue: 0.38),
        errorText: Color(red: 1.00, green: 0.83, blue: 0.86),
        materialTail: Color(red: 0.10, green: 0.02, blue: 0.18),
        highlightBase: .white,
        panelShadow: .black,
        previewBackground: Color(red: 0.02, green: 0.04, blue: 0.09),
        statusDotGlowOpacity: 0.72,
        panelShadowOpacity: 0.30,
        bottomShadowOpacity: 0.24
    )
}

private struct LiquidGlassSurface: View {
    let cornerRadius: CGFloat
    let tint: Color
    let tintStrength: CGFloat
    let fillOpacity: CGFloat
    let highlightOpacity: CGFloat
    let theme: FloatingTheme

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.panelBase.opacity(fillOpacity * 0.95),
                            tint.opacity(tintStrength * 0.45),
                            theme.materialTail.opacity(fillOpacity * 0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.highlightBase.opacity(highlightOpacity), theme.highlightBase.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: max(12, cornerRadius * 0.72))
                .padding(.horizontal, 8)
                .padding(.top, 5)

            Rectangle()
                .fill(tint.opacity(tintStrength * 0.85))
                .frame(height: 1.1)
                .padding(.horizontal, 18)
                .padding(.top, 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(theme.lineStrong.opacity(0.7), lineWidth: 0.8)
        )
    }
}

struct YabaiSpace: Codable, Identifiable, Equatable {
    let id: Int
    let index: Int
    let label: String?
    let display: Int
    let hasFocus: Bool

    var title: String {
        if let label, !label.isEmpty {
            return label
        }
        return "Space \(index)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case index
        case label
        case display
        case hasFocus = "has-focus"
    }
}

@MainActor
final class YabaiSpacesMonitor: ObservableObject {
    enum RefreshTrigger {
        case startup
        case timer
        case manual
        case spaceChange
        case focusRequest
        case hover
    }

    @Published private(set) var spaces: [YabaiSpace] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private(set) var lastUpdated: Date?
    private var isPointerInside = false
    private var isRefreshing = false
    private var isSuspended = false

    private let executableURL: URL?
    private var refreshTimer: Timer?
    private var followUpRefreshTask: Task<Void, Never>?
    private var hasLoadedSnapshot = false
    private var lastRefreshStartedAt: Date?

    nonisolated private static let queryTimeout: TimeInterval = 1.0
    nonisolated private static let focusTimeout: TimeInterval = 1.5
    nonisolated private static let terminationGracePeriod: TimeInterval = 0.12

    init(settings: AppSettings) {
        self.executableURL = Self.resolveExecutableURL()
    }

    deinit {
        refreshTimer?.invalidate()
        followUpRefreshTask?.cancel()
    }

    var focusedSpace: YabaiSpace? {
        spaces.first(where: \.hasFocus)
    }

    func start() {
        guard refreshTimer == nil else { return }
        refresh(trigger: .startup)
    }

    func suspendRefreshing() {
        guard !isSuspended else { return }
        isSuspended = true
        refreshTimer?.invalidate()
        refreshTimer = nil
        followUpRefreshTask?.cancel()
        followUpRefreshTask = nil
    }

    func resumeRefreshing() {
        guard isSuspended else { return }
        isSuspended = false

        if hasLoadedSnapshot {
            scheduleFollowUpRefresh(after: 0.1, trigger: .timer)
        } else {
            refresh(trigger: .startup)
        }
    }

    func setPointerInside(_ isInside: Bool) {
        guard isPointerInside != isInside else { return }
        isPointerInside = isInside
        scheduleNextRefresh()

        guard isInside else { return }
        guard shouldRefreshSoonForHover else { return }
        scheduleFollowUpRefresh(after: 0.05, trigger: .hover)
    }

    func refresh(trigger: RefreshTrigger = .manual) {
        guard !isSuspended else { return }

        if shouldSkipRefresh(for: trigger) {
            scheduleDeferredRefresh(for: trigger)
            return
        }

        guard !isRefreshing else {
            scheduleDeferredRefresh(for: trigger)
            return
        }

        isRefreshing = true
        let shouldShowLoading = shouldSurfaceLoadingState(for: trigger)
        if shouldShowLoading, !isLoading {
            isLoading = true
        }
        lastRefreshStartedAt = .now

        let executableURL = self.executableURL

        Task.detached(priority: .utility) {
            let result = Result { try Self.querySpaces(using: executableURL) }
            await MainActor.run {
                self.isRefreshing = false
                if self.isLoading {
                    self.isLoading = false
                }

                switch result {
                case .success(let spaces):
                    let sortedSpaces = spaces.sorted { $0.index < $1.index }

                    if self.spaces != sortedSpaces {
                        self.spaces = sortedSpaces
                    }
                    if self.errorMessage != nil {
                        self.errorMessage = nil
                    }
                    self.lastUpdated = .now
                    self.hasLoadedSnapshot = true

                case .failure(let error):
                    let message = error.localizedDescription
                    if self.errorMessage != message {
                        self.errorMessage = message
                    }
                }

                self.scheduleNextRefresh()
            }
        }
    }

    func focus(space: YabaiSpace) {
        guard !space.hasFocus else {
            refresh(trigger: .focusRequest)
            return
        }

        let executableURL = self.executableURL
        let focusTimeout = Self.focusTimeout
        Task.detached(priority: .userInitiated) {
            let result = Result {
                try Self.runYabai(
                    arguments: ["-m", "space", "--focus", "\(space.index)"],
                    timeout: focusTimeout,
                    using: executableURL
                )
            }

            await MainActor.run {
                if case .failure(let error) = result {
                    self.errorMessage = error.localizedDescription
                    self.scheduleNextRefresh()
                    return
                }

                self.scheduleFollowUpRefresh(after: FloatingPanelMetrics.focusRefreshDelay, trigger: .focusRequest)
            }
        }
    }

    private func scheduleDeferredRefresh(for trigger: RefreshTrigger) {
        if trigger == .timer {
            scheduleNextRefresh()
            return
        }
        scheduleFollowUpRefresh(after: FloatingPanelMetrics.eventRefreshDebounce, trigger: trigger)
    }

    private func scheduleFollowUpRefresh(after delay: TimeInterval, trigger: RefreshTrigger) {
        guard !isSuspended else { return }
        followUpRefreshTask?.cancel()
        followUpRefreshTask = Task { @MainActor [weak self] in
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled, let self else { return }
            self.refresh(trigger: trigger)
        }
    }

    private func scheduleNextRefresh() {
        refreshTimer?.invalidate()
        guard !isSuspended else {
            refreshTimer = nil
            return
        }

        let interval = nextRefreshInterval
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let monitor = self else { return }
            Task { @MainActor [monitor] in
                monitor.refresh(trigger: .timer)
            }
        }
        timer.tolerance = max(0.15, interval * FloatingPanelMetrics.refreshTimerToleranceRatio)
        refreshTimer = timer
    }

    private var nextRefreshInterval: TimeInterval {
        if errorMessage != nil {
            return FloatingPanelMetrics.refreshIntervalError
        }
        if isLoading || spaces.isEmpty {
            return FloatingPanelMetrics.refreshIntervalLoading
        }
        if isPointerInside {
            return FloatingPanelMetrics.refreshIntervalInteractive
        }
        return FloatingPanelMetrics.refreshIntervalIdle
    }

    private var shouldRefreshSoonForHover: Bool {
        guard !isLoading else { return false }
        guard let lastUpdated else { return true }
        return Date.now.timeIntervalSince(lastUpdated) >= FloatingPanelMetrics.hoverRefreshStalenessThreshold
    }

    private func shouldSurfaceLoadingState(for trigger: RefreshTrigger) -> Bool {
        if !hasLoadedSnapshot || spaces.isEmpty || errorMessage != nil {
            return true
        }

        switch trigger {
        case .manual, .spaceChange, .focusRequest, .startup:
            return true
        case .timer, .hover:
            return false
        }
    }

    private func shouldSkipRefresh(for trigger: RefreshTrigger) -> Bool {
        guard trigger != .manual, trigger != .startup else { return false }
        guard let lastRefreshStartedAt else { return false }

        return Date.now.timeIntervalSince(lastRefreshStartedAt) < FloatingPanelMetrics.eventRefreshDebounce
    }

    nonisolated private static let decoder = JSONDecoder()

    nonisolated private static func querySpaces(using executableURL: URL?) throws -> [YabaiSpace] {
        let data = try runYabai(
            arguments: ["-m", "query", "--spaces"],
            timeout: queryTimeout,
            using: executableURL
        )
        return try decoder.decode([YabaiSpace].self, from: data)
    }

    nonisolated private static func runYabai(arguments: [String], timeout: TimeInterval, using executableURL: URL?) throws -> Data {
        guard let executableURL else {
            throw YabaiMonitorError.executableNotFound
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            finished.signal()
        }

        try process.run()

        if finished.wait(timeout: .now() + timeout) == .timedOut, process.isRunning {
            process.interrupt()
            Thread.sleep(forTimeInterval: terminationGracePeriod)
            if process.isRunning {
                process.terminate()
                Thread.sleep(forTimeInterval: terminationGracePeriod)
            }
            throw YabaiMonitorError.commandTimedOut(arguments.joined(separator: " "))
        }

        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorOutput, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw YabaiMonitorError.commandFailed(message ?? "yabai exited with code \(process.terminationStatus).")
        }

        return output
    }

    nonisolated private static func resolveExecutableURL() -> URL? {
        let fileManager = FileManager.default
        var candidates: [String] = []

        if let explicitPath = ProcessInfo.processInfo.environment["YABAI_BIN"] {
            candidates.append(explicitPath)
        }

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map { "\($0)/yabai" })
        }

        candidates.append(contentsOf: [
            "/opt/homebrew/bin/yabai",
            "/opt/homebrew/sbin/yabai",
            "/usr/local/bin/yabai",
            "/usr/local/sbin/yabai"
        ])

        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }

        return nil
    }
}

enum YabaiMonitorError: LocalizedError {
    case executableNotFound
    case commandFailed(String)
    case commandTimedOut(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Could not find the yabai executable. Set YABAI_BIN or install yabai in /opt/homebrew/bin."
        case .commandFailed(let message):
            return message
        case .commandTimedOut(let command):
            return "Timed out while running: \(command)"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    @MainActor private static let previewSettings: AppSettings = {
        AppSettings(refreshLaunchAtLoginStatus: false)
    }()

    static var previews: some View {
        Group {
            ContentView(monitor: YabaiSpacesMonitor(settings: previewSettings), settings: previewSettings)
                .padding(24)
                .background(FloatingTheme.light.previewBackground)
                .preferredColorScheme(.light)

            ContentView(monitor: YabaiSpacesMonitor(settings: previewSettings), settings: previewSettings)
                .padding(24)
                .background(FloatingTheme.dark.previewBackground)
                .preferredColorScheme(.dark)
        }
    }
}
