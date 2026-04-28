import SwiftUI
import AppKit
import CoreGraphics

struct ContentView: View {
    private enum SettingsTab: Hashable {
        case prompts
        case playback
        case voice
        case settings
    }

    @ObservedObject private var model = PrompterModel.shared

    @State private var selectedTab: SettingsTab = .prompts
    @State private var selectedPromptID: UUID?
    @State private var promptSearchQuery: String = ""
    @State private var fileErrorMessage: String?

    private var isPlaybackLocked: Bool {
        model.isRunning || model.isCountingDown
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PromptMe Settings")
                    .font(.title3.weight(.semibold))
                Spacer(minLength: 0)
                if let activePrompt = model.activePrompt {
                    Text("Displayed: \(activePrompt.title)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            TabView(selection: $selectedTab) {
                promptsTab
                    .tabItem {
                        Label("Prompts", systemImage: "list.bullet.rectangle")
                    }
                    .tag(SettingsTab.prompts)

                playbackTab
                    .tabItem {
                        Label("Playback", systemImage: "play.circle")
                    }
                    .tag(SettingsTab.playback)

                voiceTab
                    .tabItem {
                        Label("Voice", systemImage: "waveform")
                    }
                    .tag(SettingsTab.voice)

                settingsTab
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(SettingsTab.settings)
            }
        }
        .frame(minWidth: 920, minHeight: 640)
        .onAppear {
            syncPromptSelection()
        }
        .onChange(of: model.prompts) { _, _ in
            syncPromptSelection()
        }
        .onChange(of: model.activePromptID) { _, _ in
            syncPromptSelection()
        }
        .alert("File Operation Failed", isPresented: Binding(
            get: { fileErrorMessage != nil },
            set: { _ in fileErrorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(fileErrorMessage ?? "This file operation could not be completed.")
        }
    }

    private var filteredPrompts: [PrompterModel.PromptEntry] {
        let query = promptSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return model.prompts
        }

        return model.prompts.filter { prompt in
            prompt.title.lowercased().contains(query) || prompt.text.lowercased().contains(query)
        }
    }

    private var selectedPrompt: PrompterModel.PromptEntry? {
        guard let selectedPromptID else { return nil }
        return model.prompt(withID: selectedPromptID)
    }

    private var promptsTab: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Prompt List")
                    .font(.headline)

                TextField("Search prompts", text: $promptSearchQuery)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isPlaybackLocked)

                if isPlaybackLocked {
                    Text("Prompt switching is disabled during playback to prevent rendering glitches.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                List(selection: $selectedPromptID) {
                    ForEach(filteredPrompts) { prompt in
                        PromptListRow(
                            title: prompt.title,
                            isActive: model.isActivePrompt(prompt.id)
                        )
                        .tag(prompt.id)
                    }
                }
                .listStyle(.inset)
                .disabled(isPlaybackLocked)

                HStack(spacing: 8) {
                    Button {
                        createPrompt()
                    } label: {
                        Label("New", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isPlaybackLocked)

                    Button {
                        duplicateSelectedPrompt()
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isPlaybackLocked || selectedPromptID == nil)

                    Button(role: .destructive) {
                        deleteSelectedPrompt()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isPlaybackLocked || selectedPromptID == nil || model.prompts.count <= 1)
                }
            }
            .padding(12)
            .frame(minWidth: 270, idealWidth: 300, maxWidth: 340)

            promptEditorPane
        }
    }

    @ViewBuilder
    private var promptEditorPane: some View {
        if let prompt = selectedPrompt {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if isPlaybackLocked {
                        Label("Pause playback to switch or edit prompts.", systemImage: "pause.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label(
                            model.isActivePrompt(prompt.id) ? "Currently Displayed" : "Not Displayed",
                            systemImage: model.isActivePrompt(prompt.id) ? "checkmark.circle.fill" : "circle"
                        )
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(model.isActivePrompt(prompt.id) ? Color.accentColor : .secondary)

                        Spacer(minLength: 0)

                        if !model.isActivePrompt(prompt.id) {
                            Button {
                                model.setActivePrompt(prompt.id)
                            } label: {
                                Label("Display This Prompt", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isPlaybackLocked)
                        }

                        Menu {
                            Button {
                                Task {
                                    await importPromptAsync(promptID: prompt.id)
                                }
                            } label: {
                                Label("Import Text...", systemImage: "arrow.down.doc")
                            }

                            Button {
                                Task {
                                    await exportPromptAsync(promptID: prompt.id)
                                }
                            } label: {
                                Label("Export Text...", systemImage: "arrow.up.doc")
                            }
                        } label: {
                            Label("File", systemImage: "ellipsis.circle")
                        }
                        .disabled(isPlaybackLocked)
                    }

                    SettingItem(
                        icon: "text.cursor",
                        title: "Prompt Title",
                        description: "Used in the list and quick selection."
                    ) {
                        TextField(
                            "Prompt title",
                            text: Binding(
                                get: { model.prompt(withID: prompt.id)?.title ?? "" },
                                set: { model.updatePromptTitle($0, for: prompt.id) }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .disabled(isPlaybackLocked)
                    }

                    SettingItem(
                        icon: "doc.plaintext",
                        title: "Prompt Text",
                        description: "This text appears in the overlay when displayed."
                    ) {
                        TextEditor(
                            text: Binding(
                                get: { model.prompt(withID: prompt.id)?.text ?? "" },
                                set: { model.updatePromptText($0, for: prompt.id) }
                            )
                        )
                        .font(.system(size: 13))
                        .frame(minHeight: 330)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                        .disabled(isPlaybackLocked)
                    }

                    HStack {
                        Spacer(minLength: 0)
                        Text("Estimated read time: \(model.formattedEstimatedReadDuration(for: prompt.text))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Select a prompt")
                    .font(.title3.weight(.semibold))
                Text("Pick a prompt from the list or create a new one.")
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var playbackTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SettingItem(
                    icon: "speedometer",
                    title: "Scroll Speed",
                    description: "Global scrolling speed used by all prompts."
                ) {
                    HStack(spacing: 10) {
                        Slider(value: $model.speedPointsPerSecond, in: PrompterModel.speedRange, step: PrompterModel.speedStep)
                            .disabled(model.voicePromptMode != .off)
                        Text("\(Int(model.speedPointsPerSecond))")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }

                    if model.voicePromptMode != .off {
                        Text("Disabled because Voice Hold controls speed automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                SettingItem(
                    icon: "repeat",
                    title: "Scroll Mode",
                    description: "Loop continuously or stop when reaching the end."
                ) {
                    Picker(
                        "Scroll mode",
                        selection: Binding(
                            get: { model.scrollMode },
                            set: { model.setScrollMode($0) }
                        )
                    ) {
                        Text("Infinite").tag(PrompterModel.ScrollMode.infinite)
                        Text("Stop at end").tag(PrompterModel.ScrollMode.stopAtEnd)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                SettingItem(
                    icon: "hand.point.up.left",
                    title: "Pause On Hover",
                    description: "Temporarily pauses scroll while your cursor is over overlay."
                ) {
                    Toggle("Pause on hover", isOn: $model.hoverPauseEnabled)
                        .disabled(model.voicePromptMode != .off)

                    if model.voicePromptMode != .off {
                        Text("Disabled because Pause on Hover is not supported in Voice Hold mode.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                SettingItem(
                    icon: "timer",
                    title: "Countdown Behavior",
                    description: "When to run countdown before playback starts."
                ) {
                    Picker("Countdown", selection: $model.countdownBehavior) {
                        ForEach(PrompterModel.CountdownBehavior.allCases, id: \.self) { behavior in
                            Text(behavior.label).tag(behavior)
                        }
                    }
                }

                SettingItem(
                    icon: "hourglass",
                    title: "Countdown Duration",
                    description: "Length of countdown in seconds."
                ) {
                    HStack(spacing: 10) {
                        Slider(
                            value: Binding(
                                get: { Double(model.countdownSeconds) },
                                set: { model.countdownSeconds = Int($0.rounded()) }
                            ),
                            in: 0...10,
                            step: 1
                        )
                        .disabled(model.countdownBehavior == .never)
                        Text("\(model.countdownSeconds)s")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }

                    if model.countdownBehavior == .never {
                        Text("Disabled because countdown behavior is set to Never.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
        }
    }

    private var voiceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SettingItem(
                    icon: "waveform",
                    title: "Voice Mode",
                    description: "Enable voice-assisted pacing or use classic mode."
                ) {
                    Picker("Mode", selection: $model.voicePromptMode) {
                        ForEach(PrompterModel.VoicePromptMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                SettingItem(
                    icon: "slider.horizontal.3",
                    title: "Sensitivity",
                    description: "How aggressively voice activity influences playback."
                ) {
                    HStack(spacing: 10) {
                        Slider(
                            value: $model.voiceSensitivity,
                            in: PrompterModel.voiceSensitivityRange,
                            step: 0.01
                        )
                        .disabled(model.voicePromptMode == .off)
                        Text("\(Int(model.voiceSensitivity * 100))%")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }

                    if model.voicePromptMode == .off {
                        Text("Disabled because Voice Mode is set to Classic.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                SettingItem(
                    icon: "mic",
                    title: "Input Source",
                    description: "Current microphone used by voice detection."
                ) {
                    Text(model.voiceInputDeviceName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                SettingItem(
                    icon: "waveform.path.ecg",
                    title: "Signal Meter",
                    description: "Live input level from your microphone."
                ) {
                    HStack {
                        VoiceMeterBar(level: model.voiceSignalLevel, isSpeaking: model.isVoiceSpeechDetected)
                            .frame(height: 10)
                        Text(model.isVoiceSpeechDetected ? "Speaking" : "Silent")
                            .font(.caption)
                            .foregroundStyle(model.isVoiceSpeechDetected ? Color.accentColor : .secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                }

                if model.voicePromptMode != .off {
                    SettingItem(
                        icon: "info.circle",
                        title: "Voice Status",
                        description: "Current recognition state and fallback behavior."
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(model.voiceStatusText)
                                .font(.footnote)
                                .foregroundStyle(model.voicePermissionDenied ? .red : .secondary)

                            if model.voicePermissionDenied {
                                Button("Open Voice Privacy Settings") {
                                    AppDelegate.shared?.openVoicePrivacySettings()
                                }
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    private var settingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SettingItem(
                    icon: "textformat.size",
                    title: "Font Size",
                    description: "Text size used in overlay prompting."
                ) {
                    HStack(spacing: 10) {
                        Slider(value: $model.fontSize, in: 12...40, step: 1)
                        Text("\(Int(model.fontSize))")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                }

                SettingItem(
                    icon: "rectangle.compress.vertical",
                    title: "Overlay Height",
                    description: "Height of the notch overlay area."
                ) {
                    HStack(spacing: 10) {
                        Slider(value: $model.overlayHeight, in: 120...420, step: 2)
                        Text("\(Int(model.overlayHeight))")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                }

                SettingItem(
                    icon: "display",
                    title: "Display Target",
                    description: "Monitor where the overlay should appear."
                ) {
                    Picker("Show overlay on", selection: $model.selectedScreenID) {
                        Text("Auto (Built-in)").tag(CGDirectDisplayID(0))
                        ForEach(NSScreen.screens, id: \.self) { screen in
                            Text(screen.localizedName).tag(screenID(for: screen))
                        }
                    }
                    .labelsHidden()
                }

                SettingItem(
                    icon: "rectangle.on.rectangle",
                    title: "Overlay Visibility",
                    description: "Show or hide the PromptMe overlay window."
                ) {
                    Toggle("Show overlay", isOn: $model.isOverlayVisible)
                }

                SettingItem(
                    icon: "lock.shield",
                    title: "Capture Privacy",
                    description: "Limit overlay capture during screen sharing when possible."
                ) {
                    Toggle("Limit screen sharing capture", isOn: $model.privacyModeEnabled)
                }
            }
            .padding(12)
        }
    }

    private func screenID(for screen: NSScreen) -> CGDirectDisplayID {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return 0
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private func createPrompt() {
        guard !isPlaybackLocked else { return }
        let newID = model.createPrompt(text: "")
        selectedPromptID = newID
    }

    private func duplicateSelectedPrompt() {
        guard !isPlaybackLocked else { return }
        guard let selectedPromptID else { return }
        if let duplicateID = model.duplicatePrompt(id: selectedPromptID) {
            self.selectedPromptID = duplicateID
        }
    }

    private func deleteSelectedPrompt() {
        guard !isPlaybackLocked else { return }
        guard let selectedPromptID else { return }
        let nextID = model.deletePrompt(id: selectedPromptID)
        self.selectedPromptID = nextID
    }

    private func syncPromptSelection() {
        if let selectedPromptID,
           model.prompt(withID: selectedPromptID) != nil {
            return
        }
        selectedPromptID = model.activePromptID
    }

    @MainActor
    private func importPromptAsync(promptID: UUID) async {
        guard !isPlaybackLocked else { return }
        guard model.prompt(withID: promptID) != nil else { return }
        let url = await FilePanelCoordinator.presentImportPanel(from: NSApp.keyWindow)
        guard let url else { return }

        do {
            let importedText = try await ScriptFileIO.importText(from: url)
            model.updatePromptText(importedText, for: promptID)
        } catch {
            fileErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func exportPromptAsync(promptID: UUID) async {
        guard !isPlaybackLocked else { return }
        guard let prompt = model.prompt(withID: promptID) else { return }
        let url = await FilePanelCoordinator.presentExportPanel(from: NSApp.keyWindow)
        guard let url else { return }

        do {
            try await ScriptFileIO.exportText(prompt.text, to: url)
        } catch {
            fileErrorMessage = error.localizedDescription
        }
    }
}

private struct PromptListRow: View {
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
            Text(title)
                .lineLimit(1)
        }
    }
}

private struct SettingItem<Content: View>: View {
    let icon: String
    let title: String
    let description: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            content()
                .padding(.leading, 28)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct VoiceMeterBar: View {
    let level: Double
    let isSpeaking: Bool

    var body: some View {
        GeometryReader { proxy in
            let clampedLevel = max(0, min(level, 1))
            let activeColor: Color = isSpeaking ? Color.accentColor : .secondary

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(nsColor: .separatorColor))
                Capsule()
                    .fill(activeColor)
                    .frame(width: max(4, proxy.size.width * clampedLevel))
            }
        }
        .animation(.easeOut(duration: 0.12), value: level)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 980, height: 660)
    }
}
#endif