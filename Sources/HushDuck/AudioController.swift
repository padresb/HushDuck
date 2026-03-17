import CoreAudio
import Foundation

final class AudioController {
    /// Whether we are the ones who muted the audio (vs user had it muted already)
    private var didDuck: Bool = false

    /// Listener block reference for device change notifications
    private var deviceChangeListenerBlock: AudioObjectPropertyListenerBlock?
    private var deviceChangeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    // MARK: - Default Output Device

    func getDefaultOutputDevice() -> AudioObjectID? {
        var deviceID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    // MARK: - Mute State

    func isMuted() -> Bool? {
        guard let deviceID = getDefaultOutputDevice() else { return nil }
        return isMuted(device: deviceID)
    }

    func isMuted(device deviceID: AudioObjectID) -> Bool? {
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &muted)
        guard status == noErr else { return nil }
        return muted == 1
    }

    @discardableResult
    func setMute(_ muted: Bool) -> Bool {
        guard let deviceID = getDefaultOutputDevice() else { return false }
        return setMute(muted, device: deviceID)
    }

    @discardableResult
    func setMute(_ muted: Bool, device deviceID: AudioObjectID) -> Bool {
        var value: UInt32 = muted ? 1 : 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            deviceID, &address, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &value
        )
        return status == noErr
    }

    // MARK: - Duck / Unduck

    /// Mute the system audio. Returns true if we actually changed the mute state.
    func duck() -> Bool {
        guard let alreadyMuted = isMuted() else { return false }
        if alreadyMuted {
            didDuck = false
            return false
        }
        let success = setMute(true)
        didDuck = success
        return success
    }

    /// Unmute the system audio, but only if we were the ones who muted it.
    func unduck() {
        guard didDuck else { return }
        setMute(false)
        didDuck = false
    }

    /// Force unmute regardless of who muted it (used for crash recovery).
    func forceUnmute() {
        setMute(false)
        didDuck = false
    }

    // MARK: - Device Change Listener

    func startDeviceChangeListener(onDeviceChanged: @escaping () -> Void) {
        let block: AudioObjectPropertyListenerBlock = { _, _ in
            onDeviceChanged()
        }
        deviceChangeListenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &deviceChangeAddress,
            DispatchQueue.main,
            block
        )
    }

    func stopDeviceChangeListener() {
        guard let block = deviceChangeListenerBlock else { return }
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &deviceChangeAddress,
            DispatchQueue.main,
            block
        )
        deviceChangeListenerBlock = nil
    }

    /// Called when the default device changes while we are ducked.
    func handleDeviceChange() {
        if didDuck {
            // Mute the new default device too
            setMute(true)
        }
    }

    deinit {
        stopDeviceChangeListener()
    }
}
