import AppKit
import Combine

@MainActor
final class StatusItemManager: NSObject {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private let onQuit: () -> Void
    private var cancellables = Set<AnyCancellable>()

    // Menu items we need to update dynamically
    private let statusMenuItem = NSMenuItem()
    private let pauseMenuItem = NSMenuItem()
    private let permissionMenuItem = NSMenuItem()

    init(appState: AppState, onQuit: @escaping () -> Void) {
        self.appState = appState
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        super.init()

        buildMenu()
        updateIcon(isPaused: false, isDucked: false, hasAccessibility: false)

        // Observe state changes to update icon and menu items
        Publishers.CombineLatest3(
            appState.$isPaused,
            appState.$isDucked,
            appState.$hasAccessibility
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isPaused, isDucked, hasAccessibility in
            self?.updateIcon(isPaused: isPaused, isDucked: isDucked, hasAccessibility: hasAccessibility)
            self?.updateMenuItems(isPaused: isPaused, isDucked: isDucked, hasAccessibility: hasAccessibility)
        }
        .store(in: &cancellables)
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        // Status line (disabled item, just for display)
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        // Permission item (hidden when not needed)
        permissionMenuItem.title = "Open System Settings..."
        permissionMenuItem.image = NSImage(systemSymbolName: "lock.open", accessibilityDescription: nil)
        permissionMenuItem.target = self
        permissionMenuItem.action = #selector(openAccessibilitySettings)
        permissionMenuItem.isHidden = true
        menu.addItem(permissionMenuItem)

        // Pause/Resume
        pauseMenuItem.target = self
        pauseMenuItem.action = #selector(togglePause)
        pauseMenuItem.image = NSImage(systemSymbolName: "pause.circle", accessibilityDescription: nil)
        menu.addItem(pauseMenuItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem()
        quitItem.title = "Quit HushDuck"
        quitItem.image = NSImage(systemSymbolName: "xmark.square", accessibilityDescription: nil)
        quitItem.keyEquivalent = "q"
        quitItem.target = self
        quitItem.action = #selector(quitApp)
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func togglePause() {
        appState.isPaused.toggle()
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quitApp() {
        onQuit()
    }

    // MARK: - Updates

    private func updateMenuItems(isPaused: Bool, isDucked: Bool, hasAccessibility: Bool) {
        // Status line
        let statusDot: String
        let statusText: String
        if !hasAccessibility {
            statusDot = "\u{1F7E0}" // orange circle
            statusText = "Needs Permission"
        } else if isPaused {
            statusDot = "\u{1F7E1}" // yellow circle
            statusText = "Paused"
        } else if isDucked {
            statusDot = "\u{1F534}" // red circle
            statusText = "Ducking"
        } else {
            statusDot = "\u{1F7E2}" // green circle
            statusText = "Normal"
        }
        statusMenuItem.title = "\(statusDot)  \(statusText)"

        // Permission item visibility
        permissionMenuItem.isHidden = hasAccessibility

        // Pause item
        if isPaused {
            pauseMenuItem.title = "Resume Monitoring"
            pauseMenuItem.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: nil)
        } else {
            pauseMenuItem.title = "Pause Monitoring"
            pauseMenuItem.image = NSImage(systemSymbolName: "pause.circle", accessibilityDescription: nil)
        }
        pauseMenuItem.isEnabled = hasAccessibility
    }

    private func updateIcon(isPaused: Bool, isDucked: Bool, hasAccessibility: Bool) {
        let symbolName: String
        if !hasAccessibility {
            symbolName = "waveform.badge.exclamationmark"
        } else if isPaused {
            symbolName = "waveform.slash"
        } else if isDucked {
            symbolName = "waveform.path.ecg"
        } else {
            symbolName = "waveform"
        }

        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: "HushDuck"
            )
            image?.isTemplate = true
            button.image = image
        }
    }
}
