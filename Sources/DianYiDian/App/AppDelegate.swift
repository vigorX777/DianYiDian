import AppKit
import DianYiDianCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: CounterController?
    private var settingsWindowController: SettingsWindowController?
    private var statusBarController: StatusBarController?
    private var globalShortcutService: GlobalShortcutService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let counterController = CounterController()
        let shortcutService = GlobalShortcutService { [weak counterController] index in
            counterController?.selectScenarioByShortcutIndex(index)
            NotificationCenter.default.post(name: .dianYiDianCounterDidChange, object: nil)
        }
        shortcutService.registerDefaultShortcuts()

        let settingsController = SettingsWindowController(
            counterController: counterController,
            launchAtLoginService: LaunchAtLoginService(),
            shortcutWarningProvider: { [weak shortcutService] in
                shortcutService?.registrationError
            }
        )
        let statusController = StatusBarController(
            counterController: counterController,
            onOpenSettings: { [weak settingsController] in
                settingsController?.show()
            }
        )

        controller = counterController
        settingsWindowController = settingsController
        statusBarController = statusController
        globalShortcutService = shortcutService
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalShortcutService?.invalidate()
        globalShortcutService = nil
        statusBarController = nil
        settingsWindowController = nil
        controller = nil
    }
}
