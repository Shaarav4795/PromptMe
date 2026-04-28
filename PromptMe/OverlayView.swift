import AppKit
import SwiftUI

private struct AppleNotchShape: InsettableShape {
    var topCornerRadiusRatio: CGFloat = 0.10
    var bottomCornerRadiusRatio: CGFloat = 0.13
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard r.width > 0, r.height > 0 else { return Path() }

        let w = r.width
        let h = r.height

        let cornerScaleBasis = min(h, 220)
        let targetTopRadius = cornerScaleBasis * topCornerRadiusRatio
        let targetBottomRadius = cornerScaleBasis * bottomCornerRadiusRatio
        let topRadius = max(0, min(max(8, targetTopRadius), min(w * 0.18, h * 0.24)))
        let maxBottomFromHeight = max(0, h - topRadius)
        let bottomRadius = max(0, min(max(12, targetBottomRadius), min(w * 0.26, min(h * 0.30, maxBottomFromHeight))))

        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))

        p.addQuadCurve(
            to: CGPoint(x: r.minX + topRadius, y: r.minY + topRadius),
            control: CGPoint(x: r.minX + topRadius, y: r.minY)
        )

        p.addLine(to: CGPoint(x: r.minX + topRadius, y: r.maxY - bottomRadius))
        p.addQuadCurve(
            to: CGPoint(x: r.minX + topRadius + bottomRadius, y: r.maxY),
            control: CGPoint(x: r.minX + topRadius, y: r.maxY)
        )

        p.addLine(to: CGPoint(x: r.maxX - topRadius - bottomRadius, y: r.maxY))

        p.addQuadCurve(
            to: CGPoint(x: r.maxX - topRadius, y: r.maxY - bottomRadius),
            control: CGPoint(x: r.maxX - topRadius, y: r.maxY)
        )
        p.addLine(to: CGPoint(x: r.maxX - topRadius, y: r.minY + topRadius))

        p.addQuadCurve(
            to: CGPoint(x: r.maxX, y: r.minY),
            control: CGPoint(x: r.maxX - topRadius, y: r.minY)
        )
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()

        return p
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var s = self
        s.insetAmount += amount
        return s
    }
}

struct OverlayView: View {
    @ObservedObject var model: PrompterModel
    @State private var isHovering = false
    @State private var cachedOverlaySize: CGSize = .zero
    @State private var cachedNotchFillPath = Path()
    @State private var cachedNotchStrokePath = Path()

    private static let overlayShape = AppleNotchShape()
    private static let topStrokeCoverHeight: CGFloat = 1

    var body: some View {
        let overlayWidth = CGFloat(model.overlayWidth)
        let overlayHeight = CGFloat(model.overlayHeight)
        let targetSize = CGSize(width: overlayWidth, height: overlayHeight)
        let resolvedNotchPaths = notchPaths(for: targetSize)
        let notchFillPath = resolvedNotchPaths.fill
        let notchStrokePath = resolvedNotchPaths.stroke
        let isPlaybackActive = model.isRunning || model.isCountingDown
        let hoverPauseEnabled = model.hoverPauseEnabled && model.voicePromptMode == .off
        let overlayBackground = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: model.backgroundOpacity)
        let shoulderInset = calculatedTopShoulderInset(overlayWidth: overlayWidth, overlayHeight: overlayHeight)
        let textHorizontalInset = max(24, shoulderInset + 12)
        let controlsHorizontalInset = max(22, min(52, max(overlayHeight * 0.16, shoulderInset + 20)))

        ZStack {
            notchFillPath
                .fill(overlayBackground)

            notchStrokePath
                .stroke(Color.white.opacity(0.04), lineWidth: 1)

            overlayBackground
                .frame(maxWidth: .infinity)
                .frame(height: Self.topStrokeCoverHeight)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipShape(notchFillPath)
                .allowsHitTesting(false)

            ScrollingTextView(
                text: model.script,
                fontSize: CGFloat(model.fontSize),
                speedPointsPerSecond: model.speedPointsPerSecond,
                voiceSpeedMultiplier: model.voiceSpeedMultiplier,
                voiceMode: model.voicePromptMode,
                voiceMatchedRange: model.voiceMatchedRange,
                voiceAlignmentToken: model.voiceAlignmentToken,
                isRunning: model.isRunning,
                hasStartedSession: model.hasStartedSession,
                resetToken: model.resetToken,
                jumpBackToken: model.jumpBackToken,
                jumpBackDistancePoints: model.jumpBackDistancePoints,
                manualScrollToken: model.manualScrollToken,
                manualScrollDeltaPoints: model.manualScrollDeltaPoints,
                fadeFraction: CGFloat(model.edgeFadeFraction),
                backgroundOpacity: model.backgroundOpacity,
                isHovering: hoverPauseEnabled ? isHovering : false,
                scrollMode: model.scrollMode,
                savedScrollPhaseForResume: model.savedScrollPhaseForResume,
                onSaveScrollPhaseForResume: model.saveScrollPhaseForResume,
                onReachedEnd: {
                    if model.isRunning {
                        model.markReachedEndInStopMode()
                    }
                }
            )
            .padding(.horizontal, textHorizontalInset)
            .padding(.top, 46)
            .padding(.bottom, 12)
            .clipped(antialiased: false)
            .clipShape(notchFillPath)
            .overlay {
                TrackpadScrollCaptureView(onScroll: model.handleManualScroll(deltaPoints:))
            }
            
            if !model.isCountingDown {
                HStack {
                    HStack(spacing: 6) {
                        OverlayControlButton(symbol: isPlaybackActive ? "pause.fill" : "play.fill") {
                            model.switchPlaybackModeFromOverlayControl()
                        }
                        .help(isPlaybackActive ? "Pause and switch to manual trackpad scroll" : "Start auto scroll")
                        
                        OverlayControlButton(symbol: "gobackward.5") {
                            model.jumpBack(seconds: 5)
                        }
                        .help("Jump back 5 seconds")

                        if model.voicePromptMode != .off {
                            OverlayVoiceMeter(
                                level: model.voiceSignalLevel,
                                isSpeaking: model.isVoiceSpeechDetected,
                                isFallback: model.voiceFallbackToClassic,
                                permissionDenied: model.voicePermissionDenied
                            )
                            .help(model.voiceStatusText)
                        }
                    }
                    .overlayControlCapsule()
                    
                    Spacer(minLength: 8)
                    
                    HStack(spacing: 6) {
                        if model.voicePromptMode == .off {
                            OverlayControlButton(symbol: "minus", repeatWhilePressed: true) {
                                model.adjustSpeed(delta: -PrompterModel.speedStep)
                            }
                            .help("Decrease speed")

                            OverlayControlButton(symbol: "plus", repeatWhilePressed: true) {
                                model.adjustSpeed(delta: PrompterModel.speedStep)
                            }
                            .help("Increase speed")
                        }

                        OverlayControlButton(symbol: "gearshape") {
                            AppDelegate.shared?.openMainWindow()
                        }
                        .help("Open settings")

                        OverlayControlButton(symbol: "power") {
                            NSApp.terminate(nil)
                        }
                        .help("Quit PromptMe")
                    }
                    .overlayControlCapsule()
                }
                .padding(.horizontal, controlsHorizontalInset)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            if model.isCountingDown {
                ZStack {
                    Color.black.opacity(0.92)
                    Text("\(model.countdownRemaining)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .clipShape(notchFillPath)
                .allowsHitTesting(false)
            }
        }
        .frame(width: overlayWidth, height: overlayHeight)
        .onAppear {
            rebuildNotchPaths(width: overlayWidth, height: overlayHeight)
        }
        .onChange(of: overlayWidth) { _, newWidth in
            rebuildNotchPaths(width: newWidth, height: overlayHeight)
        }
        .onChange(of: overlayHeight) { _, newHeight in
            rebuildNotchPaths(width: overlayWidth, height: newHeight)
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func isCachedNotchValid(for size: CGSize) -> Bool {
        abs(cachedOverlaySize.width - size.width) < 0.5 &&
            abs(cachedOverlaySize.height - size.height) < 0.5 &&
            !cachedNotchFillPath.isEmpty
    }

    private func notchPaths(for size: CGSize) -> (fill: Path, stroke: Path) {
        guard isCachedNotchValid(for: size) else {
            let fallbackRect = CGRect(origin: .zero, size: size)
            return (
                fill: Self.overlayShape.path(in: fallbackRect),
                stroke: Self.overlayShape.inset(by: 0.5).path(in: fallbackRect)
            )
        }
        return (fill: cachedNotchFillPath, stroke: cachedNotchStrokePath)
    }

    private func calculatedTopShoulderInset(overlayWidth: CGFloat, overlayHeight: CGFloat) -> CGFloat {
        let cornerScaleBasis = min(overlayHeight, 220)
        return max(0, min(max(8, cornerScaleBasis * 0.10), min(overlayWidth * 0.18, overlayHeight * 0.24)))
    }

    private func rebuildNotchPaths(width: CGFloat, height: CGFloat) {
        let size = CGSize(width: width, height: height)
        guard !isCachedNotchValid(for: size) else { return }

        let rect = CGRect(origin: .zero, size: size)
        cachedNotchFillPath = Self.overlayShape.path(in: rect)
        cachedNotchStrokePath = Self.overlayShape.inset(by: 0.5).path(in: rect)
        cachedOverlaySize = size
    }
}

private struct OverlayVoiceMeter: View {
    let level: Double
    let isSpeaking: Bool
    let isFallback: Bool
    let permissionDenied: Bool

    private var meterColor: Color {
        if permissionDenied {
            return Color(.sRGB, red: 0.85, green: 0.28, blue: 0.24, opacity: 1)
        }
        if isFallback {
            return Color(.sRGB, red: 0.92, green: 0.60, blue: 0.20, opacity: 1)
        }
        if isSpeaking {
            return Color(.sRGB, red: 0.18, green: 0.84, blue: 0.50, opacity: 1)
        }
        return Color.white.opacity(0.45)
    }

    var body: some View {
        let clampedLevel = max(0, min(level, 1))

        HStack(spacing: 6) {
            Image(systemName: "waveform")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.88))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(meterColor)
                    .frame(width: max(3, 44 * clampedLevel))
            }
            .frame(width: 44, height: 6)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.12), value: level)
    }
}

private extension View {
    func overlayControlCapsule() -> some View {
        padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.7), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

private struct OverlayControlButton: View {
    let symbol: String
    var isActive: Bool = false
    var repeatWhilePressed: Bool = false
    let action: () -> Void

    var body: some View {
        // Button preserves click-through behavior on panel windows (FB13720950).
        Button {
            if !repeatWhilePressed { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .contentShape(Circle())
        }
        .buttonStyle(
            OverlayCircleButtonStyle(
                isActive: isActive,
                repeatWhilePressed: repeatWhilePressed,
                repeatAction: action
            )
        )
    }
}

private struct OverlayCircleButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var repeatWhilePressed: Bool = false
    var repeatAction: (() -> Void)?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed || isActive ? 0.18 : 0.10))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .background {
                if repeatWhilePressed {
                    RepeatWhileHeldHelper(
                        isPressed: configuration.isPressed,
                        action: repeatAction ?? {}
                    )
                }
            }
    }
}

private struct RepeatWhileHeldHelper: View {
    let isPressed: Bool
    let action: () -> Void

    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: isPressed) { _, pressed in
                if pressed {
                    action()
                    startRepeating()
                } else {
                    stopRepeating()
                }
            }
            .onDisappear { stopRepeating() }
    }

    private func startRepeating() {
        stopRepeating()
        repeatTask = Task {
            try? await Task.sleep(nanoseconds: Self.initialRepeatDelay)
            while !Task.isCancelled {
                await MainActor.run { action() }
                try? await Task.sleep(nanoseconds: Self.repeatInterval)
            }
        }
    }

    private func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
    }

    private static let initialRepeatDelay: UInt64 = 280_000_000
    private static let repeatInterval: UInt64 = 85_000_000
}

struct TrackpadScrollCaptureView: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll)
    }

    func makeNSView(context: Context) -> ScrollCaptureNSView {
        let view = ScrollCaptureNSView()
        view.onScroll = context.coordinator.handleScroll
        return view
    }

    func updateNSView(_ nsView: ScrollCaptureNSView, context: Context) {
        context.coordinator.onScroll = onScroll
    }

    final class Coordinator {
        var onScroll: (CGFloat) -> Void

        init(onScroll: @escaping (CGFloat) -> Void) {
            self.onScroll = onScroll
        }

        func handleScroll(_ event: NSEvent) {
            let rawDelta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY * 10
            let semanticDelta = event.isDirectionInvertedFromDevice ? -rawDelta : rawDelta
            onScroll(semanticDelta)
        }
    }
}

final class ScrollCaptureNSView: NSView {
    var onScroll: ((NSEvent) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event)
    }
}
