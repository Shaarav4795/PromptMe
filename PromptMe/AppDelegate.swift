import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    static weak var shared: AppDelegate?

    private let model = PrompterModel.shared
    private let voiceController = VoicePromptingController()

    private var statusItem: NSStatusItem?
    private var overlayController: OverlayWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var cancellables: Set<AnyCancellable> = []

    private var startPauseItem: NSMenuItem?
    private var showOverlayItem: NSMenuItem?
    private var privacyModeItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        model.loadFromDefaults()
        overlayController = OverlayWindowController(model: model)
        overlayController?.setVisible(model.isOverlayVisible)

#if DEBUG
        ScreenSelectionSelfTests.run()
#endif

        setupEditMenu()
        wireModel()
        voiceController.updateConfiguration(
            mode: model.voicePromptMode,
            sensitivity: model.voiceSensitivity
        )
        setupStatusBar()
        installEditKeyHandler()
    }

    func applicationWillTerminate(_ notification: Notification) {
        voiceController.shutdown()
        model.saveToDefaults()
        cancellables.removeAll()
    }

    private func wireModel() {
        voiceController.$runtimeState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.model.applyVoiceRuntimeState(state)
            }
            .store(in: &cancellables)

        model.$script
            .receive(on: RunLoop.main)
            .sink { [weak self] script in
                self?.voiceController.updateScript(script)
            }
            .store(in: &cancellables)

        model.$isRunning
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isRunning in
                self?.voiceController.setPlaybackActive(isRunning)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(
            model.$voicePromptMode.removeDuplicates(),
            model.$voiceSensitivity.removeDuplicates()
        )
        .dropFirst()
        .receive(on: RunLoop.main)
        .sink { [weak self] mode, sensitivity in
            self?.voiceController.updateConfiguration(
                mode: mode,
                sensitivity: sensitivity
            )
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.voiceController.refreshAuthorizationState()
            }
            .store(in: &cancellables)

        model.$privacyModeEnabled
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.overlayController?.setPrivacyMode(enabled)
            }
            .store(in: &cancellables)

        model.$isOverlayVisible
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isVisible in
                self?.overlayController?.setVisible(isVisible)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(model.$overlayWidth, model.$overlayHeight)
            .dropFirst()
            .removeDuplicates { lhs, rhs in
                Int(lhs.0) == Int(rhs.0) && Int(lhs.1) == Int(rhs.1)
            }
            .throttle(for: .milliseconds(16), scheduler: RunLoop.main, latest: true)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.overlayController?.reposition()
            }
            .store(in: &cancellables)

        model.$selectedScreenID
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.overlayController?.reposition()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(120), scheduler: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
#if DEBUG
                print("[PromptMe] didChangeScreenParametersNotification")
#endif
                self?.overlayController?.reposition()
            }
            .store(in: &cancellables)

        let scriptAutosave = model.$script
            .dropFirst()
            .map { _ in () }
            .debounce(for: .milliseconds(550), scheduler: RunLoop.main)
            .eraseToAnyPublisher()

        let settingsAutosave = Publishers.MergeMany(
            model.$isOverlayVisible
                .dropFirst()
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            model.$privacyModeEnabled
                .dropFirst()
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            model.$hoverPauseEnabled
                .dropFirst()
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            model.$speedPointsPerSecond
                .dropFirst()
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            model.$fontSize
                .dropFirst()
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            model.$overlayHeight
                .dropFirst()
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            model.$countdownSeconds
                .dropFirst()
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            model.$countdownBehavior
                .dropFirst()
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            model.$scrollMode
                .dropFirst()
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            model.$voicePromptMode
                .dropFirst()
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            model.$voiceSensitivity
                .dropFirst()
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            model.$selectedScreenID
                .dropFirst()
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            model.$promptLibraryRevision
                .dropFirst()
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
        .eraseToAnyPublisher()

        Publishers.Merge(scriptAutosave, settingsAutosave)
        .sink { [weak self] in
            self?.model.saveToDefaults()
        }
        .store(in: &cancellables)
    }

    private func setupEditMenu() {
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu

        if let mainMenu = NSApp.mainMenu {
            mainMenu.addItem(editMenuItem)
        } else {
            let mainMenu = NSMenu()
            mainMenu.addItem(editMenuItem)
            NSApp.mainMenu = mainMenu
        }
    }

    private func setupStatusBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "PM"
        item.button?.toolTip = "PromptMe"

        let menu = NSMenu()

        let startPause = NSMenuItem(
            title: "Start/Pause",
            action: #selector(toggleRunning),
            keyEquivalent: ""
        )
        startPause.target = self
        menu.addItem(startPause)
        startPauseItem = startPause

        let reset = NSMenuItem(
            title: "Reset Scroll",
            action: #selector(resetScroll),
            keyEquivalent: ""
        )
        reset.target = self
        menu.addItem(reset)

        let jumpBack = NSMenuItem(
            title: "Jump Back 5s",
            action: #selector(jumpBack),
            keyEquivalent: ""
        )
        jumpBack.target = self
        menu.addItem(jumpBack)

        let privacyMode = NSMenuItem(
            title: "Privacy Mode",
            action: #selector(togglePrivacyMode),
            keyEquivalent: ""
        )
        privacyMode.target = self
        menu.addItem(privacyMode)
        privacyModeItem = privacyMode

        let showOverlay = NSMenuItem(
            title: "Show Overlay",
            action: #selector(toggleOverlayVisibility),
            keyEquivalent: ""
        )
        showOverlay.target = self
        menu.addItem(showOverlay)
        showOverlayItem = showOverlay

        let speedUp = NSMenuItem(
            title: "Increase Speed",
            action: #selector(increaseSpeed),
            keyEquivalent: ""
        )
        speedUp.target = self
        menu.addItem(speedUp)

        let speedDown = NSMenuItem(
            title: "Decrease Speed",
            action: #selector(decreaseSpeed),
            keyEquivalent: ""
        )
        speedDown.target = self
        menu.addItem(speedDown)

        menu.addItem(.separator())

        let open = NSMenuItem(title: "Settings…", action: #selector(openMainWindow), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit PromptMe", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        quit.keyEquivalentModifierMask = [.command]
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    // MARK: - Edit key handler (Cmd+C/V/X/A/Z bypass for menu-bar apps)

    private func installEditKeyHandler() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command ||
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command, .shift] else {
                return event
            }
            let key = event.charactersIgnoringModifiers ?? ""
            let action: Selector? = switch key {
            case "x": #selector(NSText.cut(_:))
            case "c": #selector(NSText.copy(_:))
            case "v": #selector(NSText.paste(_:))
            case "a": #selector(NSText.selectAll(_:))
            case "z" where event.modifierFlags.contains(.shift): NSSelectorFromString("redo:")
            case "z": NSSelectorFromString("undo:")
            default: nil
            }
            if let action, NSApp.sendAction(action, to: nil, from: nil) {
                return nil
            }
            return event
        }
    }

    // MARK: - Actions

    @objc private func toggleRunning() {
        model.toggleRunning()
    }

    @objc private func resetScroll() {
        model.resetScroll()
    }

    @objc private func jumpBack() {
        model.jumpBack(seconds: 5)
    }

    @objc private func togglePrivacyMode() {
        model.privacyModeEnabled.toggle()
    }

    @objc private func toggleOverlayVisibility() {
        model.isOverlayVisible.toggle()
    }

    @objc private func increaseSpeed() {
        model.adjustSpeed(delta: PrompterModel.speedStep)
    }

    @objc private func decreaseSpeed() {
        model.adjustSpeed(delta: -PrompterModel.speedStep)
    }

    @objc func openMainWindow() {
        Task { @MainActor in
            if settingsWindowController == nil {
                settingsWindowController = SettingsWindowController()
            }
            settingsWindowController?.show()
        }
    }

    @objc func openVoicePrivacySettings() {
        let privacyURLs = [
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"),
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
        ]

        for candidate in privacyURLs {
            guard let candidate else { continue }
            if NSWorkspace.shared.open(candidate) {
                return
            }
        }

        if let genericPrivacy = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            _ = NSWorkspace.shared.open(genericPrivacy)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Menu Validation

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem === startPauseItem {
            menuItem.title = model.isRunning ? "Pause" : "Start"
            return true
        }

        if menuItem === privacyModeItem {
            menuItem.state = model.privacyModeEnabled ? .on : .off
            return true
        }

        if menuItem === showOverlayItem {
            menuItem.state = model.isOverlayVisible ? .on : .off
            return true
        }

        return true
    }
}
