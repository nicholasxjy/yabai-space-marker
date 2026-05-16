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
    static let expandedWidth: CGFloat = 248
    static let collapsedWidth: CGFloat = 94
    static let horizontalInset: CGFloat = 12

    static let expandedMinimumHeight: CGFloat = 152
    static let headerHeight: CGFloat = 42
    static let footerHeight: CGFloat = 30
    static let statusHeight: CGFloat = 68
    static let itemHeight: CGFloat = 44
    static let itemSpacing: CGFloat = 6
    static let bodySpacing: CGFloat = 6
    static let verticalPadding: CGFloat = 10

    static let collapsedHeight: CGFloat = 128
    static let collapsedPadding: CGFloat = 9
    static let collapsedSpacing: CGFloat = 6
    static let collapsedHeaderHeight: CGFloat = 24
    static let compactCardHeight: CGFloat = 46

    static let autoCollapseDelay: TimeInterval = 2.6
    static let frameAnimationDuration: TimeInterval = 0.36
    static let panelAnimation = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.74, blendDuration: 0.16)
    static let contentAnimation = Animation.interactiveSpring(response: 0.28, dampingFraction: 0.78, blendDuration: 0.1)
    static let fadeAnimation = Animation.easeInOut(duration: 0.18)
}

enum FloatingPanelPresentation: Equatable {
    case collapsed
    case expanded
}

struct ContentView: View {
    @ObservedObject var monitor: YabaiSpacesMonitor

    private var isExpanded: Bool {
        monitor.effectivePresentation == .expanded
    }

    private var focusedSpace: YabaiSpace? {
        monitor.focusedSpace
    }

    private var summaryText: String {
        if monitor.errorMessage != nil {
            return "yabai needs attention before spaces can sync."
        }

        if monitor.isLoading && monitor.spaces.isEmpty {
            return "Syncing your spaces and preparing quick switching."
        }

        if let focusedSpace {
            return "\(monitor.spaces.count) spaces ready. \(focusedSpace.title) is active now."
        }

        return "Keep every workspace one click away from anywhere."
    }

    private var statusBadgeText: String {
        if monitor.errorMessage != nil {
            return "Alert"
        }

        if monitor.isLoading {
            return "Syncing"
        }

        return "Live"
    }

    private var footerText: String {
        if monitor.errorMessage != nil {
            return "Check yabai permissions and refresh."
        }

        if monitor.spaces.isEmpty {
            return monitor.isLoading ? "Looking for active spaces…" : "Open a few spaces to populate the list."
        }

        return "Click any space to focus it instantly."
    }

    var body: some View {
        Group {
            if isExpanded {
                expandedPanel
                    .transition(
                        .asymmetric(
                            insertion: .modifier(
                                active: JellyMorphModifier(opacity: 0.0, xOffset: -18, scaleX: 0.92, scaleY: 1.06, blur: 1.4),
                                identity: JellyMorphModifier(opacity: 1.0, xOffset: 0, scaleX: 1.0, scaleY: 1.0, blur: 0)
                            ).animation(FloatingPanelMetrics.fadeAnimation),
                            removal: .modifier(
                                active: JellyMorphModifier(opacity: 0.0, xOffset: 8, scaleX: 0.98, scaleY: 0.94, blur: 1.2),
                                identity: JellyMorphModifier(opacity: 1.0, xOffset: 0, scaleX: 1.0, scaleY: 1.0, blur: 0)
                            ).animation(FloatingPanelMetrics.fadeAnimation)
                        )
                    )
            } else {
                collapsedPanel
                    .transition(
                        .asymmetric(
                            insertion: .modifier(
                                active: JellyMorphModifier(opacity: 0.0, xOffset: 12, scaleX: 1.05, scaleY: 0.9, blur: 1.0),
                                identity: JellyMorphModifier(opacity: 1.0, xOffset: 0, scaleX: 1.0, scaleY: 1.0, blur: 0)
                            ).animation(FloatingPanelMetrics.fadeAnimation),
                            removal: .modifier(
                                active: JellyMorphModifier(opacity: 0.0, xOffset: -6, scaleX: 0.93, scaleY: 1.04, blur: 1.2),
                                identity: JellyMorphModifier(opacity: 1.0, xOffset: 0, scaleX: 1.0, scaleY: 1.0, blur: 0)
                            ).animation(FloatingPanelMetrics.fadeAnimation)
                        )
                    )
            }
        }
        .compositingGroup()
        .frame(width: isExpanded ? FloatingPanelMetrics.expandedWidth : FloatingPanelMetrics.collapsedWidth, alignment: .topLeading)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(FloatingPanelMetrics.panelAnimation, value: isExpanded)
        .animation(FloatingPanelMetrics.contentAnimation, value: monitor.focusedSpace?.id)
        .animation(FloatingPanelMetrics.contentAnimation, value: monitor.isLoading)
        .contextMenu {
            Button("Refresh") {
                monitor.refresh(trigger: .manual)
            }

            Divider()

            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: FloatingPanelMetrics.bodySpacing) {
            expandedHeader

            Group {
                if let errorMessage = monitor.errorMessage {
                    StateBanner(
                        title: "Yabai unavailable",
                        message: errorMessage,
                        systemImage: "exclamationmark.triangle.fill",
                        accent: FloatingPalette.errorAccent,
                        textColor: FloatingPalette.errorText,
                        backgroundColor: FloatingPalette.errorBackground,
                        tint: FloatingPalette.errorAccent
                    )
                    .help(errorMessage)
                } else if monitor.spaces.isEmpty {
                    StateBanner(
                        title: monitor.isLoading ? "Looking for spaces" : "No spaces yet",
                        message: monitor.isLoading
                            ? "The marker is checking yabai for the latest workspace state."
                            : "Create or expose spaces in yabai and they will appear here.",
                        systemImage: monitor.isLoading ? "arrow.triangle.2.circlepath" : "rectangle.3.group.fill",
                        accent: FloatingPalette.accentStart,
                        textColor: FloatingPalette.primaryText,
                        backgroundColor: FloatingPalette.surfaceWash,
                        tint: FloatingPalette.accentGlow
                    )
                } else {
                    VStack(spacing: FloatingPanelMetrics.itemSpacing) {
                        ForEach(monitor.spaces) { space in
                            Button {
                                monitor.focus(space: space)
                            } label: {
                                SpaceRow(space: space)
                            }
                            .buttonStyle(.plain)
                            .help(space.title)
                        }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }

            expandedFooter
        }
        .padding(FloatingPanelMetrics.verticalPadding)
    }

    private var collapsedPanel: some View {
        VStack(spacing: FloatingPanelMetrics.collapsedSpacing) {
            HStack(spacing: 6) {
                BrandBadge(size: 24)

                Spacer(minLength: 0)

                Circle()
                    .fill(monitor.errorMessage == nil ? FloatingPalette.accentStart : FloatingPalette.errorAccent)
                    .frame(width: 6, height: 6)
                    .shadow(
                        color: (monitor.errorMessage == nil ? FloatingPalette.accentStart : FloatingPalette.errorAccent).opacity(0.4),
                        radius: 5,
                        x: 0,
                        y: 1
                    )
            }
            .frame(height: FloatingPanelMetrics.collapsedHeaderHeight)

            compactCard

            footerButtons
                .frame(height: FloatingPanelMetrics.footerHeight)
        }
        .padding(FloatingPanelMetrics.collapsedPadding)
    }

    private var compactCard: some View {
        Button {
            monitor.revealPanelTemporarily()
        } label: {
            VStack(spacing: 2) {
                if let focusedSpace {
                    Text("\(focusedSpace.index)")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(FloatingPalette.primaryText)

                    Text(compactCardTitle(for: focusedSpace))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(FloatingPalette.secondaryText)
                        .lineLimit(1)
                } else if monitor.isLoading {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FloatingPalette.primaryText)

                    Text("Sync")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(FloatingPalette.secondaryText)
                } else {
                    Image(systemName: "rectangle.3.group.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FloatingPalette.primaryText)

                    Text("Spaces")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(FloatingPalette.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: FloatingPanelMetrics.compactCardHeight)
            .background(
                LiquidGlassSurface(
                    cornerRadius: 18,
                    tint: focusedSpace == nil ? FloatingPalette.neutralTone : FloatingPalette.focusGlow,
                    tintStrength: focusedSpace == nil ? 0.09 : 0.18,
                    fillOpacity: focusedSpace == nil ? 0.18 : 0.24,
                    highlightOpacity: focusedSpace == nil ? 0.7 : 0.82
                )
            )
        }
        .buttonStyle(.plain)
        .help("Expand space switcher")
    }

    private func compactCardTitle(for space: YabaiSpace) -> String {
        let source = space.label?.isEmpty == false ? space.label! : space.title
        return String(source.prefix(6))
    }

    private var expandedHeader: some View {
        HStack(spacing: 10) {
            BrandBadge(size: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("Space Marker")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(FloatingPalette.primaryText)

                Text(summaryText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(FloatingPalette.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 6)

            Text(statusBadgeText)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(monitor.errorMessage == nil ? FloatingPalette.primaryText : FloatingPalette.errorText)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    LiquidGlassSurface(
                        cornerRadius: 11,
                        tint: monitor.errorMessage == nil ? FloatingPalette.neutralTone : FloatingPalette.errorAccent,
                        tintStrength: monitor.errorMessage == nil ? 0.08 : 0.15,
                        fillOpacity: 0.18,
                        highlightOpacity: 0.6
                    )
                )
        }
        .frame(height: FloatingPanelMetrics.headerHeight)
    }

    private var expandedFooter: some View {
        HStack(spacing: 8) {
            Label {
                Text(footerText)
                    .lineLimit(1)
            } icon: {
                Image(systemName: monitor.errorMessage == nil ? "sparkles" : "wrench.and.screwdriver.fill")
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(FloatingPalette.tertiaryText)

            Spacer(minLength: 6)

            footerButtons
        }
        .frame(height: FloatingPanelMetrics.footerHeight)
    }

    private var footerButtons: some View {
        HStack(spacing: 5) {
            Button {
                monitor.revealPanelTemporarily()
                monitor.refresh(trigger: .manual)
            } label: {
                FooterControlButton(
                    systemImage: monitor.isLoading ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise.circle.fill",
                    foreground: FloatingPalette.primaryText,
                    backgroundTint: FloatingPalette.neutralTone
                )
            }
            .buttonStyle(.plain)
            .help("Refresh spaces")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                FooterControlButton(
                    systemImage: "power.circle.fill",
                    foreground: FloatingPalette.errorText,
                    backgroundTint: FloatingPalette.errorAccent
                )
            }
            .buttonStyle(.plain)
            .help("Quit Space Marker")
        }
    }

    private var panelBackground: some View {
        LiquidGlassSurface(
            cornerRadius: 24,
            tint: isExpanded ? FloatingPalette.neutralTone : FloatingPalette.neutralTint,
            tintStrength: isExpanded ? 0.1 : 0.08,
            fillOpacity: isExpanded ? 0.18 : 0.22,
            highlightOpacity: isExpanded ? 0.84 : 0.76
        )
        .shadow(color: Color.black.opacity(isExpanded ? 0.09 : 0.05), radius: isExpanded ? 18 : 12, x: 0, y: isExpanded ? 12 : 8)
        .shadow(color: FloatingPalette.focusGlow.opacity(isExpanded ? 0.1 : 0.05), radius: isExpanded ? 12 : 7, x: 0, y: 5)
    }
}

private struct JellyMorphModifier: ViewModifier {
    let opacity: Double
    let xOffset: CGFloat
    let scaleX: CGFloat
    let scaleY: CGFloat
    let blur: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .offset(x: xOffset)
            .scaleEffect(x: scaleX, y: scaleY, anchor: .leading)
            .blur(radius: blur)
    }
}

private enum FloatingPalette {
    static let accentStart = Color(red: 0.38, green: 0.70, blue: 1.00)
    static let accentEnd = Color(red: 0.54, green: 0.57, blue: 1.00)
    static let accentGlow = Color(red: 0.76, green: 0.90, blue: 1.00)

    static let neutralTint = Color(red: 0.88, green: 0.92, blue: 0.98)
    static let neutralTone = Color(red: 0.72, green: 0.79, blue: 0.92)
    static let neutralGlow = Color(red: 0.97, green: 0.99, blue: 1.00)

    static let primaryText = Color(red: 0.08, green: 0.10, blue: 0.14)
    static let secondaryText = Color(red: 0.33, green: 0.38, blue: 0.46)
    static let tertiaryText = Color(red: 0.44, green: 0.49, blue: 0.58)

    static let lineSoft = Color.white.opacity(0.72)
    static let lineStrong = Color.white.opacity(0.92)
    static let surfaceWash = Color.white.opacity(0.22)

    static let focusTint = Color(red: 0.28, green: 0.63, blue: 1.00)
    static let focusGlow = Color(red: 0.58, green: 0.84, blue: 1.00)
    static let focusDeep = Color(red: 0.11, green: 0.27, blue: 0.54)
    static let focusText = Color.white.opacity(0.97)

    static let errorAccent = Color(red: 0.84, green: 0.34, blue: 0.31)
    static let errorBackground = Color(red: 0.99, green: 0.92, blue: 0.91)
    static let errorText = Color(red: 0.46, green: 0.15, blue: 0.14)
}

private struct LiquidGlassSurface: View {
    let cornerRadius: CGFloat
    let tint: Color
    let tintStrength: CGFloat
    let fillOpacity: CGFloat
    let highlightOpacity: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(fillOpacity))

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(tintStrength),
                            tint.opacity(tintStrength * 0.45),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(highlightOpacity), Color.white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: max(12, cornerRadius * 0.95))
                .padding(.horizontal, 6)
                .padding(.top, 4)
                .blur(radius: 0.6)
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(FloatingPalette.lineStrong.opacity(0.75), lineWidth: 0.8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(tint.opacity(tintStrength * 1.6), lineWidth: 0.7)
                .blur(radius: 0.3)
        )
    }
}

private struct BrandBadge: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            LiquidGlassSurface(
                cornerRadius: size * 0.38,
                tint: FloatingPalette.accentStart,
                tintStrength: 0.22,
                fillOpacity: 0.22,
                highlightOpacity: 0.82
            )

            Image(systemName: "command")
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(FloatingPalette.primaryText)
        }
        .frame(width: size, height: size)
    }
}

private struct StateBanner: View {
    let title: String
    let message: String
    let systemImage: String
    let accent: Color
    let textColor: Color
    let backgroundColor: Color
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.16))

                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(textColor)

                Text(message)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(textColor.opacity(0.72))
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: FloatingPanelMetrics.statusHeight, alignment: .topLeading)
        .background(
            ZStack {
                LiquidGlassSurface(
                    cornerRadius: 18,
                    tint: tint,
                    tintStrength: 0.1,
                    fillOpacity: 0.18,
                    highlightOpacity: 0.68
                )

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(backgroundColor.opacity(0.14))
            }
        )
    }
}

private struct FooterControlButton: View {
    let systemImage: String
    let foreground: Color
    let backgroundTint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: 26, height: 26)
            .background(
                LiquidGlassSurface(
                    cornerRadius: 13,
                    tint: backgroundTint,
                    tintStrength: 0.14,
                    fillOpacity: 0.2,
                    highlightOpacity: 0.68
                )
            )
    }
}

private struct SpaceRow: View {
    let space: YabaiSpace

    private var titleStyle: AnyShapeStyle {
        AnyShapeStyle(space.hasFocus ? FloatingPalette.focusText : FloatingPalette.primaryText)
    }

    private var subtitleStyle: AnyShapeStyle {
        AnyShapeStyle(space.hasFocus ? FloatingPalette.focusText.opacity(0.8) : FloatingPalette.secondaryText)
    }

    private var trailingStyle: AnyShapeStyle {
        AnyShapeStyle(space.hasFocus ? FloatingPalette.focusText.opacity(0.86) : FloatingPalette.tertiaryText)
    }

    private var subtitle: String {
        if let label = space.label, !label.isEmpty {
            return "Display \(space.display) · Space \(space.index)"
        }

        return "Display \(space.display)"
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                LiquidGlassSurface(
                    cornerRadius: 12,
                    tint: space.hasFocus ? FloatingPalette.focusGlow : FloatingPalette.neutralTint,
                    tintStrength: space.hasFocus ? 0.34 : 0.08,
                    fillOpacity: space.hasFocus ? 0.34 : 0.18,
                    highlightOpacity: space.hasFocus ? 0.9 : 0.68
                )

                Text("\(space.index)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(space.hasFocus ? FloatingPalette.focusDeep : FloatingPalette.primaryText)
                    .contentTransition(.numericText())
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(space.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(titleStyle)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(subtitleStyle)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if space.hasFocus {
                Text("Active")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(FloatingPalette.focusText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(FloatingPalette.focusDeep.opacity(0.36))
                    )
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(trailingStyle)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: FloatingPanelMetrics.itemHeight, alignment: .leading)
        .background(
            LiquidGlassSurface(
                cornerRadius: 18,
                tint: space.hasFocus ? FloatingPalette.focusTint : FloatingPalette.neutralTone,
                tintStrength: space.hasFocus ? 0.32 : 0.07,
                fillOpacity: space.hasFocus ? 0.28 : 0.15,
                highlightOpacity: space.hasFocus ? 0.9 : 0.7
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(space.hasFocus ? FloatingPalette.focusGlow.opacity(0.95) : FloatingPalette.lineSoft.opacity(0.28), lineWidth: space.hasFocus ? 1.05 : 0.6)
        )
        .shadow(
            color: (space.hasFocus ? FloatingPalette.focusTint : Color.black).opacity(space.hasFocus ? 0.24 : 0.03),
            radius: space.hasFocus ? 14 : 6,
            x: 0,
            y: space.hasFocus ? 8 : 3
        )
        .scaleEffect(space.hasFocus ? 1.02 : 0.985)
        .animation(FloatingPanelMetrics.contentAnimation, value: space.hasFocus)
    }
}

struct YabaiSpace: Codable, Identifiable {
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
    }

    @Published private(set) var spaces: [YabaiSpace] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var panelPresentation: FloatingPanelPresentation

    private let executableURL: URL?
    private var refreshTimer: Timer?
    private var collapseTask: Task<Void, Never>?
    private var hasLoadedSnapshot = false

    init() {
        self.executableURL = Self.resolveExecutableURL()
        self.panelPresentation = .collapsed
    }

    deinit {
        refreshTimer?.invalidate()
        collapseTask?.cancel()
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
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let monitor = self else { return }
            Task { @MainActor [monitor] in
                monitor.refresh(trigger: .timer)
            }
        }
    }

    func revealPanelTemporarily() {
        setPanelPresentation(.expanded)
        scheduleAutoCollapseIfNeeded()
    }

    func refresh(trigger: RefreshTrigger = .manual) {
        if trigger != .timer {
            revealPanelTemporarily()
        }

        guard !isLoading else { return }

        isLoading = true

        let executableURL = self.executableURL
        let previousFocusedID = focusedSpace?.id
        let hadError = errorMessage != nil

        Task.detached(priority: .utility) {
            let result = Result { try Self.querySpaces(using: executableURL) }
            await MainActor.run {
                self.isLoading = false

                switch result {
                case .success(let spaces):
                    let sortedSpaces = spaces.sorted { $0.index < $1.index }
                    let newFocusedID = sortedSpaces.first(where: \.hasFocus)?.id
                    let focusChanged = previousFocusedID != newFocusedID
                    let shouldReveal = !self.hasLoadedSnapshot || hadError || focusChanged || trigger != .timer

                    self.spaces = sortedSpaces
                    self.errorMessage = nil
                    self.lastUpdated = .now
                    self.hasLoadedSnapshot = true

                    if shouldReveal {
                        self.revealPanelTemporarily()
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.setPanelPresentation(.expanded)
                    self.cancelAutoCollapse()
                }
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
        Task.detached(priority: .userInitiated) {
            let result = Result {
                try Self.runYabai(arguments: ["-m", "space", "--focus", "\(space.index)"], using: executableURL)
            }

            await MainActor.run {
                if case .failure(let error) = result {
                    self.errorMessage = error.localizedDescription
                    self.setPanelPresentation(.expanded)
                    self.cancelAutoCollapse()
                }
                self.refresh(trigger: .focusRequest)
            }
        }
    }

    private func setPanelPresentation(_ presentation: FloatingPanelPresentation) {
        guard panelPresentation != presentation else { return }
        withAnimation(FloatingPanelMetrics.panelAnimation) {
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
            let delay = UInt64(FloatingPanelMetrics.autoCollapseDelay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, let self else { return }
            self.setPanelPresentation(.collapsed)
        }
    }

    private func cancelAutoCollapse() {
        collapseTask?.cancel()
        collapseTask = nil
    }

    nonisolated private static func querySpaces(using executableURL: URL?) throws -> [YabaiSpace] {
        let data = try runYabai(arguments: ["-m", "query", "--spaces"], using: executableURL)
        return try JSONDecoder().decode([YabaiSpace].self, from: data)
    }

    nonisolated private static func runYabai(arguments: [String], using executableURL: URL?) throws -> Data {
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

        try process.run()
        process.waitUntilExit()

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

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Could not find the yabai executable. Set YABAI_BIN or install yabai in /opt/homebrew/bin."
        case .commandFailed(let message):
            return message
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(monitor: YabaiSpacesMonitor())
            .padding(24)
            .background(Color(red: 0.92, green: 0.95, blue: 0.99))
    }
}
