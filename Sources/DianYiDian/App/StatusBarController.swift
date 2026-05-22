import AppKit
import DianYiDianCore

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let counterController: CounterController
    private let onOpenSettings: () -> Void
    private let iconRenderer = StatusIconRenderer()
    private let soundFeedbackService = SoundFeedbackService()
    private var statusItems: [UUID: NSStatusItem] = [:]
    private var activeMenu: NSMenu?

    init(counterController: CounterController, onOpenSettings: @escaping () -> Void) {
        self.counterController = counterController
        self.onOpenSettings = onOpenSettings
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(counterDidChange),
            name: .dianYiDianCounterDidChange,
            object: nil
        )
        rebuildStatusItems()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func rebuildStatusItems() {
        removeStatusItems()

        let scenariosToShow = visibleMenuBarScenarios()
        for scenario in scenariosToShow {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            configure(item: item, scenarioID: scenario.id)
            statusItems[scenario.id] = item
        }
    }

    private func removeStatusItems() {
        for item in statusItems.values {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItems.removeAll()
    }

    private func visibleMenuBarScenarios() -> [CheckInScenario] {
        if counterController.settings.scenarioDisplayMode == .pinnedScenarios,
           !counterController.pinnedScenarios.isEmpty {
            return counterController.pinnedScenarios
        }
        return [counterController.snapshot.scenario]
    }

    private func configure(item: NSStatusItem, scenarioID: UUID) {
        guard let button = item.button else {
            return
        }
        button.target = self
        button.action = #selector(statusButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        refresh(item: item, scenarioID: scenarioID)
    }

    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        guard let scenarioID = scenarioID(for: sender) else {
            return
        }

        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu(scenarioID: scenarioID)
            return
        }

        increment(scenarioID: scenarioID)
    }

    private func scenarioID(for button: NSStatusBarButton) -> UUID? {
        statusItems.first { _, item in item.button === button }?.key
    }

    private func showMenu(scenarioID: UUID) {
        do {
            try counterController.rolloverIfNeeded()
        } catch {
            presentError("跨天归档失败：\(error.localizedDescription)")
        }
        refreshAllStatusItems()

        guard let item = statusItems[scenarioID] else {
            return
        }
        let menu = buildMenu(scenarioID: scenarioID)
        menu.delegate = self
        activeMenu = menu
        item.menu = menu
        item.button?.performClick(nil)
    }

    private func buildMenu(scenarioID: UUID) -> NSMenu {
        let snapshot = counterController.snapshot(for: scenarioID)
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: snapshot.scenario.name, action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let countItem = NSMenuItem(
            title: "今日 \(snapshot.state.count) / \(snapshot.scenario.dailyTarget)",
            action: nil,
            keyEquivalent: ""
        )
        countItem.isEnabled = false
        menu.addItem(countItem)

        let calendarItem = NSMenuItem()
        calendarItem.view = MonthCalendarMenuView(monthProgress: counterController.currentMonthProgress(scenarioID: scenarioID))
        calendarItem.isEnabled = false
        menu.addItem(calendarItem)
        menu.addItem(.separator())

        addScenarioSwitchItems(to: menu)
        menu.addItem(.separator())

        menu.addItem(actionItem(title: "打卡", action: #selector(menuIncrement(_:)), scenarioID: scenarioID))

        let undoItem = actionItem(title: "撤销", action: #selector(menuUndo(_:)), scenarioID: scenarioID)
        undoItem.isEnabled = snapshot.state.hasUndoableIncrement && snapshot.state.count > 0
        menu.addItem(undoItem)

        menu.addItem(actionItem(title: "重置", action: #selector(menuReset(_:)), scenarioID: scenarioID))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(menuSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出点一点", action: #selector(menuQuit), keyEquivalent: "q"))

        for item in menu.items where item.target == nil {
            item.target = self
        }
        return menu
    }

    private func addScenarioSwitchItems(to menu: NSMenu) {
        let header = NSMenuItem(title: "切换场景", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        for (index, scenario) in counterController.enabledScenarios.enumerated() {
            let snapshot = counterController.snapshot(for: scenario.id)
            let item = NSMenuItem(
                title: "\(scenario.name)  \(snapshot.state.count)/\(scenario.dailyTarget)",
                action: #selector(menuSelectScenario(_:)),
                keyEquivalent: index < 9 ? "\(index + 1)" : ""
            )
            item.target = self
            item.representedObject = scenario.id.uuidString
            item.state = scenario.id == counterController.currentScenarioID ? .on : .off
            item.image = iconRenderer.makeImage(progress: snapshot.progress, style: scenario.iconStyle, themeColor: scenario.themeColor)
            menu.addItem(item)
        }
    }

    private func actionItem(title: String, action: Selector, scenarioID: UUID) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = scenarioID.uuidString
        return item
    }

    @objc private func menuIncrement(_ sender: NSMenuItem) {
        increment(scenarioID: scenarioID(from: sender))
    }

    @objc private func menuUndo(_ sender: NSMenuItem) {
        do {
            _ = try counterController.undoLastIncrement(scenarioID: scenarioID(from: sender))
            refreshAllStatusItems()
        } catch {
            presentError("撤销失败：\(error.localizedDescription)")
        }
    }

    @objc private func menuReset(_ sender: NSMenuItem) {
        do {
            _ = try counterController.resetToday(scenarioID: scenarioID(from: sender))
            refreshAllStatusItems()
        } catch {
            presentError("重置失败：\(error.localizedDescription)")
        }
    }

    @objc private func menuSelectScenario(_ sender: NSMenuItem) {
        let scenarioID = scenarioID(from: sender)
        counterController.selectScenario(id: scenarioID)
        rebuildStatusItems()
        NotificationCenter.default.post(name: .dianYiDianCounterDidChange, object: nil)
    }

    @objc private func menuSettings() {
        onOpenSettings()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    @objc private func counterDidChange() {
        rebuildStatusItems()
    }

    func menuDidClose(_ menu: NSMenu) {
        if activeMenu === menu {
            for item in statusItems.values where item.menu === menu {
                item.menu = nil
            }
            activeMenu = nil
        }
    }

    private func increment(scenarioID: UUID) {
        do {
            let before = counterController.snapshot(for: scenarioID).reachedGoal
            let snapshot = try counterController.increment(scenarioID: scenarioID)
            refreshAllStatusItems()
            playFeedback(snapshot: snapshot, reachedGoalBeforeIncrement: before)
        } catch {
            presentError("打卡失败：\(error.localizedDescription)")
        }
    }

    private func refreshAllStatusItems() {
        let expectedIDs = Set(visibleMenuBarScenarios().map(\.id))
        if Set(statusItems.keys) != expectedIDs {
            rebuildStatusItems()
            return
        }

        for (scenarioID, item) in statusItems {
            refresh(item: item, scenarioID: scenarioID)
        }
    }

    private func refresh(item: NSStatusItem, scenarioID: UUID) {
        let snapshot = counterController.snapshot(for: scenarioID)
        let displayMode = snapshot.settings.menuBarDisplayMode
        let title = "\(snapshot.state.count)/\(snapshot.scenario.dailyTarget)"
        item.length = displayMode == .iconOnly ? 28 : max(68, CGFloat(title.count * 8 + 34))
        item.button?.image = iconRenderer.makeImage(
            progress: snapshot.progress,
            style: snapshot.scenario.iconStyle,
            themeColor: snapshot.scenario.themeColor
        )
        item.button?.imagePosition = displayMode == .iconOnly ? .imageOnly : .imageLeading
        item.button?.attributedTitle = displayMode == .iconOnly
            ? NSAttributedString(string: "")
            : NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: NSColor.labelColor,
                    .shadow: titleShadow()
                ]
            )
        item.button?.toolTip = "\(snapshot.scenario.name)：今日 \(snapshot.state.count) / \(snapshot.scenario.dailyTarget)"
    }

    private func scenarioID(from item: NSMenuItem) -> UUID {
        if let idString = item.representedObject as? String,
           let id = UUID(uuidString: idString) {
            return id
        }
        return counterController.currentScenarioID
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
