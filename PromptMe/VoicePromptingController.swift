import AppKit
import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class VoicePromptingController: NSObject, ObservableObject {
    struct RuntimeState: Equatable {
        let signalLevel: Double
        let isSpeechDetected: Bool
        let speedMultiplier: Double
        let inputDeviceName: String
        let statusText: String
        let permissionDenied: Bool
        let fallbackToClassic: Bool
        let matchedRange: NSRange?
    }

    private struct ScriptWordToken {
        let normalized: String
        let range: NSRange
    }

    private struct ScriptMatch {
        let range: NSRange
        let endWordIndex: Int
        let wordCount: Int
    }

    @Published private(set) var runtimeState = RuntimeState(
        signalLevel: 0,
        isSpeechDetected: false,
        speedMultiplier: 1,
        inputDeviceName: "System default microphone",
        statusText: "Voice assist is off. Classic auto-scroll is active.",
        permissionDenied: false,
        fallbackToClassic: false,
        matchedRange: nil
    )

    private enum VoiceControllerError: Error {
        case noOnDeviceSpeechRecognizer
    }

    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasInstalledTap = false
    private var isStoppingCapture = false
    private var observers: [NSObjectProtocol] = []

    private var mode: PrompterModel.VoicePromptMode = .off
    private var sensitivity: Double = 0.55
    private var scriptText: String = ""
    private var scriptWords: [ScriptWordToken] = []
    private var lastMatchedWordIndex = 0
    private var lastTranscriptDigest = ""
    private var lastMatchPublishTime: CFAbsoluteTime = 0
    private var transcriptActivityDeadline: CFAbsoluteTime = 0
    private var playbackActive = false

    private var smoothedSignalLevel: Double = 0
    private var speechGateOpen = false
    private var speechOnAccumulated: TimeInterval = 0
    private var speechOffAccumulated: TimeInterval = 0
    private var currentMultiplier: Double = 1
    private var lastSampleTimestamp: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private var lastPublishedTimestamp: CFAbsoluteTime = 0

    private static let speechRiseDebounce: TimeInterval = 0.12
    private static let speechFallDebounce: TimeInterval = 0.36
    private static let meterPublishInterval: CFAbsoluteTime = 1.0 / 20.0
    private static let wordRegex = try! NSRegularExpression(pattern: "[\\p{L}\\p{N}']+")

    deinit {
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func updateConfiguration(
        mode: PrompterModel.VoicePromptMode,
        sensitivity: Double
    ) {
        self.mode = mode
        self.sensitivity = clamp(sensitivity, lower: PrompterModel.voiceSensitivityRange.lowerBound, upper: PrompterModel.voiceSensitivityRange.upperBound)

        if mode == .off {
            stopCapturePipeline(resetToClassicState: true)
            updateRuntimeState(
                signalLevel: 0,
                isSpeechDetected: false,
                speedMultiplier: 1,
                statusText: "Voice assist is off. Classic auto-scroll is active.",
                permissionDenied: false,
                fallbackToClassic: false,
                matchedRange: nil,
                force: true
            )
            return
        }

        guard playbackActive else {
            stopCapturePipeline(resetToClassicState: true)
            updateRuntimeState(
                signalLevel: 0,
                isSpeechDetected: false,
                speedMultiplier: 0,
                statusText: "Voice Hold is ready. Press Start to begin listening.",
                permissionDenied: false,
                fallbackToClassic: false,
                matchedRange: runtimeState.matchedRange,
                force: true
            )
            return
        }

        Task { [weak self] in
            await self?.ensureCaptureRunning(triggerReason: "Voice assist is active.")
        }
    }

    func setPlaybackActive(_ isActive: Bool) {
        guard playbackActive != isActive else { return }
        playbackActive = isActive

        if !isActive {
            stopCapturePipeline(resetToClassicState: true)
            updateRuntimeState(
                signalLevel: 0,
                isSpeechDetected: false,
                speedMultiplier: 0,
                statusText: "Voice Hold paused: listening resumes when playback starts.",
                permissionDenied: runtimeState.permissionDenied,
                fallbackToClassic: runtimeState.fallbackToClassic,
                matchedRange: runtimeState.matchedRange,
                force: true
            )
            return
        }

        if mode != .off {
            Task { [weak self] in
                await self?.ensureCaptureRunning(triggerReason: "Voice assist is listening.")
            }
        }
    }

    func refreshAuthorizationState() {
        guard mode != .off else { return }

        let microphoneAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let speechAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        guard microphoneAuthorized, speechAuthorized else {
            let message = "Voice assist fell back to classic mode because microphone or speech permission is unavailable."
            applyFallback(statusText: message, permissionDenied: true)
            stopCapturePipeline(resetToClassicState: false)
            return
        }

        Task { [weak self] in
            await self?.ensureCaptureRunning(triggerReason: "Voice permissions restored.")
        }
    }

    func shutdown() {
        stopCapturePipeline(resetToClassicState: false)
    }

    private func ensureCaptureRunning(triggerReason: String) async {
        guard mode != .off, playbackActive else { return }
        guard await requestPermissionsIfNeeded() else { return }

        do {
            try startCapturePipeline()
            updateRuntimeState(
                signalLevel: smoothedSignalLevel,
                isSpeechDetected: speechGateOpen,
                speedMultiplier: currentMultiplier,
                statusText: triggerReason,
                permissionDenied: false,
                fallbackToClassic: false,
                matchedRange: runtimeState.matchedRange,
                force: true
            )
        } catch {
            applyFallback(
                statusText: "Voice assist could not start with the current microphone setup. Classic auto-scroll remains active.",
                permissionDenied: false
            )
            stopCapturePipeline(resetToClassicState: false)
        }
    }

    func updateScript(_ script: String) {
        guard scriptText != script else { return }

        scriptText = script
        scriptWords = tokenizeScriptWords(script)
        lastTranscriptDigest = ""
        lastMatchedWordIndex = 0
        lastMatchPublishTime = 0
        transcriptActivityDeadline = 0

        if runtimeState.matchedRange != nil {
            updateRuntimeState(
                signalLevel: runtimeState.signalLevel,
                isSpeechDetected: runtimeState.isSpeechDetected,
                speedMultiplier: runtimeState.speedMultiplier,
                statusText: runtimeState.statusText,
                permissionDenied: runtimeState.permissionDenied,
                fallbackToClassic: runtimeState.fallbackToClassic,
                matchedRange: nil,
                force: true
            )
        }
    }

    private func requestPermissionsIfNeeded() async -> Bool {
        let microphoneGranted = await requestMicrophonePermissionIfNeeded()
        guard microphoneGranted else {
            applyFallback(
                statusText: "Microphone permission is required for voice assist. Classic auto-scroll is still available.",
                permissionDenied: true
            )
            return false
        }

        let speechGranted = await requestSpeechPermissionIfNeeded()
        guard speechGranted else {
            applyFallback(
                statusText: "Speech recognition permission is required for voice assist. Classic auto-scroll is still available.",
                permissionDenied: true
            )
            return false
        }

        guard let recognizer = makeOnDeviceSpeechRecognizer() else {
            applyFallback(
                statusText: "On-device speech recognition is unavailable for this locale. Classic auto-scroll remains active.",
                permissionDenied: false
            )
            return false
        }

        speechRecognizer = recognizer
        return true
    }

    private func requestMicrophonePermissionIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func requestSpeechPermissionIfNeeded() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func makeOnDeviceSpeechRecognizer() -> SFSpeechRecognizer? {
        let locales = [Locale.current, Locale(identifier: "en-US")]
        for locale in locales {
            guard let recognizer = SFSpeechRecognizer(locale: locale) else { continue }
            if recognizer.supportsOnDeviceRecognition {
                return recognizer
            }
        }
        return nil
    }

    private func startCapturePipeline() throws {
        guard let speechRecognizer else {
            throw VoiceControllerError.noOnDeviceSpeechRecognizer
        }

        installObserversIfNeeded()

        if audioEngine.isRunning {
            refreshInputDeviceName()
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true

        recognitionRequest = request
        recognitionTask?.cancel()
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                let transcript = result.bestTranscription.formattedString
                Task { @MainActor [weak self] in
                    self?.consumeTranscription(transcript, isFinal: result.isFinal)
                }
            }

            if let error {
                Task { @MainActor [weak self] in
                    self?.handleRecognitionError(error)
                }
            }
        }

        let inputNode = audioEngine.inputNode
        if hasInstalledTap {
            inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)

            let level = Self.normalizedSignalLevel(from: buffer)
            Task { @MainActor [weak self] in
                self?.consumeSignalSample(level)
            }
        }
        hasInstalledTap = true

        audioEngine.prepare()
        try audioEngine.start()
        resetDynamicsForActivation()
        refreshInputDeviceName()
    }

    private func stopCapturePipeline(resetToClassicState: Bool) {
        isStoppingCapture = true
        defer { isStoppingCapture = false }

        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        if resetToClassicState {
            resetDynamicsForActivation()
        }
    }

    private func handleRecognitionError(_ error: Error) {
        guard mode != .off, !isStoppingCapture else { return }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSUserCancelledError {
            return
        }

        applyFallback(
            statusText: "Speech pipeline was interrupted. PromptMe is using classic auto-scroll while reconnecting.",
            permissionDenied: false
        )
        restartCaptureAfterInterruption()
    }

    private func restartCaptureAfterInterruption() {
        guard mode != .off, playbackActive else { return }
        stopCapturePipeline(resetToClassicState: false)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            await self?.ensureCaptureRunning(triggerReason: "Voice assist reconnected.")
        }
    }

    private func consumeSignalSample(_ rawLevel: Double) {
        guard mode != .off, playbackActive else { return }

        let now = CFAbsoluteTimeGetCurrent()
        let deltaTime = max(0.001, min(now - lastSampleTimestamp, 0.25))
        lastSampleTimestamp = now

        let riseRate = 14.0
        let fallRate = 7.0
        let responseRate = rawLevel >= smoothedSignalLevel ? riseRate : fallRate
        smoothedSignalLevel += (rawLevel - smoothedSignalLevel) * min(1, responseRate * deltaTime)

        let threshold = vadThreshold(for: sensitivity)
        let upperGate = min(0.95, threshold + 0.04)
        let lowerGate = max(0.02, threshold - 0.04)

        if speechGateOpen {
            if smoothedSignalLevel <= lowerGate {
                speechOffAccumulated += deltaTime
                speechOnAccumulated = 0
                if speechOffAccumulated >= Self.speechFallDebounce {
                    speechGateOpen = false
                    speechOffAccumulated = 0
                }
            } else {
                speechOffAccumulated = 0
            }
        } else {
            if smoothedSignalLevel >= upperGate {
                speechOnAccumulated += deltaTime
                speechOffAccumulated = 0
                if speechOnAccumulated >= Self.speechRiseDebounce {
                    speechGateOpen = true
                    speechOnAccumulated = 0
                }
            } else {
                speechOnAccumulated = 0
            }
        }

        let hasRecentTranscriptActivity = now <= transcriptActivityDeadline
        let targetMultiplier = multiplierTarget(
            speaking: speechGateOpen,
            hasRecentTranscriptActivity: hasRecentTranscriptActivity
        )
        let multiplierRiseRate = 8.0
        let multiplierFallRate = 3.0
        let rate = targetMultiplier > currentMultiplier ? multiplierRiseRate : multiplierFallRate
        currentMultiplier += (targetMultiplier - currentMultiplier) * min(1, rate * deltaTime)
        currentMultiplier = clamp(currentMultiplier, lower: 0, upper: 1.5)

        updateRuntimeState(
            signalLevel: smoothedSignalLevel,
            isSpeechDetected: speechGateOpen,
            speedMultiplier: currentMultiplier,
            statusText: activeStatusText(),
            permissionDenied: false,
            fallbackToClassic: false,
            matchedRange: runtimeState.matchedRange
        )
    }

    private func consumeTranscription(_ transcript: String, isFinal: Bool) {
        guard mode != .off, playbackActive else { return }

        let words = transcriptWords(from: transcript)
        guard words.count >= 2 else { return }

        let transcriptDigest = words.joined(separator: " ")
        guard transcriptDigest != lastTranscriptDigest else { return }
        lastTranscriptDigest = transcriptDigest

        guard let match = findBestScriptMatch(for: words) else { return }

        let jumpDistance = abs(match.endWordIndex - lastMatchedWordIndex)
        let now = CFAbsoluteTimeGetCurrent()
        if !isFinal {
            if match.wordCount < 2 {
                return
            }
            if jumpDistance <= 1 {
                return
            }
            if jumpDistance > 170, match.wordCount < 5 {
                return
            }
            if (now - lastMatchPublishTime) < 0.14, match.wordCount < 3 {
                return
            }
        }

        lastMatchedWordIndex = match.endWordIndex
        lastMatchPublishTime = now
        transcriptActivityDeadline = now + 0.95

        guard runtimeState.matchedRange != match.range else { return }
        updateRuntimeState(
            signalLevel: runtimeState.signalLevel,
            isSpeechDetected: runtimeState.isSpeechDetected,
            speedMultiplier: runtimeState.speedMultiplier,
            statusText: activeStatusText(),
            permissionDenied: runtimeState.permissionDenied,
            fallbackToClassic: runtimeState.fallbackToClassic,
            matchedRange: match.range,
            force: true
        )
    }

    private func activeStatusText() -> String {
        switch mode {
        case .off:
            return "Voice assist is off. Classic auto-scroll is active."
        case .vad:
            return "Voice Hold mode: speaking advances, silence holds."
        }
    }

    private func multiplierTarget(speaking: Bool, hasRecentTranscriptActivity: Bool) -> Double {
        switch mode {
        case .off:
            return 1
        case .vad:
            let transcriptGate = hasRecentTranscriptActivity ? 1.0 : 0.0
            let voiceGate = speaking ? 1.0 : 0.0
            return min(transcriptGate, voiceGate)
        }
    }

    private func vadThreshold(for sensitivity: Double) -> Double {
        let clampedSensitivity = clamp(sensitivity, lower: 0, upper: 1)
        return clamp(0.30 - (clampedSensitivity * 0.22), lower: 0.06, upper: 0.34)
    }

    private func resetDynamicsForActivation() {
        smoothedSignalLevel = 0
        speechGateOpen = false
        speechOnAccumulated = 0
        speechOffAccumulated = 0
        currentMultiplier = 1
        lastSampleTimestamp = CFAbsoluteTimeGetCurrent()
    }

    private func applyFallback(statusText: String, permissionDenied: Bool) {
        resetDynamicsForActivation()
        updateRuntimeState(
            signalLevel: 0,
            isSpeechDetected: false,
            speedMultiplier: 1,
            statusText: statusText,
            permissionDenied: permissionDenied,
            fallbackToClassic: true,
            matchedRange: nil,
            force: true
        )
    }

    private func refreshInputDeviceName() {
        let currentName = AVCaptureDevice.default(for: .audio)?.localizedName ?? "System default microphone"
        if runtimeState.inputDeviceName != currentName {
            updateRuntimeState(
                signalLevel: runtimeState.signalLevel,
                isSpeechDetected: runtimeState.isSpeechDetected,
                speedMultiplier: runtimeState.speedMultiplier,
                statusText: runtimeState.statusText,
                permissionDenied: runtimeState.permissionDenied,
                fallbackToClassic: runtimeState.fallbackToClassic,
                matchedRange: runtimeState.matchedRange,
                inputDeviceName: currentName,
                force: true
            )
        }
    }

    private func installObserversIfNeeded() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default

        observers.append(
            center.addObserver(
                forName: .AVAudioEngineConfigurationChange,
                object: audioEngine,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.restartCaptureAfterInterruption()
                }
            }
        )

        observers.append(
            center.addObserver(
                forName: AVCaptureDevice.wasConnectedNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshInputDeviceName()
                    self?.restartCaptureAfterInterruption()
                }
            }
        )

        observers.append(
            center.addObserver(
                forName: AVCaptureDevice.wasDisconnectedNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshInputDeviceName()
                    self?.restartCaptureAfterInterruption()
                }
            }
        )
    }

    private func updateRuntimeState(
        signalLevel: Double,
        isSpeechDetected: Bool,
        speedMultiplier: Double,
        statusText: String,
        permissionDenied: Bool,
        fallbackToClassic: Bool,
        matchedRange: NSRange?,
        inputDeviceName: String? = nil,
        force: Bool = false
    ) {
        let next = RuntimeState(
            signalLevel: clamp(signalLevel, lower: 0, upper: 1),
            isSpeechDetected: isSpeechDetected,
            speedMultiplier: clamp(speedMultiplier, lower: 0, upper: 1.5),
            inputDeviceName: inputDeviceName ?? runtimeState.inputDeviceName,
            statusText: statusText,
            permissionDenied: permissionDenied,
            fallbackToClassic: fallbackToClassic,
            matchedRange: matchedRange
        )

        let now = CFAbsoluteTimeGetCurrent()
        let stateChangeRequiresImmediatePublish =
            next.isSpeechDetected != runtimeState.isSpeechDetected ||
            next.inputDeviceName != runtimeState.inputDeviceName ||
            next.statusText != runtimeState.statusText ||
            next.permissionDenied != runtimeState.permissionDenied ||
            next.fallbackToClassic != runtimeState.fallbackToClassic ||
            next.matchedRange != runtimeState.matchedRange

        let meterChanged =
            abs(next.signalLevel - runtimeState.signalLevel) > 0.012 ||
            abs(next.speedMultiplier - runtimeState.speedMultiplier) > 0.012

        let canPublishMeterTick = (now - lastPublishedTimestamp) >= Self.meterPublishInterval
        guard force || stateChangeRequiresImmediatePublish || (meterChanged && canPublishMeterTick) else {
            return
        }

        runtimeState = next
        lastPublishedTimestamp = now
    }

    private func tokenizeScriptWords(_ text: String) -> [ScriptWordToken] {
        let range = NSRange(location: 0, length: (text as NSString).length)
        return Self.wordRegex.matches(in: text, range: range).map {
            let token = (text as NSString).substring(with: $0.range)
            return ScriptWordToken(normalized: normalizeWord(token), range: $0.range)
        }
    }

    private func transcriptWords(from text: String) -> [String] {
        let range = NSRange(location: 0, length: (text as NSString).length)
        return Self.wordRegex.matches(in: text, range: range).map {
            normalizeWord((text as NSString).substring(with: $0.range))
        }
    }

    private func findBestScriptMatch(for transcriptWords: [String]) -> ScriptMatch? {
        guard !scriptWords.isEmpty, !transcriptWords.isEmpty else { return nil }

        let recentWords = Array(transcriptWords.suffix(7))
        guard !recentWords.isEmpty else { return nil }

        var best: (score: Int, start: Int, end: Int)?
        let maxWindow = min(6, recentWords.count)

        for windowSize in stride(from: maxWindow, through: 1, by: -1) {
            let phrase = Array(recentWords.suffix(windowSize))
            guard !phrase.isEmpty else { continue }
            let maxStart = scriptWords.count - phrase.count
            guard maxStart >= 0 else { continue }

            for start in 0...maxStart {
                var matched = true
                for index in 0..<phrase.count {
                    if scriptWords[start + index].normalized != phrase[index] {
                        matched = false
                        break
                    }
                }
                guard matched else { continue }

                let end = start + phrase.count - 1
                let proximityPenalty = abs(start - lastMatchedWordIndex) * 2
                let score = (phrase.count * 100) - proximityPenalty

                if let existing = best {
                    if score > existing.score {
                        best = (score, start, end)
                    }
                } else {
                    best = (score, start, end)
                }
            }

            if best != nil, windowSize >= 4 {
                break
            }
        }

        guard let best else { return nil }
        let startRange = scriptWords[best.start].range
        let endRange = scriptWords[best.end].range
        let mergedRange = NSRange(
            location: startRange.location,
            length: (endRange.location + endRange.length) - startRange.location
        )
        return ScriptMatch(range: mergedRange, endWordIndex: best.end, wordCount: (best.end - best.start) + 1)
    }

    private func normalizeWord(_ word: String) -> String {
        word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func normalizedSignalLevel(from buffer: AVAudioPCMBuffer) -> Double {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }

        if let channels = buffer.floatChannelData {
            let samples = channels[0]
            var sum: Float = 0
            var count = 0
            let strideStep = 2
            var i = 0
            while i < frameCount {
                let sample = samples[i]
                sum += sample * sample
                count += 1
                i += strideStep
            }

            guard count > 0 else { return 0 }
            let rms = sqrt(sum / Float(count))
            let db = 20 * log10(max(rms, 0.000_015))
            let normalized = (Double(db) + 55) / 55
            return max(0, min(normalized, 1))
        }

        if let channels = buffer.int16ChannelData {
            let samples = channels[0]
            var sum: Double = 0
            var count = 0
            let strideStep = 2
            var i = 0
            while i < frameCount {
                let sample = Double(samples[i]) / Double(Int16.max)
                sum += sample * sample
                count += 1
                i += strideStep
            }

            guard count > 0 else { return 0 }
            let rms = sqrt(sum / Double(count))
            let db = 20 * log10(max(rms, 0.000_015))
            let normalized = (db + 55) / 55
            return max(0, min(normalized, 1))
        }

        return 0
    }

    private func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
