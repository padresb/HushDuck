import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private let audioController = AudioController()
    private let fnKeyMonitor = FnKeyMonitor()
    private var statusItemManager: StatusItemManager!
    private var permissionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from dock (agent app behavior without Info.plist)
        NSApp.setActivationPolicy(.accessory)

        // Crash recovery: unmute if previous session crashed while ducked
        if CrashRecovery.wasDuckedOnLastExit {
            audioController.forceUnmute()
            CrashRecovery.markUnducked()
        }

        // Set up menu bar
        statusItemManager = StatusItemManager(appState: appState) { [weak self] in
            self?.quit()
        }

        // Wire up Fn key callbacks
        fnKeyMonitor.onFnDown = { [weak self] in
            DispatchQueue.main.async { self?.handleFnDown() }
        }
        fnKeyMonitor.onFnUp = { [weak self] in
            DispatchQueue.main.async { self?.handleFnUp() }
        }

        // Listen for pause/resume state changes
        appState.$isPaused
            .dropFirst()
            .sink { [weak self] isPaused in
                self?.handlePauseChanged(isPaused)
            }
            .store(in: &cancellables)

        // Start device change listener
        audioController.startDeviceChangeListener { [weak self] in
            self?.audioController.handleDeviceChange()
        }

        // Watch for sleep to unduck
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )

        // Check accessibility and start monitoring
        checkAccessibilityAndStart()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Safety: unmute if currently ducked
        if appState.isDucked {
            audioController.unduck()
            CrashRecovery.markUnducked()
        }
        fnKeyMonitor.stop()
        audioController.stopDeviceChangeListener()
    }

    // MARK: - Fn Key Handling

    private func handleFnDown() {
        guard !appState.isPaused else { return }
        if audioController.duck() {
            appState.isDucked = true
            appState.isFnHeld = true
            CrashRecovery.markDucked()
        }
    }

    private func handleFnUp() {
        appState.isFnHeld = false
        guard appState.isDucked else { return }
        audioController.unduck()
        appState.isDucked = false
        CrashRecovery.markUnducked()
    }

    // MARK: - Pause

    private func handlePauseChanged(_ isPaused: Bool) {
        if isPaused {
            // If currently ducked, unduck first
            if appState.isDucked {
                audioController.unduck()
                appState.isDucked = false
                CrashRecovery.markUnducked()
            }
            fnKeyMonitor.pause()
        } else {
            fnKeyMonitor.resume()
        }
    }

    // MARK: - Sleep

    @objc private func handleSleep() {
        if appState.isDucked {
            audioController.unduck()
            appState.isDucked = false
            CrashRecovery.markUnducked()
        }
    }

    // MARK: - Accessibility

    private func checkAccessibilityAndStart() {
        if PermissionManager.isAccessibilityGranted() {
            appState.hasAccessibility = true
            startMonitoring()
        } else {
            PermissionManager.requestAccessibility()
            startPermissionPolling()
        }
    }

    private func startMonitoring() {
        let success = fnKeyMonitor.start()
        if !success {
            // Event tap creation failed — permissions may have been revoked
            appState.hasAccessibility = false
            startPermissionPolling()
        }
    }

    private func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if PermissionManager.isAccessibilityGranted() {
                    self.permissionTimer?.invalidate()
                    self.permissionTimer = nil
                    self.appState.hasAccessibility = true
                    self.startMonitoring()
                }
            }
        }
    }

    // MARK: - Quit

    private func quit() {
        NSApp.terminate(nil)
    }
}
