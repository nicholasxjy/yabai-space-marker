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
    static let notchHeight: CGFloat = 54
    static let statusWidth: CGFloat = 220
    static let switcherWidth: CGFloat = 136
    static let defaultCameraHousingReservedWidth: CGFloat = 308
    static let componentHeight: CGFloat = 50
    static let notchAnimationInset: CGFloat = 24
    static let animationSafeInset: CGFloat = 18
    static let unifiedContentWidth: CGFloat = statusWidth + switcherWidth
    static let unifiedPanelWidth: CGFloat = unifiedContentWidth + (animationSafeInset * 2)
    static let panelWidth: CGFloat = separatedPanelWidth(cameraHousingReservedWidth: defaultCameraHousingReservedWidth)
    static let notchWidth: CGFloat = panelWidth
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 0
    static let panelCornerRadius: CGFloat = 17
    static let controlButtonSize: CGFloat = 22
    static let spaceButtonSize: CGFloat = 30

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
    static let jellyAnimation = Animation.interpolatingSpring(mass: 0.8, stiffness: 310, damping: 13, initialVelocity: 0.55)
    static let liquidReleaseAnimation = Animation.interpolatingSpring(mass: 0.72, stiffness: 250, damping: 11, initialVelocity: 0.7)
    static let contentAnimation = Animation.easeOut(duration: 0.16)

    static func separatedContentWidth(cameraHousingReservedWidth: CGFloat) -> CGFloat {
        statusWidth + notchAnimationInset + cameraHousingReservedWidth + notchAnimationInset + switcherWidth
    }

    static func separatedPanelWidth(cameraHousingReservedWidth: CGFloat) -> CGFloat {
        separatedContentWidth(cameraHousingReservedWidth: cameraHousingReservedWidth) + (animationSafeInset * 2)
    }

    static func panelWidth(avoidsCameraHousing: Bool, cameraHousingReservedWidth: CGFloat = defaultCameraHousingReservedWidth) -> CGFloat {
        avoidsCameraHousing ? separatedPanelWidth(cameraHousingReservedWidth: cameraHousingReservedWidth) : unifiedPanelWidth
    }

    static func cameraHousingCenterX(avoidsCameraHousing: Bool, cameraHousingReservedWidth: CGFloat = defaultCameraHousingReservedWidth) -> CGFloat {
        avoidsCameraHousing
            ? animationSafeInset + statusWidth + notchAnimationInset + (cameraHousingReservedWidth / 2)
            : animationSafeInset + (unifiedContentWidth / 2)
    }

    static func switcherOriginX(avoidsCameraHousing: Bool, cameraHousingReservedWidth: CGFloat = defaultCameraHousingReservedWidth) -> CGFloat {
        avoidsCameraHousing
            ? animationSafeInset + statusWidth + notchAnimationInset + cameraHousingReservedWidth + notchAnimationInset
            : animationSafeInset + statusWidth
    }
}

@MainActor
final class NotchLayoutState: ObservableObject {
    @Published var avoidsCameraHousing = true
    @Published var placement: PanelPlacement = .top
    @Published var cameraHousingReservedWidth = FloatingPanelMetrics.defaultCameraHousingReservedWidth
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var monitor: YabaiSpacesMonitor
    @ObservedObject var notchLayout: NotchLayoutState

    @State private var isPointerHovering = false
    @State private var isSwitchPulsing = false
    @State private var isContentSettled = true
    @State private var isLiquidStretched = false

    private var theme: FloatingTheme {
        .resolve(for: colorScheme)
    }

    private var focusedSpaceID: Int? {
        monitor.focusedSpace?.id
    }

    var body: some View {
        NotchSpacePanel(
            spaces: monitor.spaces,
            focusedSpace: monitor.focusedSpace,
            isLoading: monitor.isLoading,
            errorMessage: monitor.errorMessage,
            isSwitchPulsing: isSwitchPulsing,
            isLiquidStretched: isLiquidStretched,
            isContentSettled: isContentSettled,
            isPointerHovering: isPointerHovering,
            avoidsCameraHousing: notchLayout.avoidsCameraHousing,
            cameraHousingReservedWidth: notchLayout.cameraHousingReservedWidth,
            placement: notchLayout.placement,
            theme: theme,
            openSettings: {
                openAppSettings()
            },
            quit: {
                NSApplication.shared.terminate(nil)
            }
        )
        .frame(
            width: FloatingPanelMetrics.panelWidth(
                avoidsCameraHousing: notchLayout.avoidsCameraHousing,
                cameraHousingReservedWidth: notchLayout.cameraHousingReservedWidth
            ),
            height: FloatingPanelMetrics.notchHeight,
            alignment: notchLayout.placement == .top ? .top : .bottom
        )
        .background(Color.clear)
        .contentShape(Rectangle())
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
    }

    private func playSpaceSwitchAnimation() {
        withAnimation(.easeOut(duration: 0.08)) {
            isContentSettled = false
            isSwitchPulsing = true
        }
        withAnimation(FloatingPanelMetrics.liquidReleaseAnimation) {
            isLiquidStretched = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(FloatingPanelMetrics.liquidReleaseAnimation) {
                isLiquidStretched = false
            }

            try? await Task.sleep(nanoseconds: 40_000_000)
            withAnimation(FloatingPanelMetrics.jellyAnimation) {
                isContentSettled = true
            }

            try? await Task.sleep(nanoseconds: 360_000_000)
            withAnimation(.easeOut(duration: 0.28)) {
                isSwitchPulsing = false
            }
        }
    }
}

private struct NotchSpacePanel: View {
    let spaces: [YabaiSpace]
    let focusedSpace: YabaiSpace?
    let isLoading: Bool
    let errorMessage: String?
    let isSwitchPulsing: Bool
    let isLiquidStretched: Bool
    let isContentSettled: Bool
    let isPointerHovering: Bool
    let avoidsCameraHousing: Bool
    let cameraHousingReservedWidth: CGFloat
    let placement: PanelPlacement
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
        Group {
            if avoidsCameraHousing {
                separatedBody
            } else {
                unifiedBody
            }
        }
        .scaleEffect(
            x: isLiquidStretched ? 1.012 : (isSwitchPulsing ? 0.996 : 1.0),
            y: isLiquidStretched ? 0.96 : (isSwitchPulsing ? 1.018 : 1.0),
            anchor: .top
        )
    }

    private var separatedBody: some View {
        HStack(spacing: FloatingPanelMetrics.notchAnimationInset) {
            currentSpaceStatus

            Color.clear
                .frame(width: cameraHousingReservedWidth)
                .allowsHitTesting(false)

            spaceSwitcher
        }
        .frame(
            width: FloatingPanelMetrics.separatedContentWidth(cameraHousingReservedWidth: cameraHousingReservedWidth),
            height: FloatingPanelMetrics.notchHeight,
            alignment: .top
        )
        .padding(.horizontal, FloatingPanelMetrics.animationSafeInset)
        .frame(
            width: FloatingPanelMetrics.panelWidth(
                avoidsCameraHousing: true,
                cameraHousingReservedWidth: cameraHousingReservedWidth
            ),
            height: FloatingPanelMetrics.notchHeight,
            alignment: placement == .top ? .top : .bottom
        )
    }

    private var unifiedBody: some View {
        HStack(spacing: 0) {
            currentSpaceStatus
                .shadow(color: .clear, radius: 0)

            spaceSwitcher
                .shadow(color: .clear, radius: 0)
        }
        .frame(
            width: FloatingPanelMetrics.unifiedContentWidth,
            height: FloatingPanelMetrics.componentHeight,
            alignment: .top
        )
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: FloatingPanelMetrics.panelCornerRadius, style: .continuous))
        .overlay(panelOverlay)
        .shadow(color: theme.panelShadow.opacity(theme.panelShadowOpacity), radius: 10, x: 0, y: 5)
        .padding(.horizontal, FloatingPanelMetrics.animationSafeInset)
        .frame(
            width: FloatingPanelMetrics.panelWidth(avoidsCameraHousing: false),
            height: FloatingPanelMetrics.notchHeight,
            alignment: placement == .top ? .top : .bottom
        )
    }

    private var currentSpaceStatus: some View {
        HStack(spacing: 13) {
            spaceBadge

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    statusDot

                    Text(statusText)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(hasError ? theme.errorAccent : theme.secondaryText)
                        .tracking(0.3)
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(hasError ? theme.errorText : theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                        .id(focusedSpace?.id ?? -1)
                        .transition(.opacity)

                    if let focusedSpace {
                        Text("D\(focusedSpace.display)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(isContentSettled ? 1 : 0.68)
            .blur(radius: isContentSettled ? 0 : 1.2)
        }
        .padding(.leading, 14)
        .padding(.trailing, 14)
        .frame(width: FloatingPanelMetrics.statusWidth, height: FloatingPanelMetrics.componentHeight)
        .background {
            if avoidsCameraHousing {
                panelBackground
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: FloatingPanelMetrics.panelCornerRadius, style: .continuous))
        .overlay {
            if avoidsCameraHousing {
                panelOverlay
            }
        }
        .shadow(color: avoidsCameraHousing ? theme.panelShadow.opacity(theme.panelShadowOpacity) : .clear, radius: avoidsCameraHousing ? 10 : 0, x: 0, y: 5)
    }

    private var spaceSwitcher: some View {
        HStack(spacing: 8) {
            spaceCountBadge

            HStack(spacing: 6) {
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
        .padding(.horizontal, 10)
        .frame(width: FloatingPanelMetrics.switcherWidth, height: FloatingPanelMetrics.componentHeight)
        .background {
            if avoidsCameraHousing {
                panelBackground
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: FloatingPanelMetrics.panelCornerRadius, style: .continuous))
        .overlay {
            if avoidsCameraHousing {
                RoundedRectangle(cornerRadius: FloatingPanelMetrics.panelCornerRadius, style: .continuous)
                    .stroke(theme.highlightBase.opacity(isPointerHovering ? 0.12 : 0.06), lineWidth: 0.8)
            }
        }
        .shadow(color: avoidsCameraHousing ? theme.panelShadow.opacity(theme.panelShadowOpacity) : .clear, radius: avoidsCameraHousing ? 10 : 0, x: 0, y: 5)
    }

    private var spaceCountBadge: some View {
        HStack(spacing: 2) {
            Text("\(focusedSpace?.index ?? 0)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(hasError ? theme.errorText : theme.primaryText)
                .contentTransition(.numericText())

            Text("/")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(hasError ? theme.errorAccent : theme.cyberYellow.opacity(0.82))

            Text("\(spaces.count)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(hasError ? theme.errorText : theme.primaryText)
                .contentTransition(.numericText())
        }
        .frame(width: 44, height: 26)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: hasError
                            ? [
                                theme.errorAccent.opacity(0.22),
                                Color.white.opacity(0.07)
                            ]
                            : [
                                theme.highlightBase.opacity(isSwitchPulsing ? 0.18 : 0.13),
                                theme.cyberYellow.opacity(isSwitchPulsing ? 0.16 : 0.10)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    hasError
                        ? theme.errorAccent.opacity(0.24)
                        : theme.cyberYellow.opacity(isSwitchPulsing ? 0.34 : 0.22),
                    lineWidth: 0.8
                )
        )
        .help("Current space \(focusedSpace?.index ?? 0) of \(spaces.count)")
    }

    private var spaceBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: hasError
                            ? [
                                theme.errorAccent.opacity(0.78),
                                theme.errorAccent.opacity(0.30)
                            ]
                            : [
                                theme.cyberCyan.opacity(isSwitchPulsing ? 0.92 : 0.72),
                                theme.cyberMagenta.opacity(isSwitchPulsing ? 0.78 : 0.54)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let focusedSpace {
                Text("\(focusedSpace.index)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.focusText)
                    .contentTransition(.numericText())
            } else {
                Image(systemName: hasError ? "exclamationmark" : "rectangle.3.group.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.focusText)
            }
        }
        .frame(width: 36, height: 36)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.highlightBase.opacity(isSwitchPulsing ? 0.42 : 0.22), lineWidth: 0.8)
        )
        .shadow(color: accent.opacity(isSwitchPulsing ? 0.34 : 0.18), radius: isSwitchPulsing ? 9 : 5, x: 0, y: 0)
    }

    private var statusDot: some View {
        Circle()
            .fill(accent)
            .frame(width: 5, height: 5)
            .shadow(color: accent.opacity(theme.statusDotGlowOpacity), radius: 5, x: 0, y: 0)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: FloatingPanelMetrics.panelCornerRadius, style: .continuous)
            .fill(theme.panelBase)
    }

    private var panelOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: FloatingPanelMetrics.panelCornerRadius, style: .continuous)
                .stroke(theme.highlightBase.opacity(isPointerHovering ? 0.16 : 0.08), lineWidth: 0.8)

            TopFlowLine(
                isActive: isSwitchPulsing,
                theme: theme
            )

            VStack(spacing: 0) {
                Spacer()

                LinearGradient(
                    colors: [
                        theme.highlightBase.opacity(isSwitchPulsing ? 0.18 : (isPointerHovering ? 0.11 : 0.06)),
                        theme.highlightBase.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 1)
                .padding(.horizontal, 18)
                .padding(.bottom, 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: FloatingPanelMetrics.panelCornerRadius, style: .continuous))
            .allowsHitTesting(false)
        }
    }
}

private struct TopFlowLine: View {
    let isActive: Bool
    let theme: FloatingTheme

    var body: some View {
        Group {
            if isActive {
                TimelineView(.animation) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                    let travel = sin(phase * 7.2)

                    HStack {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.cyberCyan.opacity(0.0),
                                        theme.cyberCyan.opacity(0.95),
                                        theme.cyberMagenta.opacity(0.92),
                                        theme.cyberYellow.opacity(0.68),
                                        theme.cyberCyan.opacity(0.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 96, height: 1.6)
                            .offset(x: travel * 88)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 0.8)
                    .clipShape(RoundedRectangle(cornerRadius: FloatingPanelMetrics.panelCornerRadius, style: .continuous))
                }
            }
        }
        .animation(.easeOut(duration: 0.24), value: isActive)
        .allowsHitTesting(false)
    }
}

private struct NativeNotchShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(cornerRadius, rect.width / 2, rect.height)

        path.move(to: rect.origin)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

private struct NotchIconButton: View {
    let systemImage: String
    let foreground: Color
    let tint: Color
    let theme: FloatingTheme

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: FloatingPanelMetrics.controlButtonSize, height: FloatingPanelMetrics.controlButtonSize)
            .background(
                Circle()
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                Circle()
                    .stroke(theme.highlightBase.opacity(0.10), lineWidth: 0.6)
            )
    }
}

private struct FloatingTheme: Equatable {
    let accentStart: Color
    let accentGlow: Color
    let cyberCyan: Color
    let cyberMagenta: Color
    let cyberYellow: Color

    let neutralTint: Color
    let panelBase: Color
    let primaryText: Color
    let secondaryText: Color
    let activeSpaceFill: Color
    let activeSpaceStroke: Color
    let activeSpaceText: Color
    let inactiveSpaceFill: Color
    let inactiveSpaceStroke: Color
    let inactiveSpaceText: Color

    let focusText: Color

    let errorAccent: Color
    let errorText: Color

    let highlightBase: Color
    let panelShadow: Color
    let previewBackground: Color

    let statusDotGlowOpacity: Double
    let panelShadowOpacity: Double

    static func resolve(for colorScheme: ColorScheme) -> FloatingTheme {
        colorScheme == .dark ? .dark : .light
    }

    static let light = FloatingTheme(
        accentStart: Color(red: 0.28, green: 0.92, blue: 0.62),
        accentGlow: Color.white,
        cyberCyan: Color(red: 0.00, green: 0.92, blue: 1.00),
        cyberMagenta: Color(red: 1.00, green: 0.10, blue: 0.74),
        cyberYellow: Color(red: 1.00, green: 0.92, blue: 0.25),
        neutralTint: Color.white,
        panelBase: Color(red: 0.005, green: 0.005, blue: 0.006),
        primaryText: Color.white.opacity(0.94),
        secondaryText: Color.white.opacity(0.52),
        activeSpaceFill: Color.white.opacity(0.96),
        activeSpaceStroke: Color.white.opacity(0.55),
        activeSpaceText: Color.black.opacity(0.94),
        inactiveSpaceFill: Color(red: 0.08, green: 0.11, blue: 0.16).opacity(0.96),
        inactiveSpaceStroke: Color.white.opacity(0.16),
        inactiveSpaceText: Color.white.opacity(0.72),
        focusText: Color.white.opacity(0.97),
        errorAccent: Color(red: 0.97, green: 0.31, blue: 0.36),
        errorText: Color(red: 1.00, green: 0.80, blue: 0.82),
        highlightBase: .white,
        panelShadow: .black,
        previewBackground: Color(red: 0.84, green: 0.87, blue: 0.92),
        statusDotGlowOpacity: 0.36,
        panelShadowOpacity: 0.32
    )

    static let dark = FloatingTheme(
        accentStart: Color(red: 0.28, green: 0.92, blue: 0.62),
        accentGlow: Color.white,
        cyberCyan: Color(red: 0.00, green: 0.92, blue: 1.00),
        cyberMagenta: Color(red: 1.00, green: 0.10, blue: 0.74),
        cyberYellow: Color(red: 1.00, green: 0.92, blue: 0.25),
        neutralTint: Color.white,
        panelBase: Color(red: 0.005, green: 0.005, blue: 0.006),
        primaryText: Color.white.opacity(0.94),
        secondaryText: Color.white.opacity(0.52),
        activeSpaceFill: Color.white.opacity(0.96),
        activeSpaceStroke: Color.white.opacity(0.55),
        activeSpaceText: Color.black.opacity(0.94),
        inactiveSpaceFill: Color(red: 0.08, green: 0.11, blue: 0.16).opacity(0.96),
        inactiveSpaceStroke: Color.white.opacity(0.16),
        inactiveSpaceText: Color.white.opacity(0.72),
        focusText: Color.white.opacity(0.98),
        errorAccent: Color(red: 1.00, green: 0.35, blue: 0.38),
        errorText: Color(red: 1.00, green: 0.83, blue: 0.86),
        highlightBase: .white,
        panelShadow: .black,
        previewBackground: Color(red: 0.02, green: 0.04, blue: 0.09),
        statusDotGlowOpacity: 0.36,
        panelShadowOpacity: 0.34
    )
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
    @MainActor private static let separatedPreviewLayout: NotchLayoutState = {
        let state = NotchLayoutState()
        state.avoidsCameraHousing = true
        return state
    }()
    @MainActor private static let unifiedPreviewLayout: NotchLayoutState = {
        let state = NotchLayoutState()
        state.avoidsCameraHousing = false
        return state
    }()

    static var previews: some View {
        Group {
            ContentView(monitor: YabaiSpacesMonitor(settings: previewSettings), notchLayout: separatedPreviewLayout)
                .padding(24)
                .background(FloatingTheme.light.previewBackground)
                .preferredColorScheme(.light)

            ContentView(monitor: YabaiSpacesMonitor(settings: previewSettings), notchLayout: unifiedPreviewLayout)
                .padding(24)
                .background(FloatingTheme.dark.previewBackground)
                .preferredColorScheme(.dark)
        }
    }
}
