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
    static let expandedWidth: CGFloat = 620
    static let collapsedWidth: CGFloat = 248
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 12

    static let expandedHeight: CGFloat = 112
    static let collapsedHeight: CGFloat = 60
    static let panelCornerRadius: CGFloat = 24

    static let currentCardWidth: CGFloat = 160
    static let sliderHeight: CGFloat = 64
    static let sliderChipHeight: CGFloat = 48
    static let controlButtonSize: CGFloat = 28

    static let panelPadding: CGFloat = 12
    static let collapsedHorizontalPadding: CGFloat = 18
    static let panelSpacing: CGFloat = 10
    static let sliderSpacing: CGFloat = 8

    static let defaultAutoCollapseDelay: TimeInterval = 2.6
    static let refreshIntervalInteractive: TimeInterval = 2.0
    static let refreshIntervalCollapsedIdle: TimeInterval = 10.0
    static let refreshIntervalLoading: TimeInterval = 1.25
    static let refreshIntervalError: TimeInterval = 8.0
    static let refreshTimerToleranceRatio: Double = 0.25
    static let focusRefreshDelay: TimeInterval = 0.18
    static let hoverRefreshStalenessThreshold: TimeInterval = 1.2
    static let eventRefreshDebounce: TimeInterval = 0.35
    static let queryCommandTimeout: TimeInterval = 1.0
    static let focusCommandTimeout: TimeInterval = 1.5
    static let processTerminationGracePeriod: TimeInterval = 0.12
    // Jelly spring — expand: bouncy overshoot from center outward
    static let jellyExpandAnimation  = Animation.spring(response: 0.34, dampingFraction: 0.82, blendDuration: 0.08)
    // Jelly spring — collapse: high damping to avoid negative-value overshoot on removal
    static let jellyCollapseAnimation = Animation.spring(response: 0.26, dampingFraction: 0.90, blendDuration: 0.06)
    // Panel frame resize — silky spring
    static let panelAnimation  = Animation.spring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.08)
    // Inner content cross-fades
    static let contentAnimation = Animation.easeOut(duration: 0.16)
    // Pure opacity fades
    static let fadeAnimation   = Animation.easeInOut(duration: 0.22)
    static let snapAnimation   = Animation.easeInOut(duration: 0.16)
    static let edgeSnapThreshold: CGFloat = 28
    static let cornerSnapThreshold: CGFloat = 34
    static let dragEndDebounce: TimeInterval = 0.14
}

enum FloatingPanelPresentation: Equatable {
    case collapsed
    case expanded
}

enum FloatingPanelPosition: String, CaseIterable, Identifiable {
    case top
    case bottom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top:
            return "Top"
        case .bottom:
            return "Bottom"
        }
    }

    nonisolated static func resolve() -> FloatingPanelPosition {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--position"), arguments.indices.contains(index + 1) {
            let raw = arguments[index + 1].lowercased()
            if let position = FloatingPanelPosition(rawValue: raw) {
                return position
            }
            if raw == "left" { return .top }
            if raw == "right" { return .bottom }
        }

        if let environmentValue = ProcessInfo.processInfo.environment["YABAI_SPACE_MARKER_POSITION"]?.lowercased() {
            if let position = FloatingPanelPosition(rawValue: environmentValue) {
                return position
            }
            if environmentValue == "left" { return .top }
            if environmentValue == "right" { return .bottom }
        }

        if let defaultsValue = UserDefaults.standard.string(forKey: "position")?.lowercased() {
            if let position = FloatingPanelPosition(rawValue: defaultsValue) {
                return position
            }
            if defaultsValue == "left" { return .top }
            if defaultsValue == "right" { return .bottom }
        }

        return .top
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var monitor: YabaiSpacesMonitor
    @ObservedObject var settings: AppSettings
    @State private var isCollapsedPanelHovering = false

    private var theme: FloatingTheme {
        .resolve(for: colorScheme)
    }

    private var isExpanded: Bool {
        monitor.effectivePresentation == .expanded
    }

    private var focusedSpace: YabaiSpace? {
        monitor.focusedSpace
    }

    private var compactTitle: String {
        if let focusedSpace {
            if let label = focusedSpace.label, !label.isEmpty {
                return "\(label) \(focusedSpace.index)"
            }
            return "Space \(focusedSpace.index)"
        }

        if monitor.errorMessage != nil {
            return "yabai unavailable"
        }

        return monitor.isLoading ? "syncing spaces" : "space marker"
    }

    private var compactSubtitle: String {
        if let focusedSpace {
            return "Display \(focusedSpace.display)"
        }

        if monitor.errorMessage != nil {
            return "Check permissions"
        }

        return monitor.spaces.isEmpty ? "No spaces" : "Ready"
    }

    private var statusBadgeText: String {
        if monitor.errorMessage != nil {
            return "Alert"
        }

        if monitor.isLoading {
            return "Syncing"
        }

        return focusedSpace == nil ? "Idle" : "Live"
    }

    private var headerSummary: String {
        if monitor.errorMessage != nil {
            return "yabai needs attention"
        }

        if monitor.spaces.isEmpty {
            return monitor.isLoading ? "Refreshing spaces…" : "No spaces available"
        }

        if let focusedSpace {
            return "\(monitor.spaces.count) spaces · Display \(focusedSpace.display) · Space \(focusedSpace.index)"
        }

        return "\(monitor.spaces.count) spaces ready"
    }

    var body: some View {
        Group {
            if isExpanded {
                expandedPanel
            } else {
                collapsedPanel
            }
        }
        .frame(
            width: isExpanded ? FloatingPanelMetrics.expandedWidth : FloatingPanelMetrics.collapsedWidth,
            height: isExpanded ? FloatingPanelMetrics.expandedHeight : FloatingPanelMetrics.collapsedHeight
        )
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: FloatingPanelMetrics.panelCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: FloatingPanelMetrics.panelCornerRadius, style: .continuous))
        .onHover {
            monitor.setPointerInside($0)
            if !isExpanded {
                isCollapsedPanelHovering = $0
            }
        }
        // panelAnimation handles implicit property animations (background tint, shadow etc.)
        // that are NOT the panel expand/collapse transition itself.
        // The transition is driven by withAnimation inside setPanelPresentation.
        .animation(FloatingPanelMetrics.panelAnimation, value: isCollapsedPanelHovering)
        .contextMenu {
            Button("Settings…") {
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

    private var expandedPanel: some View {
        HStack(spacing: FloatingPanelMetrics.panelSpacing) {
            Button {
                openAppSettings()
            } label: {
                PanelActionButton(
                    systemImage: "slider.horizontal.3",
                    foreground: theme.primaryText,
                    tint: theme.neutralTint,
                    theme: theme
                )
            }
            .buttonStyle(.plain)
            .help("Open settings")

            CurrentSpaceCard(
                focusedSpace: focusedSpace,
                isLoading: monitor.isLoading,
                hasError: monitor.errorMessage != nil,
                totalSpaces: monitor.spaces.count,
                statusText: statusBadgeText,
                theme: theme
            )
            .frame(width: FloatingPanelMetrics.currentCardWidth)

            Group {
                if let errorMessage = monitor.errorMessage {
                    StateRailCard(
                        title: "Yabai unavailable",
                        message: errorMessage,
                        systemImage: "exclamationmark.triangle.fill",
                        tint: theme.errorAccent,
                        textColor: theme.errorText,
                        theme: theme
                    )
                } else if monitor.spaces.isEmpty {
                    StateRailCard(
                        title: monitor.isLoading ? "Refreshing spaces" : "No spaces yet",
                        message: monitor.isLoading
                            ? "Trying to fetch the latest workspace state."
                            : "Create or expose spaces in yabai and they will appear here.",
                        systemImage: monitor.isLoading ? "arrow.triangle.2.circlepath" : "rectangle.3.group.fill",
                        tint: theme.accentStart,
                        textColor: theme.primaryText,
                        theme: theme
                    )
                } else {
                    SpaceSliderRail(spaces: monitor.spaces, theme: theme) { space in
                        monitor.focus(space: space)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                PanelActionButton(
                    systemImage: "power",
                    foreground: theme.errorText,
                    tint: theme.errorAccent,
                    theme: theme
                )
            }
            .buttonStyle(.plain)
            .help("Quit Space Marker")
        }
        .padding(FloatingPanelMetrics.panelPadding)
    }

    private var collapsedPanel: some View {
        HStack(spacing: 10) {
            Button {
                openAppSettings()
            } label: {
                PanelActionButton(
                    systemImage: "slider.horizontal.3",
                    foreground: theme.primaryText,
                    tint: theme.neutralTint,
                    theme: theme
                )
            }
            .buttonStyle(.plain)
            .help("Open settings")

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(monitor.errorMessage == nil ? theme.accentStart : theme.errorAccent)
                        .frame(width: 5, height: 5)
                        .shadow(
                            color: (monitor.errorMessage == nil ? theme.accentStart : theme.errorAccent).opacity(0.35),
                            radius: 4,
                            x: 0,
                            y: 0
                        )

                    Text(statusBadgeText.uppercased())
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(monitor.errorMessage == nil ? theme.accentEnd : theme.errorAccent)
                }

                Text(compactTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(monitor.errorMessage == nil ? theme.primaryText : theme.errorText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(compactSubtitle)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                PanelActionButton(
                    systemImage: "power",
                    foreground: theme.errorText,
                    tint: theme.errorAccent,
                    theme: theme
                )
            }
            .buttonStyle(.plain)
            .help("Quit Space Marker")
        }
        .padding(.horizontal, FloatingPanelMetrics.collapsedHorizontalPadding)
        .padding(.vertical, 10)
    }

    private var panelBackground: some View {
        let collapsedHovering = !isExpanded && isCollapsedPanelHovering

        return LiquidGlassSurface(
            cornerRadius: FloatingPanelMetrics.panelCornerRadius,
            tint: monitor.errorMessage == nil
                ? (isExpanded ? theme.neutralTone : theme.neutralTint)
                : theme.errorAccent,
            tintStrength: monitor.errorMessage == nil
                ? (isExpanded ? 0.12 : (collapsedHovering ? 0.11 : 0.08))
                : 0.1,
            fillOpacity: isExpanded ? 0.2 : (collapsedHovering ? 0.24 : 0.2),
            highlightOpacity: isExpanded ? 0.78 : (collapsedHovering ? 0.76 : 0.7),
            theme: theme
        )
        .shadow(
            color: theme.panelShadow.opacity(isExpanded ? theme.expandedShadowOpacity : (collapsedHovering ? theme.collapsedShadowOpacity + 0.02 : theme.collapsedShadowOpacity)),
            radius: isExpanded ? 18 : (collapsedHovering ? 14 : 12),
            x: 0,
            y: isExpanded ? 12 : (collapsedHovering ? 10 : 8)
        )
    }
}

/// A ViewModifier that interpolates scale, opacity and blur from a centre anchor.
/// Must conform to Animatable so SwiftUI can interpolate between `active` and
private struct FloatingTheme: Equatable {
    let id: Int
    let accentStart: Color
    let accentEnd: Color
    let accentGlow: Color
    let accentHot: Color

    let neutralTint: Color
    let neutralTone: Color
    let neutralGlow: Color
    let panelBase: Color
    let chromeGlow: Color

    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color

    let lineSoft: Color
    let lineStrong: Color
    let surfaceWash: Color

    let focusTint: Color
    let focusGlow: Color
    let focusDeep: Color
    let focusText: Color

    let errorAccent: Color
    let errorBackground: Color
    let errorText: Color

    let materialFill: Color
    let materialTail: Color
    let highlightBase: Color
    let panelShadow: Color
    let previewBackground: Color

    let statusDotGlowOpacity: Double
    let expandedShadowOpacity: Double
    let collapsedShadowOpacity: Double
    let expandedGlowOpacity: Double
    let collapsedGlowOpacity: Double

    static func resolve(for colorScheme: ColorScheme) -> FloatingTheme {
        colorScheme == .dark ? .dark : .light
    }

    static let light = FloatingTheme(
        id: 0,
        accentStart: Color(red: 0.10, green: 0.86, blue: 1.00),
        accentEnd: Color(red: 0.48, green: 0.43, blue: 1.00),
        accentGlow: Color(red: 0.76, green: 0.98, blue: 1.00),
        accentHot: Color(red: 0.98, green: 0.31, blue: 0.75),
        neutralTint: Color(red: 0.86, green: 0.92, blue: 1.00),
        neutralTone: Color(red: 0.65, green: 0.75, blue: 0.95),
        neutralGlow: Color(red: 0.91, green: 0.97, blue: 1.00),
        panelBase: Color(red: 0.86, green: 0.90, blue: 0.99),
        chromeGlow: Color(red: 0.66, green: 0.45, blue: 0.98),
        primaryText: Color(red: 0.05, green: 0.07, blue: 0.12),
        secondaryText: Color(red: 0.25, green: 0.33, blue: 0.46),
        tertiaryText: Color(red: 0.37, green: 0.43, blue: 0.58),
        lineSoft: Color.white.opacity(0.72),
        lineStrong: Color.white.opacity(0.96),
        surfaceWash: Color.white.opacity(0.26),
        focusTint: Color(red: 0.00, green: 0.77, blue: 1.00),
        focusGlow: Color(red: 0.48, green: 0.92, blue: 1.00),
        focusDeep: Color(red: 0.07, green: 0.16, blue: 0.38),
        focusText: Color.white.opacity(0.97),
        errorAccent: Color(red: 0.97, green: 0.31, blue: 0.36),
        errorBackground: Color(red: 1.00, green: 0.92, blue: 0.93),
        errorText: Color(red: 0.52, green: 0.11, blue: 0.14),
        materialFill: .white,
        materialTail: Color(red: 0.93, green: 0.90, blue: 1.00),
        highlightBase: .white,
        panelShadow: .black,
        previewBackground: Color(red: 0.90, green: 0.94, blue: 1.00),
        statusDotGlowOpacity: 0.52,
        expandedShadowOpacity: 0.12,
        collapsedShadowOpacity: 0.08,
        expandedGlowOpacity: 0.14,
        collapsedGlowOpacity: 0.10
    )

    static let dark = FloatingTheme(
        id: 1,
        accentStart: Color(red: 0.00, green: 0.88, blue: 1.00),
        accentEnd: Color(red: 0.42, green: 0.28, blue: 1.00),
        accentGlow: Color(red: 0.38, green: 0.97, blue: 1.00),
        accentHot: Color(red: 1.00, green: 0.24, blue: 0.76),
        neutralTint: Color(red: 0.08, green: 0.10, blue: 0.17),
        neutralTone: Color(red: 0.14, green: 0.16, blue: 0.28),
        neutralGlow: Color(red: 0.27, green: 0.32, blue: 0.52),
        panelBase: Color(red: 0.03, green: 0.05, blue: 0.12),
        chromeGlow: Color(red: 0.74, green: 0.22, blue: 1.00),
        primaryText: Color(red: 0.92, green: 0.97, blue: 1.00),
        secondaryText: Color(red: 0.61, green: 0.74, blue: 0.92),
        tertiaryText: Color(red: 0.46, green: 0.57, blue: 0.74),
        lineSoft: Color.white.opacity(0.12),
        lineStrong: Color.white.opacity(0.28),
        surfaceWash: Color.white.opacity(0.09),
        focusTint: Color(red: 0.00, green: 0.72, blue: 1.00),
        focusGlow: Color(red: 0.30, green: 0.94, blue: 1.00),
        focusDeep: Color(red: 0.05, green: 0.11, blue: 0.22),
        focusText: Color.white.opacity(0.98),
        errorAccent: Color(red: 1.00, green: 0.35, blue: 0.38),
        errorBackground: Color(red: 0.24, green: 0.08, blue: 0.12),
        errorText: Color(red: 1.00, green: 0.83, blue: 0.86),
        materialFill: .black,
        materialTail: Color(red: 0.10, green: 0.02, blue: 0.18),
        highlightBase: .white,
        panelShadow: .black,
        previewBackground: Color(red: 0.02, green: 0.04, blue: 0.09),
        statusDotGlowOpacity: 0.72,
        expandedShadowOpacity: 0.36,
        collapsedShadowOpacity: 0.28,
        expandedGlowOpacity: 0.24,
        collapsedGlowOpacity: 0.14
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
                .frame(height: max(12, cornerRadius * 0.78))
                .padding(.horizontal, 8)
                .padding(.top, 5)

            Rectangle()
                .fill(tint.opacity(tintStrength * 0.85))
                .frame(height: 1.2)
                .padding(.horizontal, 18)
                .padding(.top, 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(theme.lineStrong.opacity(0.7), lineWidth: 0.8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(tint.opacity(tintStrength * 0.72), lineWidth: 0.65)
        )
    }
}

private struct PanelGrabber: View {
    let theme: FloatingTheme

    var body: some View {
        Capsule(style: .continuous)
            .fill(theme.lineStrong.opacity(0.92))
            .frame(width: 42, height: 5)
            .overlay(
                Capsule(style: .continuous)
                    .fill(theme.highlightBase.opacity(0.35))
                    .blur(radius: 0.4)
            )
            .opacity(0.9)
    }
}

private struct StatusPill: View {
    let text: String
    let isError: Bool
    let theme: FloatingTheme

    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.9)
            .foregroundStyle(isError ? theme.errorText : theme.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                LiquidGlassSurface(
                    cornerRadius: 12,
                    tint: isError ? theme.errorAccent : theme.accentEnd,
                    tintStrength: isError ? 0.16 : 0.12,
                    fillOpacity: 0.16,
                    highlightOpacity: 0.58,
                    theme: theme
                )
            )
    }
}

private struct CurrentSpaceCard: View {
    let focusedSpace: YabaiSpace?
    let isLoading: Bool
    let hasError: Bool
    let totalSpaces: Int
    let statusText: String
    let theme: FloatingTheme

    private var title: String {
        if let focusedSpace {
            return focusedSpace.title
        }
        if hasError {
            return "Needs attention"
        }
        return isLoading ? "Syncing spaces" : "Space Marker"
    }

    private var subtitle: String {
        if let focusedSpace {
            return "Display \(focusedSpace.display) · \(totalSpaces) total"
        }
        if hasError {
            return "Check yabai"
        }
        return totalSpaces == 0 ? "Waiting for data" : "\(totalSpaces) spaces ready"
    }

    private var pillTint: Color {
        hasError ? theme.errorAccent : theme.focusTint
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                (hasError ? theme.errorAccent : theme.focusTint).opacity(0.9),
                                (hasError ? theme.errorAccent : theme.accentGlow).opacity(0.58)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let focusedSpace {
                    Text("\(focusedSpace.index)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(theme.focusText)
                        .contentTransition(.numericText())
                } else {
                    Image(systemName: hasError ? "exclamationmark" : (isLoading ? "arrow.triangle.2.circlepath" : "rectangle.3.group.fill"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(theme.focusText)
                }
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 5) {
                StatusPill(text: statusText, isError: hasError, theme: theme)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            LiquidGlassSurface(
                cornerRadius: 22,
                tint: pillTint,
                tintStrength: 0.14,
                fillOpacity: 0.22,
                highlightOpacity: 0.76,
                theme: theme
            )
        )
        .overlay(alignment: .topTrailing) {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.accentStart.opacity(0.0), theme.accentEnd.opacity(0.55)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 26, height: 2)
                .padding(.top, 10)
                .padding(.trailing, 12)
        }
    }
}

private struct StateRailCard: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color
    let textColor: Color
    let theme: FloatingTheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(tint.opacity(0.22), lineWidth: 0.8)
                    )

                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(textColor)
                    .lineLimit(1)

                Text(message)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(textColor.opacity(0.76))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: FloatingPanelMetrics.sliderHeight, alignment: .leading)
        .background(
            LiquidGlassSurface(
                cornerRadius: 22,
                tint: tint,
                tintStrength: 0.1,
                fillOpacity: 0.16,
                highlightOpacity: 0.68,
                theme: theme
            )
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(tint.opacity(0.68))
                .frame(width: 5, height: 5)
                .padding(.top, 10)
                .padding(.trailing, 12)
        }
    }
}

private struct SpaceSliderRail: View {
    let spaces: [YabaiSpace]
    let theme: FloatingTheme
    let focusAction: (YabaiSpace) -> Void

    private var focusedID: Int? {
        spaces.first(where: \.hasFocus)?.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FloatingPanelMetrics.sliderSpacing) {
                    ForEach(spaces) { space in
                        Button {
                            focusAction(space)
                        } label: {
                            SpaceChip(space: space, theme: theme)
                        }
                        .buttonStyle(.plain)
                        .id(space.id)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity, minHeight: FloatingPanelMetrics.sliderHeight, maxHeight: FloatingPanelMetrics.sliderHeight)
            .background(
                LiquidGlassSurface(
                    cornerRadius: 24,
                    tint: theme.neutralTone,
                    tintStrength: 0.06,
                    fillOpacity: 0.14,
                    highlightOpacity: 0.64,
                    theme: theme
                )
            )
            .onAppear {
                scrollToFocused(using: proxy, animated: false)
            }
            .onChange(of: focusedID) { _, _ in
                scrollToFocused(using: proxy, animated: true)
            }
        }
    }

    private func scrollToFocused(using proxy: ScrollViewProxy, animated: Bool) {
        guard let focusedID else { return }

        if animated {
            withAnimation(FloatingPanelMetrics.contentAnimation) {
                proxy.scrollTo(focusedID, anchor: .center)
            }
        } else {
            proxy.scrollTo(focusedID, anchor: .center)
        }
    }
}

private struct SpaceChip: View {
    let space: YabaiSpace
    let theme: FloatingTheme

    private var title: String {
        if let label = space.label, !label.isEmpty {
            return label
        }
        return "Space \(space.index)"
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(space.hasFocus ? theme.focusText.opacity(0.18) : theme.lineSoft.opacity(0.16))

                Text("\(space.index)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(space.hasFocus ? theme.focusText : theme.primaryText)
                    .contentTransition(.numericText())
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(space.hasFocus ? theme.focusText : theme.primaryText)
                    .lineLimit(1)

                Text("Display \(space.display)")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(space.hasFocus ? theme.focusText.opacity(0.82) : theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if space.hasFocus {
                Capsule(style: .continuous)
                    .fill(theme.focusText.opacity(0.22))
                    .frame(width: 8, height: 28)
            }
        }
        .padding(.horizontal, 12)
        .frame(width: space.hasFocus ? 150 : 126, height: FloatingPanelMetrics.sliderChipHeight, alignment: .leading)
        .background(
            LiquidGlassSurface(
                cornerRadius: 20,
                tint: space.hasFocus ? theme.focusTint : theme.neutralTint,
                tintStrength: space.hasFocus ? 0.24 : 0.06,
                fillOpacity: space.hasFocus ? 0.2 : 0.13,
                highlightOpacity: space.hasFocus ? 0.82 : 0.62,
                theme: theme
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(space.hasFocus ? theme.focusGlow.opacity(0.9) : theme.lineSoft.opacity(0.18), lineWidth: space.hasFocus ? 1 : 0.6)
        )
        .overlay(alignment: .bottomLeading) {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: space.hasFocus
                            ? [theme.accentStart.opacity(0.9), theme.accentEnd.opacity(0.7)]
                            : [theme.lineSoft.opacity(0.0), theme.lineSoft.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: space.hasFocus ? 34 : 0, height: 2)
                .padding(.leading, 12)
                .padding(.bottom, 9)
        }
        .animation(FloatingPanelMetrics.contentAnimation, value: space.hasFocus)
    }
}

private struct PanelControls: View {
    let theme: FloatingTheme
    let isLoading: Bool
    let openSettings: () -> Void
    let refresh: () -> Void
    let quit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: openSettings) {
                PanelActionButton(systemImage: "slider.horizontal.3", foreground: theme.primaryText, tint: theme.neutralTint, theme: theme)
            }
            .buttonStyle(.plain)
            .help("Open settings")

            Button(action: refresh) {
                PanelActionButton(
                    systemImage: isLoading ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise",
                    foreground: theme.primaryText,
                    tint: theme.accentStart,
                    theme: theme
                )
            }
            .buttonStyle(.plain)
            .help("Refresh spaces")

            Button(action: quit) {
                PanelActionButton(systemImage: "power", foreground: theme.errorText, tint: theme.errorAccent, theme: theme)
            }
            .buttonStyle(.plain)
            .help("Quit Space Marker")
        }
    }
}

private struct PanelActionButton: View {
    let systemImage: String
    let foreground: Color
    let tint: Color
    let theme: FloatingTheme

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: FloatingPanelMetrics.controlButtonSize, height: FloatingPanelMetrics.controlButtonSize)
            .background(
                LiquidGlassSurface(
                    cornerRadius: FloatingPanelMetrics.controlButtonSize * 0.5,
                    tint: tint,
                    tintStrength: 0.1,
                    fillOpacity: 0.16,
                    highlightOpacity: 0.7,
                    theme: theme
                )
            )
            .overlay(
                Circle()
                    .stroke(tint.opacity(0.12), lineWidth: 0.8)
                    .padding(2)
            )
            .overlay(alignment: .topTrailing) {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.45))
                    .frame(width: 7, height: 2)
                    .padding(.top, 5)
                    .padding(.trailing, 4)
            }
            .shadow(color: tint.opacity(0.14), radius: 6, x: 0, y: 0)
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
    @Published private(set) var panelPresentation: FloatingPanelPresentation

    private(set) var lastUpdated: Date?
    private var isPointerInside = false
    private var isRefreshing = false
    private var isSuspended = false

    private let executableURL: URL?
    private var refreshTimer: Timer?
    private var collapseTask: Task<Void, Never>?
    private var followUpRefreshTask: Task<Void, Never>?
    private var hasLoadedSnapshot = false
    private var lastRefreshStartedAt: Date?

    nonisolated private static let queryTimeout: TimeInterval = 1.0
    nonisolated private static let focusTimeout: TimeInterval = 1.5
    nonisolated private static let terminationGracePeriod: TimeInterval = 0.12

    private let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    init(settings: AppSettings) {
        self.settings = settings
        self.executableURL = Self.resolveExecutableURL()
        self.panelPresentation = .collapsed

        settings.$autoCollapseDelay
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.handleAutoCollapseDelayChanged()
            }
            .store(in: &cancellables)
    }

    deinit {
        refreshTimer?.invalidate()
        collapseTask?.cancel()
        followUpRefreshTask?.cancel()
    }

    var focusedSpace: YabaiSpace? {
        spaces.first(where: \.hasFocus)
    }

    var effectivePresentation: FloatingPanelPresentation {
        if errorMessage != nil || spaces.isEmpty {
            return .expanded
        }
        return panelPresentation
    }

    func start() {
        guard refreshTimer == nil else { return }
        refresh(trigger: .startup)
    }

    func revealPanelTemporarily() {
        setPanelPresentation(.expanded)
        scheduleAutoCollapseIfNeeded()
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

        if trigger != .timer, trigger != .hover {
            revealPanelTemporarily()
        }

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
        let previousFocusedID = focusedSpace?.id
        let previousSpaces = spaces
        let hadError = errorMessage != nil

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
                    let newFocusedID = sortedSpaces.first(where: \.hasFocus)?.id
                    let focusChanged = previousFocusedID != newFocusedID
                    let snapshotChanged = previousSpaces != sortedSpaces
                    let shouldReveal = !self.hasLoadedSnapshot || hadError || focusChanged || (trigger != .timer && trigger != .hover)

                    if snapshotChanged {
                        self.spaces = sortedSpaces
                    }
                    if self.errorMessage != nil {
                        self.errorMessage = nil
                    }
                    self.lastUpdated = .now
                    self.hasLoadedSnapshot = true

                    if shouldReveal {
                        self.revealPanelTemporarily()
                    }
                case .failure(let error):
                    let message = error.localizedDescription
                    if self.errorMessage != message {
                        self.errorMessage = message
                    }
                    self.setPanelPresentation(.expanded)
                    self.cancelAutoCollapse()
                }

                self.scheduleNextRefresh()
            }
        }
    }

    func focus(space: YabaiSpace) {
        guard !space.hasFocus else {
            revealPanelTemporarily()
            return
        }

        revealPanelTemporarily()

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
                    self.setPanelPresentation(.expanded)
                    self.cancelAutoCollapse()
                    self.scheduleNextRefresh()
                    return
                }

                self.scheduleFollowUpRefresh(after: FloatingPanelMetrics.focusRefreshDelay, trigger: .focusRequest)
            }
        }
    }

    private func setPanelPresentation(_ presentation: FloatingPanelPresentation) {
        guard panelPresentation != presentation else { return }
        // Choose the animation based on direction so that:
        //   expand → bouncy jelly spring (overshoot gives the "burst from centre" feel)
        //   collapse → tighter spring (snaps back to centre cleanly without overshoot)
        let animation: Animation = presentation == .expanded
            ? FloatingPanelMetrics.jellyExpandAnimation
            : FloatingPanelMetrics.jellyCollapseAnimation
        withAnimation(animation) {
            panelPresentation = presentation
        }
    }

    private func scheduleAutoCollapseIfNeeded() {
        guard errorMessage == nil, !spaces.isEmpty else {
            cancelAutoCollapse()
            return
        }

        cancelAutoCollapse()

        collapseTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let delay = UInt64(self.settings.autoCollapseDelay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            self.setPanelPresentation(.collapsed)
        }
    }

    private func cancelAutoCollapse() {
        collapseTask?.cancel()
        collapseTask = nil
    }

    private func handleAutoCollapseDelayChanged() {
        guard panelPresentation == .expanded else { return }
        scheduleAutoCollapseIfNeeded()
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
        if isPointerInside || effectivePresentation == .expanded {
            return FloatingPanelMetrics.refreshIntervalInteractive
        }
        return FloatingPanelMetrics.refreshIntervalCollapsedIdle
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
        AppSettings(position: .top, autoCollapseDelay: FloatingPanelMetrics.defaultAutoCollapseDelay, refreshLaunchAtLoginStatus: false)
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
