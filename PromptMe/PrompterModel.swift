import Foundation
import Combine
import CoreGraphics

@MainActor
final class PrompterModel: ObservableObject {
    struct PromptEntry: Identifiable, Codable, Equatable {
        var id: UUID
        var title: String
        var text: String
        var createdAt: Date
        var updatedAt: Date
    }

    enum ScrollMode: String, CaseIterable {
        case infinite
        case stopAtEnd
    }

    enum CountdownBehavior: String, CaseIterable {
        case always
        case freshStartOnly
        case never

        var label: String {
            switch self {
            case .always:
                return "Always"
            case .freshStartOnly:
                return "Fresh start only"
            case .never:
                return "Never"
            }
        }
    }

    enum VoicePromptMode: String, CaseIterable {
        case off
        case vad

        var label: String {
            switch self {
            case .off:
                return "Classic"
            case .vad:
                return "Voice Hold"
            }
        }
    }

    static let shared = PrompterModel()

    private static let starterPromptTitle = "Main Prompt"
    private static let starterScriptText = """
Paste your script here.

Tip: Use the menu bar icon to start/pause or reset the scroll.
"""

    @Published private(set) var script: String
    @Published private(set) var prompts: [PromptEntry]
    @Published private(set) var activePromptID: UUID
    @Published private(set) var promptLibraryRevision: UInt64 = 0

    @Published var isRunning: Bool = false
    @Published var manualScrollEnabled: Bool = false
    @Published var hoverPauseEnabled: Bool = true
    @Published var isOverlayVisible: Bool = true
    @Published var privacyModeEnabled: Bool = true
    @Published private(set) var hasStartedSession: Bool = false
    @Published private(set) var isCountingDown: Bool = false
    @Published var countdownSeconds: Int = 3
    @Published var countdownBehavior: CountdownBehavior = .freshStartOnly
    @Published private(set) var countdownRemaining: Int = 0
    @Published private(set) var didReachEndInStopMode: Bool = false

    @Published var speedPointsPerSecond: Double = 25
    @Published var fontSize: Double = 16
    @Published var overlayWidth: Double = 760
    @Published var overlayHeight: Double = 260
    // Deprecated setting kept fixed for backward compatibility.
    @Published var backgroundOpacity: Double = 1.0
    @Published var scrollMode: ScrollMode = .infinite
    @Published var voicePromptMode: VoicePromptMode = .off
    @Published var voiceSensitivity: Double = 0.55
    @Published private(set) var voiceSignalLevel: Double = 0
    @Published private(set) var isVoiceSpeechDetected: Bool = false
    @Published private(set) var voiceSpeedMultiplier: Double = 1
    @Published private(set) var voiceInputDeviceName: String = "System default microphone"
    @Published private(set) var voiceStatusText: String = "Voice assist is off. Classic auto-scroll is active."
    @Published private(set) var voicePermissionDenied: Bool = false
    @Published private(set) var voiceFallbackToClassic: Bool = false
    @Published private(set) var voiceMatchedRange: NSRange?
    @Published private(set) var voiceAlignmentToken: UUID = UUID()
    // 0 means automatic display selection.
    @Published var selectedScreenID: CGDirectDisplayID = 0
    let edgeFadeFraction: Double = 0.20

    @Published private(set) var resetToken: UUID = UUID()
    @Published private(set) var jumpBackToken: UUID = UUID()
    @Published private(set) var jumpBackDistancePoints: CGFloat = 0
    @Published private(set) var manualScrollToken: UUID = UUID()
    @Published private(set) var manualScrollDeltaPoints: CGFloat = 0
    private(set) var savedScrollPhaseForResume: CGFloat?

    private var countdownTask: Task<Void, Never>?
    private var shouldUseCountdownOnNextStart: Bool = true
    private var lastSavedDefaultsSnapshot: DefaultsSnapshot?
    private var scriptRevision: UInt64 = 0
    private var cachedDurationScriptRevision: UInt64 = .max
    private var cachedDurationSpeed: Double = .nan
    private var cachedEstimatedDuration: TimeInterval = 0

    static let speedRange: ClosedRange<Double> = 5...60
    static let speedStep: Double = 5
    static let speedPresetNormal: Double = 25
    static let voiceHoldBaseSpeed: Double = 5
    static let voiceSensitivityRange: ClosedRange<Double> = 0...1

    private enum DefaultsKey {
        static let hasSavedSession = "hasSavedSession"
        static let script = "script"
        static let promptLibraryData = "promptLibraryData"
        static let activePromptID = "activePromptID"
        static let isRunning = "isRunning"
        static let hoverPauseEnabled = "hoverPauseEnabled"
        static let isOverlayVisible = "isOverlayVisible"
        static let privacyModeEnabled = "privacyModeEnabled"
        static let speed = "speedPointsPerSecond"
        static let fontSize = "fontSize"
        static let overlayWidth = "overlayWidth"
        static let overlayHeight = "overlayHeight"
        static let countdownSeconds = "countdownSeconds"
        static let countdownBehavior = "countdownBehavior"
        static let scrollMode = "scrollMode"
        static let voicePromptMode = "voicePromptMode"
        static let voiceSensitivity = "voiceSensitivity"
        static let selectedScreenID = "selectedScreenID"
    }

    private struct DefaultsSnapshot: Equatable {
        let scriptRevision: UInt64
        let promptLibraryRevision: UInt64
        let hoverPauseEnabled: Bool
        let isOverlayVisible: Bool
        let privacyModeEnabled: Bool
        let speedPointsPerSecond: Double
        let fontSize: Double
        let overlayHeight: Double
        let countdownSeconds: Int
        let countdownBehaviorRawValue: String
        let scrollModeRawValue: String
        let voicePromptModeRawValue: String
        let voiceSensitivity: Double
        let selectedScreenID: CGDirectDisplayID
    }

    private init() {
        let starterPrompt = Self.makeStarterPrompt()
        _script = Published(initialValue: starterPrompt.text)
        _prompts = Published(initialValue: [starterPrompt])
        _activePromptID = Published(initialValue: starterPrompt.id)
    }

    deinit {
        countdownTask?.cancel()
    }

    var activePrompt: PromptEntry? {
        prompt(withID: activePromptID)
    }

    func prompt(withID id: UUID) -> PromptEntry? {
        prompts.first(where: { $0.id == id })
    }

    func isActivePrompt(_ id: UUID) -> Bool {
        activePromptID == id
    }

    func setActivePrompt(_ id: UUID) {
        guard prompts.contains(where: { $0.id == id }) else { return }
        let isChangingPrompt = activePromptID != id

        if isChangingPrompt {
            if isRunning || isCountingDown {
                stop()
            }
            manualScrollEnabled = false
            savedScrollPhaseForResume = nil
            didReachEndInStopMode = false
            shouldUseCountdownOnNextStart = true
            voiceMatchedRange = nil
            voiceAlignmentToken = UUID()
            activePromptID = id
            markPromptLibraryChanged()
            resetToken = UUID()
        }

        if let activePrompt = prompt(withID: id) {
            setScriptValue(activePrompt.text)
        }
    }

    @discardableResult
    func createPrompt(title: String? = nil, text: String = "") -> UUID {
        let now = Date()
        let baseTitle = sanitizePromptTitle(title ?? "Prompt")
        let newPrompt = PromptEntry(
            id: UUID(),
            title: uniquePromptTitle(from: baseTitle),
            text: text,
            createdAt: now,
            updatedAt: now
        )

        prompts.insert(newPrompt, at: 0)
        markPromptLibraryChanged()
        return newPrompt.id
    }

    @discardableResult
    func duplicatePrompt(id: UUID) -> UUID? {
        guard let sourceIndex = prompts.firstIndex(where: { $0.id == id }) else { return nil }
        let sourcePrompt = prompts[sourceIndex]
        let now = Date()
        let duplicate = PromptEntry(
            id: UUID(),
            title: uniquePromptTitle(from: "\(sourcePrompt.title) Copy"),
            text: sourcePrompt.text,
            createdAt: now,
            updatedAt: now
        )

        prompts.insert(duplicate, at: sourceIndex + 1)
        markPromptLibraryChanged()
        return duplicate.id
    }

    @discardableResult
    func deletePrompt(id: UUID) -> UUID {
        guard let index = prompts.firstIndex(where: { $0.id == id }) else { return activePromptID }

        if prompts.count == 1 {
            prompts[index].title = Self.starterPromptTitle
            prompts[index].text = ""
            prompts[index].updatedAt = Date()
            activePromptID = prompts[index].id
            setScriptValue(prompts[index].text)
            markPromptLibraryChanged()
            return prompts[index].id
        }

        prompts.remove(at: index)
        var nextSelection = activePromptID

        if activePromptID == id {
            let fallbackIndex = min(index, prompts.count - 1)
            nextSelection = prompts[fallbackIndex].id
            activePromptID = nextSelection
            if let activePrompt = prompt(withID: nextSelection) {
                setScriptValue(activePrompt.text)
            }
        }

        markPromptLibraryChanged()
        return nextSelection
    }

    @discardableResult
    func updatePromptTitle(_ title: String, for id: UUID) -> Bool {
        guard let index = prompts.firstIndex(where: { $0.id == id }) else { return false }
        let sanitizedTitle = sanitizePromptTitle(title)
        guard prompts[index].title != sanitizedTitle else { return false }

        prompts[index].title = sanitizedTitle
        prompts[index].updatedAt = Date()
        markPromptLibraryChanged()
        return true
    }

    @discardableResult
    func updatePromptText(_ text: String, for id: UUID) -> Bool {
        guard let index = prompts.firstIndex(where: { $0.id == id }) else { return false }
        guard prompts[index].text != text else { return false }

        prompts[index].text = text
        prompts[index].updatedAt = Date()
        if id == activePromptID {
            setScriptValue(text)
        }
        markPromptLibraryChanged()
        return true
    }

    @discardableResult
    func setScript(_ text: String) -> Bool {
        if updatePromptText(text, for: activePromptID) {
            return true
        }

        guard script != text else { return false }
        setScriptValue(text)
        return true
    }

    func pasteScript(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let wasEmpty = script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if setScript(text), wasEmpty {
            hasStartedSession = true
        }
    }

    func resetScroll() {
        if didReachEndInStopMode {
            didReachEndInStopMode = false
        }
        shouldUseCountdownOnNextStart = true
        savedScrollPhaseForResume = nil
        resetToken = UUID()
    }

    func saveScrollPhaseForResume(_ phase: CGFloat) {
        guard savedScrollPhaseForResume != phase else { return }
        savedScrollPhaseForResume = phase
    }

    func jumpBack(seconds: Double = 5) {
        guard seconds > 0 else { return }
        didReachEndInStopMode = false
        let baseSpeed = voicePromptMode == .vad ? Self.voiceHoldBaseSpeed : speedPointsPerSecond
        jumpBackDistancePoints = CGFloat(baseSpeed * seconds)
        jumpBackToken = UUID()
    }

    func switchPlaybackModeFromOverlayControl() {
        if isRunning || isCountingDown {
            stop()
            if !manualScrollEnabled {
                manualScrollEnabled = true
            }
            if didReachEndInStopMode {
                didReachEndInStopMode = false
            }
            if !hasStartedSession {
                hasStartedSession = true
            }
            shouldUseCountdownOnNextStart = false
            return
        }

        manualScrollEnabled = false
        start()
    }

    func handleManualScroll(deltaPoints: CGFloat) {
        guard abs(deltaPoints) > 0.01 else { return }

        if isCountingDown {
            return
        }

        if !manualScrollEnabled {
            manualScrollEnabled = true
        }

        if isRunning {
            stop()
        }

        if didReachEndInStopMode {
            didReachEndInStopMode = false
        }
        if !hasStartedSession {
            hasStartedSession = true
        }
        shouldUseCountdownOnNextStart = false
        manualScrollDeltaPoints = deltaPoints
        manualScrollToken = UUID()
    }

    func toggleRunning() {
        if isRunning || isCountingDown {
            stop()
        } else {
            start()
        }
    }

    func start() {
        if isRunning || isCountingDown {
            return
        }

        manualScrollEnabled = false

        if scrollMode == .stopAtEnd, didReachEndInStopMode {
            // Restart from top after a terminal stop.
            resetScroll()
        }

        let delay = max(0, countdownSeconds)
        let shouldRunCountdown: Bool
        switch countdownBehavior {
        case .always:
            shouldRunCountdown = delay > 0
        case .freshStartOnly:
            shouldRunCountdown = delay > 0 && shouldUseCountdownOnNextStart
        case .never:
            shouldRunCountdown = false
        }

        guard shouldRunCountdown else {
            beginRunningNow()
            return
        }

        beginCountdown(seconds: delay)
    }

    func markReachedEndInStopMode() {
        guard scrollMode == .stopAtEnd else { return }
        didReachEndInStopMode = true
        stop()
    }

    func setScrollMode(_ newMode: ScrollMode) {
        // Defer transition to avoid publishing during view updates.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let oldMode = self.scrollMode
            guard oldMode != newMode else { return }
            let wasTerminalStopState = (oldMode == .stopAtEnd && self.didReachEndInStopMode)

            self.scrollMode = newMode

            if newMode == .infinite {
                if self.didReachEndInStopMode {
                    self.didReachEndInStopMode = false
                }
                if wasTerminalStopState {
                    if !self.hasStartedSession {
                        self.hasStartedSession = true
                    }
                    if self.isCountingDown {
                        self.isCountingDown = false
                    }
                    if self.countdownRemaining != 0 {
                        self.countdownRemaining = 0
                    }
                    self.countdownTask?.cancel()
                    self.countdownTask = nil
                    self.shouldUseCountdownOnNextStart = false
                    if !self.isRunning {
                        self.isRunning = true
                    }
                }
            }
        }
    }

    func stop() {
        countdownTask?.cancel()
        countdownTask = nil
        if isCountingDown {
            isCountingDown = false
        }
        if countdownRemaining != 0 {
            countdownRemaining = 0
        }
        if isRunning {
            isRunning = false
        }
    }

    func setSpeed(_ value: Double) {
        let clamped = clampedSpeed(value)
        guard speedPointsPerSecond != clamped else { return }
        speedPointsPerSecond = clamped
    }

    func adjustSpeed(delta: Double) {
        let newValue = speedPointsPerSecond + delta
        setSpeed(newValue)
    }

    func applySpeedPreset(_ preset: Double) {
        setSpeed(preset)
    }

    func applyVoiceRuntimeState(_ state: VoicePromptingController.RuntimeState) {
        let normalizedSignalLevel = clamp(state.signalLevel, lower: 0, upper: 1)
        if abs(voiceSignalLevel - normalizedSignalLevel) > 0.005 {
            voiceSignalLevel = normalizedSignalLevel
        }

        let normalizedMultiplier = clamp(state.speedMultiplier, lower: 0, upper: 1.6)
        if abs(voiceSpeedMultiplier - normalizedMultiplier) > 0.002 {
            voiceSpeedMultiplier = normalizedMultiplier
        }

        if isVoiceSpeechDetected != state.isSpeechDetected {
            isVoiceSpeechDetected = state.isSpeechDetected
        }
        if voiceInputDeviceName != state.inputDeviceName {
            voiceInputDeviceName = state.inputDeviceName
        }
        if voiceStatusText != state.statusText {
            voiceStatusText = state.statusText
        }
        if voicePermissionDenied != state.permissionDenied {
            voicePermissionDenied = state.permissionDenied
        }
        if voiceFallbackToClassic != state.fallbackToClassic {
            voiceFallbackToClassic = state.fallbackToClassic
        }
        if voiceMatchedRange != state.matchedRange {
            voiceMatchedRange = state.matchedRange
            voiceAlignmentToken = UUID()
        }
    }

    var estimatedReadDuration: TimeInterval {
        updateEstimatedDurationCacheIfNeeded()
        return cachedEstimatedDuration
    }

    func formattedEstimatedReadDuration() -> String {
        formatDuration(seconds: estimatedReadDuration)
    }

    func formattedEstimatedReadDuration(for text: String) -> String {
        formatDuration(seconds: estimatedReadDuration(for: text, speed: speedPointsPerSecond))
    }

    private func updateEstimatedDurationCacheIfNeeded() {
        guard cachedDurationScriptRevision != scriptRevision || cachedDurationSpeed != speedPointsPerSecond else {
            return
        }

        cachedDurationScriptRevision = scriptRevision
        cachedDurationSpeed = speedPointsPerSecond
        cachedEstimatedDuration = estimatedReadDuration(for: script, speed: speedPointsPerSecond)
    }

    func loadFromDefaults() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: DefaultsKey.hasSavedSession) else {
            return
        }

        let loadedPrompts = decodePromptLibrary(from: defaults.data(forKey: DefaultsKey.promptLibraryData))
        if let loadedPrompts, !loadedPrompts.isEmpty {
            prompts = loadedPrompts
        } else {
            let legacyScript = defaults.string(forKey: DefaultsKey.script) ?? Self.starterScriptText
            let now = Date()
            prompts = [
                PromptEntry(
                    id: UUID(),
                    title: Self.starterPromptTitle,
                    text: legacyScript,
                    createdAt: now,
                    updatedAt: now
                )
            ]
        }

        if let rawActivePromptID = defaults.string(forKey: DefaultsKey.activePromptID),
           let parsedID = UUID(uuidString: rawActivePromptID),
           prompts.contains(where: { $0.id == parsedID }) {
            activePromptID = parsedID
        } else {
            activePromptID = prompts[0].id
        }

        if let activePrompt = prompt(withID: activePromptID) {
            setScriptValue(activePrompt.text, bumpRevision: false)
        } else {
            setScriptValue("", bumpRevision: false)
        }
        scriptRevision = 0
        promptLibraryRevision = 0

        privacyModeEnabled = defaults.object(forKey: DefaultsKey.privacyModeEnabled) as? Bool ?? privacyModeEnabled
        hoverPauseEnabled = defaults.object(forKey: DefaultsKey.hoverPauseEnabled) as? Bool ?? hoverPauseEnabled
        isOverlayVisible = defaults.object(forKey: DefaultsKey.isOverlayVisible) as? Bool ?? true
        // Require explicit start on launch.
        isRunning = false
        isCountingDown = false
        countdownRemaining = 0
        hasStartedSession = false
        shouldUseCountdownOnNextStart = true
        speedPointsPerSecond = clampedSpeed(defaults.object(forKey: DefaultsKey.speed) as? Double ?? speedPointsPerSecond)
        fontSize = clamp(defaults.object(forKey: DefaultsKey.fontSize) as? Double ?? fontSize, lower: 12, upper: 40)
        overlayWidth = 760
        defaults.removeObject(forKey: DefaultsKey.overlayWidth)
        overlayHeight = clamp(defaults.object(forKey: DefaultsKey.overlayHeight) as? Double ?? overlayHeight, lower: 120, upper: 420)
        // Opacity UI was removed; persist as fully opaque.
        backgroundOpacity = 1.0
        defaults.removeObject(forKey: "backgroundOpacity")
        countdownSeconds = Int(clamp(Double(defaults.object(forKey: DefaultsKey.countdownSeconds) as? Int ?? countdownSeconds), lower: 0, upper: 10))
        if let rawValue = defaults.string(forKey: DefaultsKey.countdownBehavior),
           let savedBehavior = CountdownBehavior(rawValue: rawValue) {
            countdownBehavior = savedBehavior
        } else {
            countdownBehavior = .freshStartOnly
        }
        if let rawValue = defaults.string(forKey: DefaultsKey.scrollMode),
           let savedMode = ScrollMode(rawValue: rawValue) {
            scrollMode = savedMode
        } else {
            scrollMode = .infinite
        }
        if let rawValue = defaults.string(forKey: DefaultsKey.voicePromptMode),
           let savedMode = VoicePromptMode(rawValue: rawValue) {
            voicePromptMode = savedMode
        } else {
            voicePromptMode = .off
        }
        voiceSensitivity = clamp(defaults.object(forKey: DefaultsKey.voiceSensitivity) as? Double ?? voiceSensitivity, lower: Self.voiceSensitivityRange.lowerBound, upper: Self.voiceSensitivityRange.upperBound)
        voiceSignalLevel = 0
        isVoiceSpeechDetected = false
        voiceSpeedMultiplier = 1
        voiceInputDeviceName = "System default microphone"
        voiceStatusText = "Voice assist is off. Classic auto-scroll is active."
        voicePermissionDenied = false
        voiceFallbackToClassic = false
        voiceMatchedRange = nil
        voiceAlignmentToken = UUID()
        selectedScreenID = CGDirectDisplayID(defaults.object(forKey: DefaultsKey.selectedScreenID) as? UInt32 ?? 0)
        lastSavedDefaultsSnapshot = makeDefaultsSnapshot()
    }

    func saveToDefaults() {
        let snapshot = makeDefaultsSnapshot()
        guard snapshot != lastSavedDefaultsSnapshot else { return }

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: DefaultsKey.hasSavedSession)
        defaults.set(script, forKey: DefaultsKey.script)
        defaults.set(activePromptID.uuidString, forKey: DefaultsKey.activePromptID)
        if let data = try? JSONEncoder().encode(prompts) {
            defaults.set(data, forKey: DefaultsKey.promptLibraryData)
        }
        defaults.set(snapshot.hoverPauseEnabled, forKey: DefaultsKey.hoverPauseEnabled)
        defaults.set(snapshot.isOverlayVisible, forKey: DefaultsKey.isOverlayVisible)
        defaults.set(snapshot.privacyModeEnabled, forKey: DefaultsKey.privacyModeEnabled)
        defaults.set(snapshot.speedPointsPerSecond, forKey: DefaultsKey.speed)
        defaults.set(snapshot.fontSize, forKey: DefaultsKey.fontSize)
        defaults.set(snapshot.overlayHeight, forKey: DefaultsKey.overlayHeight)
        defaults.set(snapshot.countdownSeconds, forKey: DefaultsKey.countdownSeconds)
        defaults.set(snapshot.countdownBehaviorRawValue, forKey: DefaultsKey.countdownBehavior)
        defaults.set(snapshot.scrollModeRawValue, forKey: DefaultsKey.scrollMode)
        defaults.set(snapshot.voicePromptModeRawValue, forKey: DefaultsKey.voicePromptMode)
        defaults.set(snapshot.voiceSensitivity, forKey: DefaultsKey.voiceSensitivity)
        defaults.set(snapshot.selectedScreenID, forKey: DefaultsKey.selectedScreenID)
        lastSavedDefaultsSnapshot = snapshot
    }

    private func makeDefaultsSnapshot() -> DefaultsSnapshot {
        DefaultsSnapshot(
            scriptRevision: scriptRevision,
            promptLibraryRevision: promptLibraryRevision,
            hoverPauseEnabled: hoverPauseEnabled,
            isOverlayVisible: isOverlayVisible,
            privacyModeEnabled: privacyModeEnabled,
            speedPointsPerSecond: speedPointsPerSecond,
            fontSize: fontSize,
            overlayHeight: overlayHeight,
            countdownSeconds: countdownSeconds,
            countdownBehaviorRawValue: countdownBehavior.rawValue,
            scrollModeRawValue: scrollMode.rawValue,
            voicePromptModeRawValue: voicePromptMode.rawValue,
            voiceSensitivity: voiceSensitivity,
            selectedScreenID: selectedScreenID
        )
    }

    private func beginCountdown(seconds: Int) {
        countdownTask?.cancel()
        isCountingDown = true
        countdownRemaining = seconds

        countdownTask = Task { @MainActor in
            var remaining = seconds
            while remaining > 0 {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    if isCountingDown {
                        isCountingDown = false
                    }
                    if countdownRemaining != 0 {
                        countdownRemaining = 0
                    }
                    countdownTask = nil
                    return
                }
                remaining -= 1
                countdownRemaining = remaining
            }

            guard !Task.isCancelled else { return }
            beginRunningNow()
            countdownTask = nil
        }
    }

    private func beginRunningNow() {
        if isCountingDown {
            isCountingDown = false
        }
        if countdownRemaining != 0 {
            countdownRemaining = 0
        }
        if !hasStartedSession {
            hasStartedSession = true
        }
        shouldUseCountdownOnNextStart = false
        if !isRunning {
            isRunning = true
        }
    }

    private func clampedSpeed(_ value: Double) -> Double {
        let clamped = clamp(value, lower: Self.speedRange.lowerBound, upper: Self.speedRange.upperBound)
        let step = Self.speedStep
        return (clamped / step).rounded() * step
    }

    private func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private static func makeStarterPrompt() -> PromptEntry {
        let now = Date()
        return PromptEntry(
            id: UUID(),
            title: starterPromptTitle,
            text: starterScriptText,
            createdAt: now,
            updatedAt: now
        )
    }

    private func setScriptValue(_ text: String, bumpRevision: Bool = true) {
        guard script != text else { return }
        script = text
        if bumpRevision {
            scriptRevision &+= 1
        }
    }

    private func sanitizePromptTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Prompt" : trimmed
    }

    private func uniquePromptTitle(from baseTitle: String) -> String {
        let base = sanitizePromptTitle(baseTitle)
        let existing = Set(prompts.map { $0.title.lowercased() })
        if !existing.contains(base.lowercased()) {
            return base
        }

        var index = 2
        while existing.contains("\(base) \(index)".lowercased()) {
            index += 1
        }
        return "\(base) \(index)"
    }

    private func markPromptLibraryChanged() {
        promptLibraryRevision &+= 1
    }

    private func decodePromptLibrary(from data: Data?) -> [PromptEntry]? {
        guard let data else { return nil }
        guard let decoded = try? JSONDecoder().decode([PromptEntry].self, from: data) else {
            return nil
        }

        let normalized = decoded.map { prompt -> PromptEntry in
            var normalizedPrompt = prompt
            normalizedPrompt.title = sanitizePromptTitle(prompt.title)
            return normalizedPrompt
        }
        return normalized.isEmpty ? nil : normalized
    }

    private func estimatedReadDuration(for text: String, speed: Double) -> TimeInterval {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        let words = max(1, trimmed.split(whereSeparator: \.isWhitespace).count)
        let baselineWPM = 160.0
        let speedFactor = speed / Self.speedPresetNormal
        let adjustedWPM = max(60, baselineWPM * speedFactor)
        let minutes = Double(words) / adjustedWPM
        return minutes * 60
    }

    private func formatDuration(seconds: TimeInterval) -> String {
        let duration = Int(round(seconds))
        guard duration > 0 else { return "~0s" }
        if duration < 60 {
            return "~\(duration)s"
        }
        let minutes = duration / 60
        let remainderSeconds = duration % 60
        return String(format: "~%dm %02ds", minutes, remainderSeconds)
    }
}