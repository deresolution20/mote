import SwiftUI

@main
struct LocalFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            CapturePanelView().environmentObject(state)
        } label: {
            Image(systemName: state.status.symbolName)
        }
        .menuBarExtraStyle(.window)

        WindowGroup(id: "library") {
            LibraryRootView().environmentObject(state)
        }
        .defaultSize(width: 960, height: 580)

        Settings {
            SettingsView().environmentObject(state)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            AppState.shared.refreshPermissions()
            if AppState.shared.allPermissionsGranted {
                await AppState.shared.startPipeline()
            } else {
                AppState.shared.showOnboarding()
            }
        }
    }
}
