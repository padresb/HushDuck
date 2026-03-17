import ApplicationServices
import Foundation

enum PermissionManager {
    /// Check if accessibility is granted (non-prompting).
    static func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Check and prompt if needed (shows system dialog directing user to Settings).
    @discardableResult
    static func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
