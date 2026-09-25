import Combine
import CoreAudio
import Foundation

struct MicrophoneDevice: Identifiable, Equatable {
    let id: UInt32
    let name: String
}

protocol MicrophoneDeviceEnumerating {
    func inputDevices() -> [MicrophoneDevice]
    func defaultInputDeviceID() -> UInt32?
}

struct SystemMicrophoneDeviceEnumerator: MicrophoneDeviceEnumerating {
    func inputDevices() -> [MicrophoneDevice] {
        allDeviceIDs().compactMap { deviceID in
            guard hasInputChannels(deviceID) else { return nil }
            return MicrophoneDevice(id: deviceID, name: deviceName(for: deviceID))
        }
    }

    func defaultInputDeviceID() -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else {
            return []
        }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }
        var deviceIDs = [AudioDeviceID](repeating: kAudioObjectUnknown, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceIDs
        ) == noErr else {
            return []
        }
        return deviceIDs
    }

    private func hasInputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr,
              size >= UInt32(MemoryLayout<AudioBufferList>.size)
        else {
            return false
        }

        let bufferList = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { bufferList.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, bufferList) == noErr else {
            return false
        }
        return bufferList.assumingMemoryBound(to: AudioBufferList.self).pointee.mNumberBuffers > 0
    }

    private func deviceName(for deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name) == noErr else {
            return "Microphone \(deviceID)"
        }
        return name?.takeUnretainedValue() as String? ?? "Microphone \(deviceID)"
    }
}

@MainActor
final class MicrophoneDeviceService: ObservableObject {
    @Published private(set) var devices: [MicrophoneDevice] = []
    @Published private(set) var level: Double = 0

    private let enumerator: any MicrophoneDeviceEnumerating

    init(enumerator: any MicrophoneDeviceEnumerating = SystemMicrophoneDeviceEnumerator()) {
        self.enumerator = enumerator
        refresh()
    }

    var statusMessage: String {
        devices.isEmpty ? "No microphone input devices found." : ""
    }

    func refresh() {
        devices = enumerator.inputDevices()
    }

    func resolvedDeviceID(preferred: UInt32?) -> UInt32? {
        if let preferred, devices.contains(where: { $0.id == preferred }) {
            return preferred
        }
        if let defaultID = enumerator.defaultInputDeviceID(), devices.contains(where: { $0.id == defaultID }) {
            return defaultID
        }
        return devices.first?.id
    }

    func updateLevel(_ value: Double) {
        level = min(max(value, 0), 1)
    }

    func resetLevel() {
        level = 0
    }
}
