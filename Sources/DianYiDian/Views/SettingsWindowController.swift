import AppKit
import DianYiDianCore
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(
        counterController: CounterController,
        launchAtLoginService: LaunchAtLoginService,
        shortcutWarningProvider: @escaping () -> String?,
        notificationWarningProvider: @escaping () -> String?
    ) {
        let viewModel = SettingsViewModel(
            counterController: counterController,
            launchAtLoginService: launchAtLoginService,
            shortcutWarningProvider: shortcutWarningProvider,
            notificationWarningProvider: notificationWarningProvider
        )
        let hostingController = NSHostingController(rootView: SettingsView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "点一点设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 760, height: 560))
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else {
            return
        }
        if !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }
}
