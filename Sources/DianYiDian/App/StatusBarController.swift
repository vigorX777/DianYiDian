import AppKit
import DianYiDianCore
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let counterController: CounterController
    private let onOpenSettings: () -> Void
    private let iconRenderer = StatusIconRenderer()
    private let soundFeedbackService = SoundFeedbackService()
    private var statusItems: [UUID: NSStatusItem] = [:]
    private var activeMenu: NSMenu?
    private var shouldRebuildAfterMenuClose = false
    private var reopenMenuAfterCloseScenarioID: UUID?
    private var highlightedScenarioIDs: Set<UUID> = []
    private var celebratingScenarioIDs: Set<UUID> = []
    private var celebrationPopovers: [UUID: NSPopover] = [:]

    init(counterController: CounterController, onOpenSettings: @escaping () -> Void) {
        self.counterController = counterController
        self.onOpenSettings = onOpenSettings
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(counterDidChange(_:)),
            name: .dianYiDianCounterDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reminderDidFire(_:)),
            name: .dianYiDianReminderDidFire,
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

        if NSApp.currentEvent?.type == .rightMouseDown || NSApp.currentEvent?.type == .rightMouseUp {
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

        let anchorScenarioID = statusItems[scenarioID] == nil ? statusItems.keys.first : scenarioID
        guard let anchorScenarioID,
              let item = statusItems[anchorScenarioID]
        else {
            return
        }
        guard let button = item.button else {
            return
        }

        let hostingView = NSHostingView(rootView: makeStatusMenuView(scenarioID: scenarioID))
        hostingView.frame = NSRect(x: 0, y: 0, width: 326, height: 1)
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: 326,
            height: min(520, max(320, fittingSize.height))
        )

        let menu = NSMenu()
        menu.delegate = self
        let contentItem = NSMenuItem()
        contentItem.view = hostingView
        menu.addItem(contentItem)

        activeMenu = menu
        item.menu = menu
        button.performClick(nil)
    }

    private func makeStatusMenuView(scenarioID: UUID) -> StatusMenuView {
        StatusMenuView(
            initialScenarioID: scenarioID,
            scenarioData: statusMenuScenarioData(),
            onIncrement: { [weak self] selectedID in
                self?.closeMenuPopover()
                self?.increment(scenarioID: selectedID)
            },
            onUndo: { [weak self] selectedID in
                self?.closeMenuPopover()
                self?.undo(scenarioID: selectedID)
            },
            onReset: { [weak self] selectedID in
                self?.closeMenuPopover()
                self?.reset(scenarioID: selectedID)
            },
            onSelectScenario: { [weak self] selectedID in
                self?.selectScenarioInOpenMenu(id: selectedID)
            },
            onOpenSettings: { [weak self] in
                self?.closeMenuPopover()
                self?.onOpenSettings()
            },
            onQuit: { [weak self] in
                self?.closeMenuPopover()
                NSApp.terminate(nil)
            }
        )
    }

    @objc private func menuIncrement(_ sender: NSMenuItem) {
        increment(scenarioID: scenarioID(from: sender))
    }

    @objc private func menuUndo(_ sender: NSMenuItem) {
        undo(scenarioID: scenarioID(from: sender))
    }

    @objc private func menuReset(_ sender: NSMenuItem) {
        reset(scenarioID: scenarioID(from: sender))
    }

    @objc private func menuSelectScenario(_ sender: NSMenuItem) {
        selectScenario(id: scenarioID(from: sender))
    }

    @objc private func menuSettings() {
        onOpenSettings()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }

    @objc private func counterDidChange(_ notification: Notification) {
        if notification.object as AnyObject === self {
            return
        }
        refreshAllStatusItems()
    }

    @objc private func reminderDidFire(_ notification: Notification) {
        guard let idString = notification.userInfo?["scenarioID"] as? String,
              let scenarioID = UUID(uuidString: idString)
        else {
            return
        }
        let scenarioName = notification.userInfo?["scenarioName"] as? String
            ?? counterController.snapshot(for: scenarioID).scenario.name
        triggerReminderHint(scenarioID: scenarioID, text: "\(reminderVerb(for: scenarioName))了")
    }

    private func undo(scenarioID: UUID) {
        do {
            _ = try counterController.undoLastIncrement(scenarioID: scenarioID)
            refreshAllStatusItems()
            NotificationCenter.default.post(name: .dianYiDianCounterDidChange, object: nil)
        } catch {
            presentError("撤销失败：\(error.localizedDescription)")
        }
    }

    private func reset(scenarioID: UUID) {
        do {
            _ = try counterController.resetToday(scenarioID: scenarioID)
            refreshAllStatusItems()
            NotificationCenter.default.post(name: .dianYiDianCounterDidChange, object: nil)
        } catch {
            presentError("重置失败：\(error.localizedDescription)")
        }
    }

    private func selectScenario(id scenarioID: UUID) {
        counterController.selectScenario(id: scenarioID)
        rebuildStatusItems()
        NotificationCenter.default.post(name: .dianYiDianCounterDidChange, object: nil)
    }

    private func selectScenarioInOpenMenu(id scenarioID: UUID) {
        counterController.selectScenario(id: scenarioID)
        shouldRebuildAfterMenuClose = true
        reopenMenuAfterCloseScenarioID = scenarioID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self,
                  self.activeMenu != nil,
                  self.reopenMenuAfterCloseScenarioID == scenarioID
            else {
                return
            }
            self.reopenMenuAfterCloseScenarioID = nil
        }
    }

    private func closeMenuPopover() {
        activeMenu?.cancelTracking()
    }

    func menuDidClose(_ menu: NSMenu) {
        if activeMenu === menu {
            for item in statusItems.values where item.menu === menu {
                item.menu = nil
            }
            activeMenu = nil
            if shouldRebuildAfterMenuClose {
                shouldRebuildAfterMenuClose = false
                let scenarioIDToReopen = reopenMenuAfterCloseScenarioID
                reopenMenuAfterCloseScenarioID = nil
                rebuildStatusItems()
                NotificationCenter.default.post(name: .dianYiDianCounterDidChange, object: self)
                if let scenarioIDToReopen {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
                        self?.showMenu(scenarioID: scenarioIDToReopen)
                    }
                }
            }
        }
    }

    private func statusMenuScenarioData() -> [StatusMenuScenarioData] {
        counterController.enabledScenarios.map { scenario in
            let snapshot = counterController.snapshot(for: scenario.id)
            return StatusMenuScenarioData(
                id: scenario.id,
                snapshot: snapshot,
                monthProgress: counterController.currentMonthProgress(scenarioID: scenario.id),
                lastCheckInText: lastCheckInText(for: snapshot.state.lastCheckInAt)
            )
        }
    }

    private func increment(scenarioID: UUID) {
        do {
            let before = counterController.snapshot(for: scenarioID).reachedGoal
            let snapshot = try counterController.increment(scenarioID: scenarioID)
            refreshAllStatusItems()
            if snapshot.settings.checkInAnimationEnabled {
                triggerCheckInFeedback(scenarioID: scenarioID)
            }
            if !before && snapshot.reachedGoal && snapshot.settings.goalCelebrationEnabled {
                triggerGoalCelebration(snapshot: snapshot)
            }
            playFeedback(snapshot: snapshot, reachedGoalBeforeIncrement: before)
            NotificationCenter.default.post(name: .dianYiDianCounterDidChange, object: self)
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

    private func refreshStatusItem(scenarioID: UUID) {
        guard let item = statusItems[scenarioID] else {
            refreshAllStatusItems()
            return
        }
        refresh(item: item, scenarioID: scenarioID)
    }

    private func refresh(item: NSStatusItem, scenarioID: UUID) {
        let snapshot = counterController.snapshot(for: scenarioID)
        let displayMode = snapshot.settings.menuBarDisplayMode
        let title = "\(snapshot.state.count)/\(snapshot.scenario.dailyTarget)"
        item.length = displayMode == .iconOnly ? 28 : max(68, CGFloat(title.count * 8 + 34))
        item.button?.image = iconRenderer.makeImage(
            progress: snapshot.progress,
            style: snapshot.scenario.iconStyle,
            themeColor: snapshot.scenario.themeColor,
            isHighlighted: highlightedScenarioIDs.contains(scenarioID),
            isCelebrating: celebratingScenarioIDs.contains(scenarioID)
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

    private func lastCheckInText(for date: Date?) -> String {
        guard let date else {
            return "上次：今日未打卡"
        }

        let elapsed = max(0, Int(Date().timeIntervalSince(date)))
        if elapsed < 60 {
            return "上次：刚刚"
        }
        let minutes = elapsed / 60
        if minutes < 60 {
            return "上次：\(minutes) 分钟前"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "上次：\(hours) 小时前"
        }
        return "上次：今日未打卡"
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

    private func triggerCheckInFeedback(scenarioID: UUID) {
        highlightedScenarioIDs.insert(scenarioID)
        refreshStatusItem(scenarioID: scenarioID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self else {
                return
            }
            highlightedScenarioIDs.remove(scenarioID)
            refreshStatusItem(scenarioID: scenarioID)
        }
    }

    private func triggerGoalCelebration(snapshot: CounterSnapshot) {
        let scenarioID = snapshot.scenario.id
        celebratingScenarioIDs.insert(scenarioID)
        refreshStatusItem(scenarioID: scenarioID)
        showTransientPopover(scenarioID: scenarioID, text: "今日\(snapshot.scenario.name)完成")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else {
                return
            }
            celebratingScenarioIDs.remove(scenarioID)
            celebrationPopovers[scenarioID]?.close()
            celebrationPopovers.removeValue(forKey: scenarioID)
            refreshStatusItem(scenarioID: scenarioID)
        }
    }

    private func triggerReminderHint(scenarioID: UUID, text: String) {
        highlightedScenarioIDs.insert(scenarioID)
        refreshStatusItem(scenarioID: scenarioID)
        showTransientPopover(
            scenarioID: scenarioID,
            text: text,
            onClick: { [weak self] in
                self?.celebrationPopovers[scenarioID]?.close()
                self?.celebrationPopovers.removeValue(forKey: scenarioID)
                self?.increment(scenarioID: scenarioID)
            }
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else {
                return
            }
            highlightedScenarioIDs.remove(scenarioID)
            celebrationPopovers[scenarioID]?.close()
            celebrationPopovers.removeValue(forKey: scenarioID)
            refreshStatusItem(scenarioID: scenarioID)
        }
    }

    private func showTransientPopover(scenarioID: UUID, text: String, onClick: (() -> Void)? = nil) {
        guard let button = popoverAnchorButton(for: scenarioID) else {
            return
        }

        celebrationPopovers[scenarioID]?.close()
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 168, height: 52)
        popover.contentViewController = TransientMessageViewController(text: text, onClick: onClick)
        celebrationPopovers[scenarioID] = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func popoverAnchorButton(for scenarioID: UUID) -> NSStatusBarButton? {
        if let button = statusItems[scenarioID]?.button {
            return button
        }

        for scenario in visibleMenuBarScenarios() {
            if let button = statusItems[scenario.id]?.button {
                return button
            }
        }

        return statusItems.values.compactMap(\.button).first
    }

    private func reminderVerb(for scenarioName: String) -> String {
        let trimmedName = scenarioName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return "该打卡"
        }
        if trimmedName.hasPrefix("喝") || trimmedName.hasPrefix("吃") || trimmedName.hasPrefix("运动") {
            return "该\(trimmedName)"
        }
        return "该\(trimmedName)"
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

private final class TransientMessageViewController: NSViewController {
    private let text: String
    private let onClick: (() -> Void)?

    init(text: String, onClick: (() -> Void)? = nil) {
        self.text = text
        self.onClick = onClick
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 168, height: 52))
        container.material = .popover
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.28).cgColor

        let button = NSButton(title: text, target: self, action: #selector(messageClicked))
        button.isBordered = false
        button.font = .systemFont(ofSize: 14, weight: .semibold)
        button.contentTintColor = .labelColor
        button.alignment = .center
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setButtonType(.momentaryChange)
        container.addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            button.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        view = container
    }

    @objc private func messageClicked() {
        onClick?()
    }
}
