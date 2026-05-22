import AppKit
import DianYiDianCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: CounterController?
    private var settingsWindowController: SettingsWindowController?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let counterController = CounterController()
        let settingsController = SettingsWindowController(
            counterController: counterController,
            launchAtLoginService: LaunchAtLoginService()
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
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController = nil
        settingsWindowController = nil
        controller = nil
    }
}
