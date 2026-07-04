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

    private static let size = CGSize(width: 168, height: 56)

    var enabled: Bool {
        UserDefaults.standard.object(forKey: "hudEnabled") as? Bool ?? true
    }

    func show(_ phase: HUDPhase) {
        guard enabled else { return }
        hideGeneration += 1
        model.phase = phase
        let panel = panel ?? makePanel()
        reposition(panel)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    /// Flash the done state, then fade out — unless a new dictation supersedes it.
    func finishAndHide() {
        guard enabled, panel != nil else { return }
        model.phase = .done
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
        panel.contentView = NSHostingView(rootView: WaveformHUDView(model: model))
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

struct WaveformHUDView: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        HStack(spacing: 8) {
            switch model.phase {
            case .recording:
                WaveBars(animating: true, tint: .accentColor)
            case .transcribing:
                WaveBars(animating: true, tint: .secondary)
                Text("Transcribing")
                    .font(.caption).foregroundStyle(.secondary)
            case .cleaning:
                Image(systemName: "sparkles").foregroundStyle(Color.accentColor)
                Text("Cleaning up")
                    .font(.caption).foregroundStyle(.secondary)
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Done").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        .padding(6)
        .animation(.easeInOut(duration: 0.2), value: model.phase)
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
