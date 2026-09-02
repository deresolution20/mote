import AppKit
import SwiftUI

/// Pipeline phase the HUD reflects.
enum HUDPhase: Equatable {
    case recording
    case transcribing
    case cleaning
    case done
}

@MainActor
final class HUDModel: ObservableObject {
    @Published var phase: HUDPhase = .recording
    @Published var captionTail: String = ""
}

/// A floating, non-activating overlay that shows an animated waveform pill while
/// dictation runs. CRITICAL: the panel never becomes key and ignores the mouse,
/// so the frontmost app (the paste target) never changes.
@MainActor
final class HUDController {
    static let shared = HUDController()

    private var panel: NSPanel?
    private let model = HUDModel()
    /// Guards the delayed hide so a new dictation cancels a pending fade.
    private var hideGeneration = 0

    private static let size = CGSize(width: 336, height: 64)

    var enabled: Bool {
        UserDefaults.standard.object(forKey: "mote.hudEnabled") as? Bool ?? true
    }

    func show(_ phase: HUDPhase, captionTail: String = "") {
        guard enabled else { return }
        hideGeneration += 1
        model.phase = phase
        model.captionTail = captionTail
        let panel = panel ?? makePanel()
        reposition(panel)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    func updateCaptionTail(_ captionTail: String) {
        guard enabled, panel != nil else { return }
        model.captionTail = captionTail
    }

    /// Flash the done state, then fade out — unless a new dictation supersedes it.
    func finishAndHide() {
        guard enabled, panel != nil else { return }
        model.phase = .done
        model.captionTail = ""
        hideGeneration += 1
        let token = hideGeneration
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard token == hideGeneration else { return }
            fadeOut()
        }
    }

    func hide() {
        hideGeneration += 1
        model.captionTail = ""
        panel?.orderOut(nil)
    }

    private func fadeOut() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 0
        } completionHandler: { [weak panel] in
            panel?.orderOut(nil)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: MoteHUDView(model: model))
        self.panel = panel
        return panel
    }

    private func reposition(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame // excludes Dock + menu bar
        let origin = CGPoint(x: vf.midX - Self.size.width / 2, y: vf.minY + 28)
        panel.setFrame(CGRect(origin: origin, size: Self.size), display: true)
    }
}

// MARK: - Views

struct MoteHUDView: View {
    @ObservedObject var model: HUDModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            switch model.phase {
            case .recording:
                recordingIndicator
                captionText
            case .transcribing:
                WaveBars(animating: !reduceMotion, tint: MoteTheme.Colors.secondaryText)
                captionTextOrFallback("Transcribing")
            case .cleaning:
                Image(systemName: "sparkles")
                    .foregroundStyle(MoteTheme.Colors.signalStart)
                captionTextOrFallback("Cleaning up")
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MoteTheme.Colors.success)
                Text("Saved")
                    .font(MoteTheme.Typography.body(12))
                    .foregroundStyle(MoteTheme.Colors.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MoteTheme.Colors.raised, in: Capsule())
        .overlay(Capsule().strokeBorder(MoteTheme.Colors.border))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        .padding(6)
        .animation(.easeInOut(duration: MoteTheme.Motion.base), value: model.phase)
        .animation(
            StreamingHUDLatencyTuning.captionAnimationDuration == 0
                ? nil
                : .easeInOut(duration: StreamingHUDLatencyTuning.captionAnimationDuration),
            value: model.captionTail
        )
    }

    @ViewBuilder
    private var recordingIndicator: some View {
        if reduceMotion {
            Circle()
                .fill(MoteTheme.Colors.signalEnd)
                .frame(width: 10, height: 10)
        } else {
            WaveBars(animating: true, tint: MoteTheme.Colors.signalEnd)
        }
    }

    @ViewBuilder
    private var captionText: some View {
        if !model.captionTail.isEmpty {
            Text(model.captionTail)
                .font(MoteTheme.Typography.body(12))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(MoteTheme.Colors.primaryText)
                .frame(maxWidth: 230, alignment: .leading)
        }
    }

    @ViewBuilder
    private func captionTextOrFallback(_ fallback: String) -> some View {
        if model.captionTail.isEmpty {
            Text(fallback).font(.caption).foregroundStyle(.secondary)
        } else {
            captionText
        }
    }
}

/// Decorative bar-style waveform: each bar oscillates on its own phase so the
/// row looks alive while you speak. Not tied to mic amplitude by design.
private struct WaveBars: View {
    let animating: Bool
    let tint: Color
    private let barCount = 5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animating)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<barCount, id: \.self) { i in
                    Capsule()
                        .fill(tint)
                        .frame(width: 4, height: barHeight(index: i, t: t))
                }
            }
            .frame(height: 26)
        }
    }

    private func barHeight(index: Int, t: Double) -> CGFloat {
        let base = 6.0, amplitude = 14.0
        guard animating else { return base + amplitude * 0.25 }
        let phase = Double(index) * 0.8
        let v = (sin(t * 7 + phase) * 0.5) + 0.5
        return base + amplitude * v
    }
}
