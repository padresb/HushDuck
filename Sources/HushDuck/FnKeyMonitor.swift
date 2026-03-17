import CoreGraphics
import Foundation

final class FnKeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var wasFnPressed: Bool = false

    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?

    var isRunning: Bool {
        eventTap != nil
    }

    /// Start monitoring Fn key. Returns false if the event tap could not be created
    /// (typically because Accessibility permissions are not granted).
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: fnKeyEventCallback,
            userInfo: userInfo
        ) else {
            return false
        }

        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        wasFnPressed = false
    }

    func pause() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }

    func resume() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    /// Called from the C callback to process a flags-changed event.
    fileprivate func handleFlagsChanged(_ flags: CGEventFlags) {
        let fnNowPressed = flags.contains(.maskSecondaryFn)

        if fnNowPressed && !wasFnPressed {
            onFnDown?()
        } else if !fnNowPressed && wasFnPressed {
            onFnUp?()
        }

        wasFnPressed = fnNowPressed
    }

    /// Called when the system disables the tap due to timeout.
    fileprivate func reEnableTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
}

// MARK: - C Callback

/// Must be a free function (not a closure) for CGEvent.tapCreate.
private func fnKeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()

    switch type {
    case .flagsChanged:
        monitor.handleFlagsChanged(event.flags)

    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        monitor.reEnableTap()

    default:
        break
    }

    return Unmanaged.passUnretained(event)
}
