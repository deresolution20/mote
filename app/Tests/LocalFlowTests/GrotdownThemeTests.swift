import Testing
@testable import LocalFlow

@Suite struct GrotdownThemeTests {
    @Test func signalMarkMatchesTheProductGeometry() {
        #expect(GrotdownSignalMarkMetrics.widths == [6, 6, 6, 6, 6])
        #expect(GrotdownSignalMarkMetrics.heights == [40, 26, 22, 12, 10])
        #expect(GrotdownSignalMarkMetrics.cornerRadius == 3)
        #expect(GrotdownSignalMarkMetrics.pitch == 11)
    }

    @Test func motionTokensMatchTheInterfaceRhythm() {
        #expect(GrotdownTheme.Motion.fast == 0.12)
        #expect(GrotdownTheme.Motion.base == 0.20)
        #expect(GrotdownTheme.Motion.slow == 0.32)
    }
}
