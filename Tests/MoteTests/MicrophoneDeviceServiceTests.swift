import Testing
@testable import Mote

@MainActor
@Suite struct MicrophoneDeviceServiceTests {
    @Test func unavailableSelectedDeviceUsesDefaultWithoutChangingPreference() {
        let service = MicrophoneDeviceService(
            enumerator: StubMicrophoneDeviceEnumerator(
                devices: [.init(id: 1, name: "Built-in Mic")],
                defaultDeviceID: 1
            )
        )

        #expect(service.resolvedDeviceID(preferred: 99) == 1)
    }

    @Test func noAvailableDevicesProducesNoSelection() {
        let service = MicrophoneDeviceService(
            enumerator: StubMicrophoneDeviceEnumerator(devices: [], defaultDeviceID: nil)
        )

        #expect(service.devices.isEmpty)
        #expect(service.resolvedDeviceID(preferred: nil) == nil)
        #expect(service.statusMessage == "No microphone input devices found.")
    }

    @Test func meterLevelIsAlwaysClampedToTheAccessibleRange() {
        let service = MicrophoneDeviceService(
            enumerator: StubMicrophoneDeviceEnumerator(devices: [], defaultDeviceID: nil)
        )

        service.updateLevel(-0.2)
        #expect(service.level == 0)
        service.updateLevel(1.4)
        #expect(service.level == 1)
        service.updateLevel(0.42)
        #expect(service.level == 0.42)
        service.resetLevel()
        #expect(service.level == 0)
    }
}

private struct StubMicrophoneDeviceEnumerator: MicrophoneDeviceEnumerating {
    let devices: [MicrophoneDevice]
    let defaultDeviceID: UInt32?

    func inputDevices() -> [MicrophoneDevice] { devices }
    func defaultInputDeviceID() -> UInt32? { defaultDeviceID }
}
