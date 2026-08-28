import SwiftUI

@main
struct CCOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                settings: appDelegate.settings,
                multiService: appDelegate.multiService,
                updateService: appDelegate.updateService
            )
        }
        .defaultSize(
            width: DesignTokens.Layout.settingsWidth,
            height: DesignTokens.Layout.settingsHeight
        )
        .commands {
            CommandMenu("Overlay") {
                Button(OverlayContextMenuAction.showOverlay.title, action: appDelegate.showOverlayFromCommand)
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Button(OverlayContextMenuAction.showDashboard.title, action: appDelegate.showDashboard)
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }
}
