import DianYiDianCore
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var launchAtLogin: Bool
    @Published var showIncrementFeedback: Bool
    @Published var notifyWhenGoalReached: Bool
    @Published var itemName: String
    @Published var dailyTarget: Int
    @Published var initialCount: Int
    @Published var iconStyle: IconStyle
    @Published var applyInitialCountToToday = false
    @Published var message: String?

    private let counterController: CounterController
    private let launchAtLoginService: LaunchAtLoginService

    init(counterController: CounterController, launchAtLoginService: LaunchAtLoginService) {
        self.counterController = counterController
        self.launchAtLoginService = launchAtLoginService

        let snapshot = counterController.snapshot
        self.launchAtLogin = snapshot.settings.launchAtLogin
        self.showIncrementFeedback = snapshot.settings.showIncrementFeedback
        self.notifyWhenGoalReached = snapshot.settings.notifyWhenGoalReached
        self.itemName = snapshot.item.name
        self.dailyTarget = snapshot.item.dailyTarget
        self.initialCount = snapshot.item.initialCount
        self.iconStyle = snapshot.item.iconStyle
    }

    func save() {
        message = nil

        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextItem = CounterItem(
            name: trimmedName.isEmpty ? "喝水" : trimmedName,
            dailyTarget: max(1, min(99, dailyTarget)),
            initialCount: max(0, min(99, initialCount)),
            iconStyle: iconStyle
        )
        let nextSettings = AppSettings(
            launchAtLogin: launchAtLogin,
            showIncrementFeedback: showIncrementFeedback,
            notifyWhenGoalReached: notifyWhenGoalReached
        )

        do {
            try counterController.updateItem(nextItem, applyInitialCountToToday: applyInitialCountToToday)
            counterController.updateSettings(nextSettings)
        } catch {
            message = "保存失败：\(error.localizedDescription)"
            return
        }

        do {
            try launchAtLoginService.setEnabled(launchAtLogin)
            message = "已保存"
        } catch {
            message = "设置已保存，但开机自启更新失败：\(error.localizedDescription)"
        }

        NotificationCenter.default.post(name: .dianYiDianCounterDidChange, object: nil)
    }
}
