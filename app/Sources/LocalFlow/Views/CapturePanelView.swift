import AppKit
import LocalFlowCleanup
import SwiftUI

struct CapturePanelView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let snapshot = CapturePanelSnapshot.make(
            state: panelState,
            pending: state.pendingDictation,
            autoInsert: state.autoInsert,
            recentRecords: state.historyStore.records,
            hotkeyConfiguration: state.hotkeyConfiguration
        )

        VStack(alignment: .leading, spacing: GrotdownTheme.Metrics.sectionSpacing) {
            header
            captureStatus(snapshot)

            if let pending = state.pendingDictation, !state.autoInsert {
                pendingResult(pending)
            } else {
                outputPreference
            }

            recentDictations(snapshot)
            footer
        }
        .padding(16)
        .frame(width: GrotdownTheme.Metrics.panelWidth)
        .background(GrotdownTheme.Colors.surface)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 10) {
            GrotdownSignalMark(isActive: isCapturing)
                .frame(height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("Grotdown")
                    .font(GrotdownTheme.Typography.display(18).weight(.bold))
                    .foregroundStyle(GrotdownTheme.Colors.primaryText)
                Text("On-device dictation")
                    .font(GrotdownTheme.Typography.body(11))
                    .foregroundStyle(GrotdownTheme.Colors.mutedText)
            }
            Spacer()
            Circle()
                .fill(isCapturing ? GrotdownTheme.Colors.signalEnd : GrotdownTheme.Colors.success)
                .frame(width: 8, height: 8)
                .accessibilityLabel(isCapturing ? "Recording" : "Ready")
        }
    }

    private func captureStatus(_ snapshot: CapturePanelSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot.guidance)
                .font(GrotdownTheme.Typography.body(15).weight(.semibold))
                .foregroundStyle(GrotdownTheme.Colors.primaryText)
            Text(state.status.label)
                .font(GrotdownTheme.Typography.body(12))
                .foregroundStyle(GrotdownTheme.Colors.secondaryText)
                .lineLimit(2)
            HStack(spacing: 6) {
                Image(systemName: "option")
                Text(state.hotkeyConfiguration.displayName)
                Text(state.captureMode == .holdToTalk ? "Hold to talk" : "Tap to toggle")
                    .foregroundStyle(GrotdownTheme.Colors.mutedText)
            }
            .font(GrotdownTheme.Typography.mono(11))
            .foregroundStyle(GrotdownTheme.Colors.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GrotdownTheme.Colors.raised, in: RoundedRectangle(cornerRadius: GrotdownTheme.Metrics.controlCornerRadius, style: .continuous))
    }

    private func pendingResult(_ pending: PendingDictation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ready to insert")
                .font(GrotdownTheme.Typography.body(13).weight(.semibold))
                .foregroundStyle(GrotdownTheme.Colors.primaryText)
            Text(pending.resolved.text)
                .font(GrotdownTheme.Typography.body(13))
                .foregroundStyle(GrotdownTheme.Colors.secondaryText)
                .lineLimit(5)
                .textSelection(.enabled)
            Picker("Output", selection: pendingFormatBinding) {
                Text("Plain text").tag(OutputFormat.plain)
                Text("Markdown").tag(OutputFormat.markdown)
            }
            .pickerStyle(.segmented)
            HStack {
                Button("Copy", action: state.copyPending)
                    .buttonStyle(.bordered)
                Button("Insert", action: state.insertPending)
                    .buttonStyle(.borderedProminent)
                    .tint(GrotdownTheme.Colors.signalEnd)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GrotdownTheme.Colors.input, in: RoundedRectangle(cornerRadius: GrotdownTheme.Metrics.controlCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GrotdownTheme.Metrics.controlCornerRadius, style: .continuous)
                .stroke(GrotdownTheme.Colors.border, lineWidth: 1)
        }
    }

    private var outputPreference: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Output")
                .font(GrotdownTheme.Typography.body(13).weight(.semibold))
                .foregroundStyle(GrotdownTheme.Colors.primaryText)
            Picker("Output", selection: $state.outputFormat) {
                Text("Plain text").tag(OutputFormat.plain)
                Text("Markdown").tag(OutputFormat.markdown)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            Text(state.outputFormat == .markdown
                ? "Uses safe local GFM formatting. Unsafe results remain plain text."
                : "Inserts the cleaned transcription as plain text.")
                .font(GrotdownTheme.Typography.body(11))
                .foregroundStyle(GrotdownTheme.Colors.mutedText)
        }
    }

    private func recentDictations(_ snapshot: CapturePanelSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(GrotdownTheme.Typography.body(13).weight(.semibold))
                .foregroundStyle(GrotdownTheme.Colors.primaryText)
            if snapshot.recentTitles.isEmpty {
                Text("Your completed dictations stay on this Mac.")
                    .font(GrotdownTheme.Typography.body(11))
                    .foregroundStyle(GrotdownTheme.Colors.mutedText)
            } else {
                ForEach(Array(snapshot.recentTitles.enumerated()), id: \.offset) { _, title in
                    Text(title)
                        .font(GrotdownTheme.Typography.body(12))
                        .foregroundStyle(GrotdownTheme.Colors.secondaryText)
                        .lineLimit(1)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if case .paused = state.status {
                Button("Resume") { Task { await state.resumeDictation() } }
            } else {
                Button("Pause", action: state.pauseDictation)
            }
            Spacer()
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "library")
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .help("Open history and snippets")
            SettingsLink {
                Image(systemName: "gearshape")
            }
            .help("Settings")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("Quit Grotdown")
            .buttonStyle(.plain)
        }
        .font(GrotdownTheme.Typography.body(12))
    }

    private var pendingFormatBinding: Binding<OutputFormat> {
        Binding(
            get: { state.pendingDictation?.resolved.requestedFormat ?? state.outputFormat },
            set: state.setPendingFormat
        )
    }

    private var isCapturing: Bool {
        if case .recording = state.status { return true }
        return false
    }

    private var panelState: CapturePanelSnapshot.State {
        switch state.status {
        case .needsPermissions: .needsPermissions
        case .loadingModel, .transcribing, .cleaning: .processing
        case .idle: .idle
        case .recording: .recording
        case .paused: .paused
        case .failed: .failed
        }
    }
}
