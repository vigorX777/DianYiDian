import AppKit
import DianYiDianCore

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let counterController: CounterController
    private let onOpenSettings: () -> Void
    private let statusItem: NSStatusItem
    private let iconRenderer = StatusIconRenderer()
    private let soundFeedbackService = SoundFeedbackService()
    private var activeMenu: NSMenu?

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
            playFeedback(snapshot: snapshot, reachedGoalBeforeIncrement: before)
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

        let menu = buildMenu()
        menu.delegate = self
        activeMenu = menu
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
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

        let calendarItem = NSMenuItem()
        calendarItem.view = MonthCalendarMenuView(monthProgress: counterController.currentMonthProgress())
        calendarItem.isEnabled = false
        menu.addItem(calendarItem)
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
            let before = counterController.snapshot.reachedGoal
            let snapshot = try counterController.increment()
            refreshIcon()
            playFeedback(snapshot: snapshot, reachedGoalBeforeIncrement: before)
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

    func menuDidClose(_ menu: NSMenu) {
        if activeMenu === menu {
            statusItem.menu = nil
            activeMenu = nil
        }
    }

    private func refreshIcon() {
        let snapshot = counterController.snapshot
        let displayMode = snapshot.settings.menuBarDisplayMode
        let title = "\(snapshot.state.count)/\(snapshot.item.dailyTarget)"
        statusItem.length = displayMode == .iconOnly ? 28 : max(68, CGFloat(title.count * 8 + 34))
        statusItem.button?.image = iconRenderer.makeImage(
            progress: snapshot.progress,
            style: snapshot.item.iconStyle
        )
        statusItem.button?.imagePosition = displayMode == .iconOnly ? .imageOnly : .imageLeading
        statusItem.button?.attributedTitle = displayMode == .iconOnly
            ? NSAttributedString(string: "")
            : NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: NSColor.labelColor,
                    .shadow: titleShadow()
                ]
            )
        statusItem.button?.toolTip = "\(snapshot.item.name)：今日 \(snapshot.state.count) / \(snapshot.item.dailyTarget)"
    }

    private func titleShadow() -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowOffset = .zero
        shadow.shadowBlurRadius = 1.2
        shadow.shadowColor = NSColor.windowBackgroundColor.withAlphaComponent(0.8)
        return shadow
    }

    private func playFeedback(snapshot: CounterSnapshot, reachedGoalBeforeIncrement: Bool) {
        soundFeedbackService.playIncrementIfNeeded(settings: snapshot.settings)
        soundFeedbackService.playGoalReachedIfNeeded(
            snapshot: snapshot,
            reachedGoalBeforeIncrement: reachedGoalBeforeIncrement
        )
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
