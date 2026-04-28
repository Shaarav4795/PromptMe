import SwiftUI
import AppKit

struct ScrollingTextView: View {
    let text: String
    let fontSize: CGFloat
    let speedPointsPerSecond: Double
    let voiceSpeedMultiplier: Double
    let voiceMode: PrompterModel.VoicePromptMode
    let voiceMatchedRange: NSRange?
    let voiceAlignmentToken: UUID
    let isRunning: Bool
    let hasStartedSession: Bool
    let resetToken: UUID
    let jumpBackToken: UUID
    let jumpBackDistancePoints: CGFloat
    let manualScrollToken: UUID
    let manualScrollDeltaPoints: CGFloat
    let fadeFraction: CGFloat
    let backgroundOpacity: Double
    let isHovering: Bool
    let scrollMode: PrompterModel.ScrollMode
    let savedScrollPhaseForResume: CGFloat?
    let onSaveScrollPhaseForResume: ((CGFloat) -> Void)?
    let onReachedEnd: (() -> Void)?

    private static let loopGap: CGFloat = 24
    private static let geometryHysteresis: CGFloat = 0.75
    private static let contentMeasureHysteresis: CGFloat = 0.75

    @State private var contentHeight: CGFloat = 1
    @State private var viewportHeight: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @State private var hasMeasuredContentHeight: Bool = false
    @State private var hasNonWhitespaceContent: Bool = false
    @State private var cachedFadeMaskFraction: CGFloat = -1
    @State private var cachedEdgeFadeGradient: Gradient = Self.makeEdgeFadeGradient(for: 0.2)
    @State private var cachedRenderedScriptImage: NSImage?
    @State private var cachedRenderedScriptText: String = ""
    @State private var cachedRenderedScriptFontSize: CGFloat = -1
    @State private var cachedRenderedScriptWidth: CGFloat = -1

    private var hasContent: Bool {
        hasNonWhitespaceContent
    }

    private var emptyStateMessage: String {
        "No prompt text yet.\nOpen Settings > Prompts and add text to begin."
    }

    private var initialStateMessage: String {
        "Ready to prompt.\nPress Start to begin countdown."
    }

    private var clampedFadeFraction: CGFloat {
        min(max(fadeFraction, 0), 0.49)
    }

    private var edgeSofteningBandHeight: CGFloat {
        max(viewportHeight * clampedFadeFraction * 0.9, 8)
    }

    private var topFadeClearInset: CGFloat {
        guard viewportHeight > 1 else { return 0 }
        return viewportHeight * clampedFadeFraction
    }

    private var readabilityPadding: CGFloat {
        max(2, fontSize * 0.12)
    }

    private var startAnchorOffset: CGFloat {
        let fallback = max(8, min(fontSize * 0.45, 22))
        guard viewportHeight > 1 else { return fallback }

        let raw = topFadeClearInset + readabilityPadding
        let capped = min(raw, max(18, viewportHeight * 0.38))
        return max(capped, fallback)
    }

    private var topOfScriptPhaseFloor: CGFloat {
        -startAnchorOffset
    }

    private var endPhase: CGFloat {
        let bottomReadabilityInset = topFadeClearInset + readabilityPadding
        let lastLinePhase = contentHeight - max(0, viewportHeight - bottomReadabilityInset)
        return max(topOfScriptPhaseFloor, lastLinePhase)
    }

    var body: some View {
        GeometryReader { viewportProxy in
            ZStack(alignment: .topLeading) {
                if hasContent && hasStartedSession, let renderedImage = cachedRenderedScriptImage {
                    LayerScrollingImageView(
                        image: renderedImage,
                        scriptText: text,
                        scriptFontSize: fontSize,
                        contentHeight: contentHeight,
                        speedPointsPerSecond: speedPointsPerSecond,
                        voiceSpeedMultiplier: voiceSpeedMultiplier,
                        voiceMode: voiceMode,
                        voiceMatchedRange: voiceMatchedRange,
                        voiceAlignmentToken: voiceAlignmentToken,
                        isRunning: isRunning,
                        isHovering: isHovering,
                        scrollMode: scrollMode,
                        hasMeasuredContentHeight: hasMeasuredContentHeight,
                        topOfScriptPhaseFloor: topOfScriptPhaseFloor,
                        endPhase: endPhase,
                        resetToken: resetToken,
                        jumpBackToken: jumpBackToken,
                        jumpBackDistancePoints: jumpBackDistancePoints,
                        manualScrollToken: manualScrollToken,
                        manualScrollDeltaPoints: manualScrollDeltaPoints,
                        savedScrollPhaseForResume: savedScrollPhaseForResume,
                        onSaveScrollPhaseForResume: onSaveScrollPhaseForResume,
                        onReachedEnd: onReachedEnd
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else if hasContent {
                    placeholderMessage(initialStateMessage)
                } else {
                    placeholderMessage(emptyStateMessage)
                }
            }
            .frame(width: viewportProxy.size.width, height: viewportProxy.size.height, alignment: .topLeading)
            .onAppear {
                viewportHeight = max(viewportProxy.size.height, 0)
                viewportWidth = max(viewportProxy.size.width, 0)
                updateHasContentFlag()
                rebuildRenderedScriptIfNeeded(force: true)
                updateEdgeFadeMaskGradientIfNeeded(force: true)
            }
            .onChange(of: viewportProxy.size.width) { _, newWidth in
                let clampedWidth = max(newWidth, 0)
                if abs(clampedWidth - viewportWidth) > Self.geometryHysteresis {
                    viewportWidth = clampedWidth
                    hasMeasuredContentHeight = false
                    rebuildRenderedScriptIfNeeded(force: true)
                }
            }
            .onChange(of: viewportProxy.size.height) { _, newHeight in
                let clampedHeight = max(newHeight, 0)
                if abs(clampedHeight - viewportHeight) > Self.geometryHysteresis {
                    viewportHeight = clampedHeight
                }
            }
            .onChange(of: text) { _, _ in
                updateHasContentFlag()
                hasMeasuredContentHeight = false
                rebuildRenderedScriptIfNeeded(force: true)
            }
            .onChange(of: fontSize) { _, _ in
                hasMeasuredContentHeight = false
                rebuildRenderedScriptIfNeeded(force: true)
            }
            .onChange(of: fadeFraction) { _, _ in
                updateEdgeFadeMaskGradientIfNeeded()
            }
        }
        .mask(edgeFadeMask)
        .overlay(edgeSofteningOverlay)
    }

    private var scriptRenderWidth: CGFloat {
        max(1, round(viewportWidth))
    }

    private func rebuildRenderedScriptIfNeeded(force: Bool = false) {
        guard hasContent else {
            cachedRenderedScriptImage = nil
            cachedRenderedScriptText = ""
            cachedRenderedScriptFontSize = -1
            cachedRenderedScriptWidth = -1
            contentHeight = 1
            hasMeasuredContentHeight = false
            return
        }

        let targetWidth = scriptRenderWidth
        let normalizedFontSize = max(1, round(fontSize * 10) / 10)
        let needsRebuild = force ||
            cachedRenderedScriptText != text ||
            abs(cachedRenderedScriptFontSize - normalizedFontSize) > 0.001 ||
            abs(cachedRenderedScriptWidth - targetWidth) > 2.0
        guard needsRebuild else { return }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .justified
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.hyphenationFactor = 0.9

        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: normalizedFontSize, weight: .regular),
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraph
            ]
        )

        let measuredBounds = attributed.boundingRect(
            with: NSSize(width: targetWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let measuredHeight = max(1, ceil(measuredBounds.height))
        let imageSize = NSSize(width: targetWidth, height: measuredHeight)
        let image = NSImage(size: imageSize)

        image.lockFocusFlipped(true)
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()
        attributed.draw(
            with: NSRect(origin: .zero, size: imageSize),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        image.unlockFocus()

        cachedRenderedScriptImage = image
        cachedRenderedScriptText = text
        cachedRenderedScriptFontSize = normalizedFontSize
        cachedRenderedScriptWidth = targetWidth

        if abs(contentHeight - measuredHeight) > Self.contentMeasureHysteresis || !hasMeasuredContentHeight {
            contentHeight = measuredHeight
            hasMeasuredContentHeight = true
        }
    }

    private func updateHasContentFlag() {
        let hasVisibleContent = text.unicodeScalars.contains { !$0.properties.isWhitespace }
        guard hasNonWhitespaceContent != hasVisibleContent else { return }
        hasNonWhitespaceContent = hasVisibleContent
    }

    private func placeholderMessage(_ message: String) -> some View {
        Text(message)
            .font(.system(size: max(fontSize * 0.72, 13), weight: .regular, design: .default))
            .foregroundStyle(.white.opacity(0.75))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 12)
    }

    private var edgeFadeMask: some View {
        LinearGradient(
            gradient: edgeFadeGradient,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var edgeSofteningOverlay: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.black.opacity(backgroundOpacity * 0.9), Color.black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: edgeSofteningBandHeight)

            Spacer(minLength: 0)

            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(backgroundOpacity * 0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: edgeSofteningBandHeight)
        }
        .allowsHitTesting(false)
    }

    private var edgeFadeGradient: Gradient {
        if cachedFadeMaskFraction < 0 {
            return Self.makeEdgeFadeGradient(for: clampedFadeFraction)
        }
        return cachedEdgeFadeGradient
    }

    private func updateEdgeFadeMaskGradientIfNeeded(force: Bool = false) {
        let nextFraction = clampedFadeFraction
        if force || abs(nextFraction - cachedFadeMaskFraction) > 0.0005 {
            cachedFadeMaskFraction = nextFraction
            cachedEdgeFadeGradient = Self.makeEdgeFadeGradient(for: nextFraction)
        }
    }

    private static func makeEdgeFadeGradient(for fadeFraction: CGFloat) -> Gradient {
        let clamped = min(max(fadeFraction, 0), 0.49)
        return Gradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: clamped),
                .init(color: .black, location: 1 - clamped),
                .init(color: .clear, location: 1)
            ]
        )
    }

    private struct LayerScrollingImageView: NSViewRepresentable {
        let image: NSImage
        let scriptText: String
        let scriptFontSize: CGFloat
        let contentHeight: CGFloat
        let speedPointsPerSecond: Double
        let voiceSpeedMultiplier: Double
        let voiceMode: PrompterModel.VoicePromptMode
        let voiceMatchedRange: NSRange?
        let voiceAlignmentToken: UUID
        let isRunning: Bool
        let isHovering: Bool
        let scrollMode: PrompterModel.ScrollMode
        let hasMeasuredContentHeight: Bool
        let topOfScriptPhaseFloor: CGFloat
        let endPhase: CGFloat
        let resetToken: UUID
        let jumpBackToken: UUID
        let jumpBackDistancePoints: CGFloat
        let manualScrollToken: UUID
        let manualScrollDeltaPoints: CGFloat
        let savedScrollPhaseForResume: CGFloat?
        let onSaveScrollPhaseForResume: ((CGFloat) -> Void)?
        let onReachedEnd: (() -> Void)?

        func makeNSView(context: Context) -> LayerScrollingNSView {
            LayerScrollingNSView()
        }

        func updateNSView(_ nsView: LayerScrollingNSView, context: Context) {
            nsView.apply(
                image: image,
                scriptText: scriptText,
                scriptFontSize: scriptFontSize,
                contentHeight: max(contentHeight, 1),
                speedPointsPerSecond: max(speedPointsPerSecond, 0),
                voiceSpeedMultiplier: max(0, min(voiceSpeedMultiplier, 1.5)),
                voiceMode: voiceMode,
                voiceMatchedRange: voiceMatchedRange,
                voiceAlignmentToken: voiceAlignmentToken,
                isRunning: isRunning,
                isHovering: isHovering,
                scrollMode: scrollMode,
                hasMeasuredContentHeight: hasMeasuredContentHeight,
                topOfScriptPhaseFloor: topOfScriptPhaseFloor,
                endPhase: endPhase,
                resetToken: resetToken,
                jumpBackToken: jumpBackToken,
                jumpBackDistancePoints: max(0, jumpBackDistancePoints),
                manualScrollToken: manualScrollToken,
                manualScrollDeltaPoints: manualScrollDeltaPoints,
                savedScrollPhaseForResume: savedScrollPhaseForResume,
                onSaveScrollPhaseForResume: onSaveScrollPhaseForResume,
                onReachedEnd: onReachedEnd
            )
        }
    }
}

private final class HighlightPassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private final class LayerScrollingNSView: NSView {
    private static let loopGap: CGFloat = 24
    private static let activeTickInterval: TimeInterval = 1.0 / 32.0
    private static let settlingTickInterval: TimeInterval = 1.0 / 14.0
    private static let idleTickInterval: TimeInterval = 1.0 / 3.0
    private static let phaseCommitEpsilon: CGFloat = 0.0005
    private static let speedCommitEpsilon: Double = 0.0005

    private var renderedImage: NSImage?
    private var renderedImageIdentifier: ObjectIdentifier?
    private var renderedCGImage: CGImage?
    private var scriptText: String = ""
    private var scriptFontSize: CGFloat = 16
    private var contentHeight: CGFloat = 1
    private var speedPointsPerSecond: Double = 25
    private var voiceSpeedMultiplier: Double = 1
    private var voiceMode: PrompterModel.VoicePromptMode = .off
    private var voiceMatchedRange: NSRange?
    private var voiceAlignmentToken: UUID = UUID()
    private var isRunning: Bool = false
    private var isHovering: Bool = false
    private var scrollMode: PrompterModel.ScrollMode = .infinite
    private var hasMeasuredContentHeight: Bool = false
    private var topOfScriptPhaseFloor: CGFloat = -8
    private var endPhase: CGFloat = 0

    private var onSaveScrollPhaseForResume: ((CGFloat) -> Void)?
    private var onReachedEnd: (() -> Void)?

    private var resetToken: UUID = UUID()
    private var jumpBackToken: UUID = UUID()
    private var jumpBackDistancePoints: CGFloat = 0
    private var manualScrollToken: UUID = UUID()
    private var manualScrollDeltaPoints: CGFloat = 0

    private var phase: CGFloat = 0
    private var currentSpeedMultiplier: Double = 1.0
    private var deferredStopTargetPhase: CGFloat?
    private var speechSeekTargetPhase: CGFloat?
    private var hasReachedEndInStopMode: Bool = false
    private var lastTickDate: Date?

    private var hasConfigured: Bool = false
    private var lastKnownBoundsSize: CGSize = .zero
    private var hasInitializedPhase: Bool = false

    private var timer: Timer?
    private var timerInterval: TimeInterval = 0

    private var scriptLayers: [NSImageView] = []
    private var layoutStorage: NSTextStorage?
    private var layoutManager: NSLayoutManager?
    private var layoutContainer: NSTextContainer?
    private var cachedLayoutText: String = ""
    private var cachedLayoutFontSize: CGFloat = -1
    private var cachedLayoutWidth: CGFloat = -1
    private var matchedLineRectInScript: CGRect?
    private var matchedWordRectInScript: CGRect?

    private let lineHighlightView = HighlightPassthroughView(frame: .zero)

    private let speedResponseRate: Double = 8.0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        timer?.invalidate()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateTimerIfNeeded()
    }

    override func layout() {
        super.layout()
        guard bounds.size != lastKnownBoundsSize else { return }
        lastKnownBoundsSize = bounds.size
        rebuildScriptLayersIfNeeded(force: true)
        rebuildTextLayoutIfNeeded(force: true)
        refreshVoiceHighlightGeometry()
        applyPhaseToLayers()
        updateTimerIfNeeded()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.masksToBounds = true

        lineHighlightView.wantsLayer = true
        lineHighlightView.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.18).cgColor
        lineHighlightView.layer?.cornerRadius = 4
        lineHighlightView.isHidden = true

        addSubview(lineHighlightView)
    }

    override var isFlipped: Bool {
        true
    }

    func apply(
        image: NSImage,
        scriptText: String,
        scriptFontSize: CGFloat,
        contentHeight: CGFloat,
        speedPointsPerSecond: Double,
        voiceSpeedMultiplier: Double,
        voiceMode: PrompterModel.VoicePromptMode,
        voiceMatchedRange: NSRange?,
        voiceAlignmentToken: UUID,
        isRunning: Bool,
        isHovering: Bool,
        scrollMode: PrompterModel.ScrollMode,
        hasMeasuredContentHeight: Bool,
        topOfScriptPhaseFloor: CGFloat,
        endPhase: CGFloat,
        resetToken: UUID,
        jumpBackToken: UUID,
        jumpBackDistancePoints: CGFloat,
        manualScrollToken: UUID,
        manualScrollDeltaPoints: CGFloat,
        savedScrollPhaseForResume: CGFloat?,
        onSaveScrollPhaseForResume: ((CGFloat) -> Void)?,
        onReachedEnd: (() -> Void)?
    ) {
        let oldRunning = self.isRunning
        let oldScrollMode = self.scrollMode
        let oldVoiceMode = self.voiceMode

        let nextImageIdentifier = ObjectIdentifier(image)
        let imageChanged = renderedImageIdentifier != nextImageIdentifier
        let sizeChanged = abs(self.contentHeight - contentHeight) > 0.75
        let textChanged = self.scriptText != scriptText || abs(self.scriptFontSize - scriptFontSize) > 0.1
        let matchChanged = self.voiceMatchedRange != voiceMatchedRange
        let alignmentTokenChanged = self.voiceAlignmentToken != voiceAlignmentToken

        renderedImage = image
        renderedImageIdentifier = nextImageIdentifier
        if imageChanged || renderedCGImage == nil {
            renderedCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }

        self.scriptText = scriptText
        self.scriptFontSize = max(scriptFontSize, 1)
        self.contentHeight = max(contentHeight, 1)
        self.speedPointsPerSecond = max(speedPointsPerSecond, 0)
        self.voiceSpeedMultiplier = max(0, min(voiceSpeedMultiplier, 1.5))
        self.voiceMode = voiceMode
        self.voiceMatchedRange = voiceMatchedRange
        self.voiceAlignmentToken = voiceAlignmentToken
        if voiceMode == .off {
            speechSeekTargetPhase = nil
        }
        self.isRunning = isRunning
        self.isHovering = isHovering
        self.scrollMode = scrollMode
        self.hasMeasuredContentHeight = hasMeasuredContentHeight
        self.topOfScriptPhaseFloor = topOfScriptPhaseFloor
        self.endPhase = max(topOfScriptPhaseFloor, endPhase)
        self.jumpBackDistancePoints = max(0, jumpBackDistancePoints)
        self.manualScrollDeltaPoints = manualScrollDeltaPoints
        self.onSaveScrollPhaseForResume = onSaveScrollPhaseForResume
        self.onReachedEnd = onReachedEnd

        if scrollMode != oldScrollMode {
            hasReachedEndInStopMode = false
            deferredStopTargetPhase = nil
            rebuildScriptLayersIfNeeded(force: true)
        } else if imageChanged || sizeChanged || textChanged {
            rebuildScriptLayersIfNeeded(force: true)
        }

        if imageChanged || sizeChanged || textChanged {
            rebuildTextLayoutIfNeeded(force: true)
            refreshVoiceHighlightGeometry()
        } else if matchChanged || voiceMode != oldVoiceMode {
            refreshVoiceHighlightGeometry()
        }

        if alignmentTokenChanged {
            seekToMatchedRangeIfNeeded()
        }

        if !hasConfigured {
            self.resetToken = resetToken
            self.jumpBackToken = jumpBackToken
            self.manualScrollToken = manualScrollToken
            restoreOrResetPhase(savedScrollPhaseForResume)
            hasConfigured = true
        } else {
            if self.resetToken != resetToken {
                self.resetToken = resetToken
                resetPhase()
            }
            if self.jumpBackToken != jumpBackToken {
                self.jumpBackToken = jumpBackToken
                applyJumpBack()
            }
            if self.manualScrollToken != manualScrollToken {
                self.manualScrollToken = manualScrollToken
                applyManualScrollDelta(manualScrollDeltaPoints)
            }
        }

        if !oldRunning, isRunning, !hasInitializedPhase {
            restoreOrResetPhase(savedScrollPhaseForResume)
        }

        if oldRunning && !isRunning {
            onSaveScrollPhaseForResume?(phase)
        }

        if phase < topOfScriptPhaseFloor {
            phase = topOfScriptPhaseFloor
            applyPhaseToLayers()
        }

        updateVoiceHighlightViews()

        updateTimerIfNeeded()
    }

    private func restoreOrResetPhase(_ savedScrollPhaseForResume: CGFloat?) {
        if let saved = savedScrollPhaseForResume {
            phase = max(saved, topOfScriptPhaseFloor)
        } else {
            phase = topOfScriptPhaseFloor
        }
        hasReachedEndInStopMode = false
        deferredStopTargetPhase = nil
        speechSeekTargetPhase = nil
        lastTickDate = nil
        currentSpeedMultiplier = desiredSpeedMultiplier()
        hasInitializedPhase = true
        rebuildScriptLayersIfNeeded(force: true)
        applyPhaseToLayers()
    }

    private func resetPhase() {
        phase = topOfScriptPhaseFloor
        hasReachedEndInStopMode = false
        deferredStopTargetPhase = nil
        speechSeekTargetPhase = nil
        lastTickDate = nil
        currentSpeedMultiplier = desiredSpeedMultiplier()
        applyPhaseToLayers()
    }

    private func applyJumpBack() {
        hasReachedEndInStopMode = false
        deferredStopTargetPhase = nil
        speechSeekTargetPhase = nil
        phase = max(phase - jumpBackDistancePoints, topOfScriptPhaseFloor)
        applyPhaseToLayers()
    }

    private func applyManualScrollDelta(_ delta: CGFloat) {
        hasReachedEndInStopMode = false
        deferredStopTargetPhase = nil
        speechSeekTargetPhase = nil

        var nextPhase = phase + delta
        let cycleLength = max(contentHeight + Self.loopGap, 1)

        if scrollMode == .stopAtEnd, hasMeasuredContentHeight {
            nextPhase = min(max(nextPhase, topOfScriptPhaseFloor), endPhase)
            if abs(nextPhase - phase) > Self.phaseCommitEpsilon {
                phase = nextPhase
                applyPhaseToLayers()
            }
            return
        }

        if nextPhase >= cycleLength * 8 || nextPhase <= -(cycleLength * 8) {
            nextPhase = nextPhase.truncatingRemainder(dividingBy: cycleLength)
        }
        nextPhase = max(nextPhase, topOfScriptPhaseFloor)
        if abs(nextPhase - phase) > Self.phaseCommitEpsilon {
            phase = nextPhase
            applyPhaseToLayers()
        }
    }

    private func desiredSpeedMultiplier() -> Double {
        (isRunning && !isHovering) ? voiceSpeedMultiplier : 0.0
    }

    private func desiredCopyCount() -> Int {
        if scrollMode == .stopAtEnd {
            return 1
        }

        let cycleLength = max(contentHeight + Self.loopGap, 1)
        let viewportHeight = max(bounds.height, 1)
        let needed = Int(ceil(viewportHeight / cycleLength)) + 2
        return max(2, needed)
    }

    private func rebuildScriptLayersIfNeeded(force: Bool) {
        guard renderedImage != nil else {
            scriptLayers.forEach { $0.removeFromSuperview() }
            scriptLayers.removeAll()
            hideVoiceHighlights()
            return
        }

        let targetCount = desiredCopyCount()
        let shouldRebuild = force || scriptLayers.count != targetCount
        if shouldRebuild {
            scriptLayers.forEach { $0.removeFromSuperview() }
            scriptLayers.removeAll(keepingCapacity: true)

            for _ in 0..<targetCount {
                let scriptLayer = NSImageView(frame: .zero)
                scriptLayer.imageAlignment = .alignTopLeft
                scriptLayer.imageScaling = .scaleAxesIndependently
                scriptLayers.append(scriptLayer)
                addSubview(scriptLayer)
            }
        }

        for scriptLayer in scriptLayers {
            scriptLayer.image = renderedImage
        }

        addSubview(lineHighlightView)
    }

    private func applyPhaseToLayers() {
        guard !scriptLayers.isEmpty else { return }

        let cycleLength = max(contentHeight + Self.loopGap, 1)
        let width = max(bounds.width, 1)
        let wrappedPhase = phase.truncatingRemainder(dividingBy: cycleLength)
        let baseY = -wrappedPhase

        for (index, scriptLayer) in scriptLayers.enumerated() {
            let yOffset = baseY + CGFloat(index) * cycleLength
            scriptLayer.frame = CGRect(x: 0, y: yOffset, width: width, height: contentHeight)
        }

        updateVoiceHighlightViews()
    }

    private func rebuildTextLayoutIfNeeded(force: Bool) {
        let width = max(bounds.width, 1)
        let normalizedFontSize = max(1, round(scriptFontSize * 10) / 10)
        let needsRebuild =
            force ||
            cachedLayoutText != scriptText ||
            abs(cachedLayoutFontSize - normalizedFontSize) > 0.1 ||
            abs(cachedLayoutWidth - width) > 1
        guard needsRebuild else { return }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .justified
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.hyphenationFactor = 0.9

        let attributed = NSAttributedString(
            string: scriptText,
            attributes: [
                .font: NSFont.systemFont(ofSize: normalizedFontSize, weight: .regular),
                .paragraphStyle: paragraph
            ]
        )

        let storage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)

        self.layoutStorage = storage
        self.layoutManager = layoutManager
        self.layoutContainer = container
        cachedLayoutText = scriptText
        cachedLayoutFontSize = normalizedFontSize
        cachedLayoutWidth = width
    }

    private func refreshVoiceHighlightGeometry() {
        guard voiceMode == .vad,
              let matchedRange = voiceMatchedRange,
              let layoutManager,
              let layoutContainer,
              !scriptText.isEmpty,
              matchedRange.location != NSNotFound else {
            matchedLineRectInScript = nil
            matchedWordRectInScript = nil
                        speechSeekTargetPhase = nil
            hideVoiceHighlights()
            return
        }

        let nsText = scriptText as NSString
        guard matchedRange.location < nsText.length else {
            matchedLineRectInScript = nil
            matchedWordRectInScript = nil
            speechSeekTargetPhase = nil
            hideVoiceHighlights()
            return
        }

        let safeLength = min(max(matchedRange.length, 1), nsText.length - matchedRange.location)
        let safeRange = NSRange(location: matchedRange.location, length: safeLength)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: safeRange, actualCharacterRange: nil)
        guard glyphRange.length > 0 else {
            matchedLineRectInScript = nil
            matchedWordRectInScript = nil
            speechSeekTargetPhase = nil
            hideVoiceHighlights()
            return
        }

        var lineRectUnion: CGRect = .null
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
            if lineRectUnion.isNull {
                lineRectUnion = usedRect
            } else {
                lineRectUnion = lineRectUnion.union(usedRect)
            }
        }

        let wordRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: layoutContainer)
        let fallbackLineRect = wordRect
        let lineRect = lineRectUnion.isNull ? fallbackLineRect : lineRectUnion
        let fullLineRect = CGRect(
            x: 0,
            y: lineRect.minY,
            width: max(bounds.width, lineRect.maxX),
            height: max(1, lineRect.height)
        )

        matchedLineRectInScript = fullLineRect.integral
        matchedWordRectInScript = wordRect.integral
        updateVoiceHighlightViews()
    }

    private func seekToMatchedRangeIfNeeded() {
        guard voiceMode == .vad,
              let matchedWordRectInScript else { return }

        let anchorY = max(18, min(bounds.height * 0.35, max(24, bounds.height - 26)))
        var targetPhase = matchedWordRectInScript.minY - anchorY
        targetPhase = max(targetPhase, topOfScriptPhaseFloor)

        if scrollMode == .stopAtEnd, hasMeasuredContentHeight {
            targetPhase = min(max(targetPhase, topOfScriptPhaseFloor), endPhase)
        } else {
            let cycleLength = max(contentHeight + Self.loopGap, 1)
            targetPhase = nearestWrappedPhase(to: targetPhase, cycleLength: cycleLength)
            targetPhase = max(targetPhase, topOfScriptPhaseFloor)
        }

        let delta = targetPhase - phase
        let deadZone = max(14, min(30, scriptFontSize * 1.8))
        guard abs(delta) > deadZone else {
            speechSeekTargetPhase = nil
            return
        }

        if let existingTarget = speechSeekTargetPhase {
            let targetDelta = targetPhase - existingTarget
            if abs(targetDelta) < 20 {
                return
            }
            speechSeekTargetPhase = existingTarget + (targetDelta * 0.35)
        } else {
            speechSeekTargetPhase = targetPhase
        }
        updateTimerIfNeeded()
    }

    private func nearestWrappedPhase(to targetPhase: CGFloat, cycleLength: CGFloat) -> CGFloat {
        let base = phase - phase.truncatingRemainder(dividingBy: cycleLength)
        let wrappedTarget = targetPhase.truncatingRemainder(dividingBy: cycleLength)
        let candidates = [
            base + wrappedTarget,
            base + wrappedTarget - cycleLength,
            base + wrappedTarget + cycleLength
        ]
        return candidates.min(by: { abs($0 - phase) < abs($1 - phase) }) ?? targetPhase
    }

    private func updateVoiceHighlightViews() {
        guard voiceMode == .vad,
              let matchedLineRectInScript,
              let matchedWordRectInScript,
              !scriptLayers.isEmpty else {
            hideVoiceHighlights()
            return
        }

        let projections: [(line: CGRect, word: CGRect)] = scriptLayers.map { layer in
            (
                line: matchedLineRectInScript.offsetBy(dx: 0, dy: layer.frame.minY),
                word: matchedWordRectInScript.offsetBy(dx: 0, dy: layer.frame.minY)
            )
        }

        let paddedBounds = bounds.insetBy(dx: -24, dy: -24)
        let selected = projections.first(where: { $0.word.intersects(paddedBounds) }) ??
            projections.min(by: { abs($0.word.midY - bounds.midY) < abs($1.word.midY - bounds.midY) })

        guard let selected,
              selected.word.maxY >= -24,
              selected.word.minY <= bounds.height + 24 else {
            hideVoiceHighlights()
            return
        }

        let lineFrame = selected.line.insetBy(dx: -3, dy: -1)

        if lineFrame.width <= 0 || lineFrame.height <= 0 {
            hideVoiceHighlights()
            return
        }

        lineHighlightView.frame = lineFrame
        lineHighlightView.isHidden = false
        addSubview(lineHighlightView)
    }

    private func hideVoiceHighlights() {
        lineHighlightView.isHidden = true
    }

    private func tickInterval() -> TimeInterval {
        let shouldRun =
            (isRunning && !isHovering) &&
            voiceSpeedMultiplier > 0.01 &&
            !(scrollMode == .stopAtEnd && hasReachedEndInStopMode)
        if shouldRun {
            return Self.activeTickInterval
        }
        if speechSeekTargetPhase != nil {
            return Self.activeTickInterval
        }
        if currentSpeedMultiplier > 0.002 || deferredStopTargetPhase != nil {
            return Self.settlingTickInterval
        }
        return Self.idleTickInterval
    }

    private func updateTimerIfNeeded() {
        guard window != nil else {
            timer?.invalidate()
            timer = nil
            timerInterval = 0
            return
        }

        let nextInterval = tickInterval()
        let shouldAnimate = isRunning || currentSpeedMultiplier > 0.002 || deferredStopTargetPhase != nil || speechSeekTargetPhase != nil

        if !shouldAnimate && scrollMode == .stopAtEnd && hasReachedEndInStopMode {
            timer?.invalidate()
            timer = nil
            timerInterval = 0
            return
        }

        guard timer == nil || abs(nextInterval - timerInterval) > 0.0005 else { return }

        timer?.invalidate()
        timerInterval = nextInterval
        let nextTimer = Timer(timeInterval: nextInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(nextTimer, forMode: .common)
        timer = nextTimer
    }

    private func tick() {
        let shouldRun =
            (isRunning && !isHovering) &&
            voiceSpeedMultiplier > 0.01 &&
            !(scrollMode == .stopAtEnd && hasReachedEndInStopMode)
        let targetSpeedMultiplier = shouldRun ? voiceSpeedMultiplier : 0.0

        if !shouldRun, currentSpeedMultiplier == 0, deferredStopTargetPhase == nil, speechSeekTargetPhase == nil {
            lastTickDate = Date()
            updateTimerIfNeeded()
            return
        }

        let now = Date()
        let deltaTime: CGFloat
        if let lastTickDate {
            deltaTime = max(0, min(CGFloat(now.timeIntervalSince(lastTickDate)), 0.25))
        } else {
            deltaTime = CGFloat(Self.activeTickInterval)
        }

        if deltaTime <= 0.0001 {
            self.lastTickDate = now
            return
        }

        let cycleLength = max(contentHeight + Self.loopGap, 1)
        let phaseWrapLimit = cycleLength * 8

        var nextPhase = phase
        var nextSpeedMultiplier = currentSpeedMultiplier
        var nextDeferredStopTargetPhase = deferredStopTargetPhase
        var reachedEndInStopMode = hasReachedEndInStopMode
        var didReachEndThisTick = false

        let speedDelta = targetSpeedMultiplier - nextSpeedMultiplier
        if abs(speedDelta) > 0.001 {
            nextSpeedMultiplier += speedDelta * min(1.0, speedResponseRate * deltaTime)
        } else {
            nextSpeedMultiplier = targetSpeedMultiplier
        }

        let effectiveBaseSpeed = voiceMode == .vad ? PrompterModel.voiceHoldBaseSpeed : speedPointsPerSecond
        nextPhase += CGFloat(effectiveBaseSpeed) * CGFloat(nextSpeedMultiplier) * deltaTime

        if let seekTarget = speechSeekTargetPhase {
            let seekDelta = seekTarget - nextPhase
            let maxSeekStep = max(4, min(28, deltaTime * 120))
            let boundedSeek = max(-maxSeekStep, min(maxSeekStep, seekDelta))
            nextPhase += boundedSeek
            if abs(seekDelta) <= 2.0 {
                speechSeekTargetPhase = nil
            }
        }

        if scrollMode == .stopAtEnd, hasMeasuredContentHeight {
            let localEndPhase = endPhase
            if nextDeferredStopTargetPhase == nil, !reachedEndInStopMode {
                let visiblePhase = nextPhase.truncatingRemainder(dividingBy: cycleLength)
                let cycleStart = nextPhase - visiblePhase
                nextDeferredStopTargetPhase = visiblePhase <= localEndPhase
                    ? cycleStart + localEndPhase
                    : cycleStart + cycleLength + localEndPhase
            }

            if let target = nextDeferredStopTargetPhase,
               nextPhase >= target {
                nextPhase = target
                nextSpeedMultiplier = 0
                nextDeferredStopTargetPhase = nil

                if !reachedEndInStopMode {
                    reachedEndInStopMode = true
                    didReachEndThisTick = true
                }
            }
        }

        if !isRunning, nextSpeedMultiplier < 0.002 {
            nextSpeedMultiplier = 0
        }

        if scrollMode == .infinite, nextPhase >= phaseWrapLimit {
            nextPhase = nextPhase.truncatingRemainder(dividingBy: cycleLength)
        }

        nextPhase = max(nextPhase, topOfScriptPhaseFloor)

        var didMove = false
        if abs(nextPhase - phase) > Self.phaseCommitEpsilon {
            phase = nextPhase
            didMove = true
        }
        if abs(nextSpeedMultiplier - currentSpeedMultiplier) > Self.speedCommitEpsilon {
            currentSpeedMultiplier = nextSpeedMultiplier
        }

        let optionalPhaseChanged: Bool
        switch (deferredStopTargetPhase, nextDeferredStopTargetPhase) {
        case (.none, .none):
            optionalPhaseChanged = false
        case let (.some(old), .some(new)):
            optionalPhaseChanged = abs(old - new) > Self.phaseCommitEpsilon
        default:
            optionalPhaseChanged = true
        }
        if optionalPhaseChanged {
            deferredStopTargetPhase = nextDeferredStopTargetPhase
        }

        if hasReachedEndInStopMode != reachedEndInStopMode {
            hasReachedEndInStopMode = reachedEndInStopMode
        }

        if didMove {
            applyPhaseToLayers()
        }

        if didReachEndThisTick {
            onReachedEnd?()
        }

        lastTickDate = now
        updateTimerIfNeeded()
    }
}
