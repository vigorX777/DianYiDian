import AppKit
import DianYiDianCore

@MainActor
final class StatusBarController: NSObject {
    private let counterController: CounterController
    private let onOpenSettings: () -> Void
    private let statusItem: NSStatusItem
    private let iconRenderer = StatusIconRenderer()

    init(counterController: CounterController, onOpenSettings: @escaping () -> Void) {
        self.counterController = counterController
        self.onOpenSettings = onOpenSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: 60)
        super.init()
        configureButton()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(counterDidChange),
            name: .dianYiDianCounterDidChange,
            object: nil
        )
        refreshIcon()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }
        button.target = self
        button.action = #selector(statusButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "点一点"
        button.imagePosition = .imageLeading
    }

    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
            return
        }

        do {
            let before = counterController.snapshot.reachedGoal
            let snapshot = try counterController.increment()
            refreshIcon()
            showLightFeedbackIfNeeded(snapshot: snapshot, reachedGoalBeforeIncrement: before)
        } catch {
            presentError("打卡失败：\(error.localizedDescription)")
        }
    }

    private func showMenu() {
        do {
            try counterController.rolloverIfNeeded()
        } catch {
            presentError("跨天归档失败：\(error.localizedDescription)")
        }
        refreshIcon()

        statusItem.menu = buildMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let snapshot = counterController.snapshot
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: snapshot.item.name, action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let countItem = NSMenuItem(
            title: "今日 \(snapshot.state.count) / \(snapshot.item.dailyTarget)",
            action: nil,
            keyEquivalent: ""
        )
        countItem.isEnabled = false
        menu.addItem(countItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "打卡", action: #selector(menuIncrement), keyEquivalent: ""))

        let undoItem = NSMenuItem(title: "撤销", action: #selector(menuUndo), keyEquivalent: "")
        undoItem.isEnabled = snapshot.state.hasUndoableIncrement && snapshot.state.count > 0
        menu.addItem(undoItem)

        menu.addItem(NSMenuItem(title: "重置", action: #selector(menuReset), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(menuSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出点一点", action: #selector(menuQuit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }
        return menu
    }

    @objc private func menuIncrement() {
        do {
            _ = try counterController.increment()
            refreshIcon()
        } catch {
            presentError("打卡失败：\(error.localizedDescription)")
        }
    }

    @objc private func menuUndo() {
        do {
            _ = try counterController.undoLastIncrement()
            refreshIcon()
        } catch {
            presentError("撤销失败：\(error.localizedDescription)")
        }
    }

    @objc private func menuReset() {
        do {
            _ = try counterController.resetToday()
            refreshIcon()
        } catch {
            presentError("重置失败：\(error.localizedDescription)")
        }
    }

    @objc private func menuSettings() {
        onOpenSettings()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    @objc private func counterDidChange() {
        refreshIcon()
    }

    private func refreshIcon() {
        let snapshot = counterController.snapshot
        statusItem.button?.image = iconRenderer.makeImage(
            progress: snapshot.progress,
            style: snapshot.item.iconStyle
        )
        statusItem.button?.attributedTitle = NSAttributedString(
            string: "\(snapshot.state.count)/\(snapshot.item.dailyTarget)",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    private func showLightFeedbackIfNeeded(snapshot: CounterSnapshot, reachedGoalBeforeIncrement: Bool) {
        if snapshot.settings.showIncrementFeedback {
            NSSound(named: "Pop")?.play()
        }
        if snapshot.settings.notifyWhenGoalReached, snapshot.reachedGoal, !reachedGoalBeforeIncrement {
            NSSound(named: "Glass")?.play()
        }
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
