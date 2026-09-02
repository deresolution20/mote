import Testing
@testable import Mote

@Suite struct MoteThemeTests {
    @Test func signalMarkMatchesTheProductGeometry() {
        #expect(MoteSignalMarkMetrics.widths == [6, 6, 6, 6, 6])
        #expect(MoteSignalMarkMetrics.heights == [40, 26, 22, 12, 10])
        #expect(MoteSignalMarkMetrics.cornerRadius == 3)
        #expect(MoteSignalMarkMetrics.pitch == 11)
    }

    @Test func motionTokensMatchTheInterfaceRhythm() {
        #expect(MoteTheme.Motion.fast == 0.12)
        #expect(MoteTheme.Motion.base == 0.20)
        #expect(MoteTheme.Motion.slow == 0.32)
    }
}
