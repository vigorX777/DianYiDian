import DianYiDianCore
import Foundation

enum SettingsMessageKind {
    case success
    case warning
    case error
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var launchAtLogin: Bool
    @Published var showIncrementFeedback: Bool
    @Published var notifyWhenGoalReached: Bool
    @Published var menuBarDisplayMode: MenuBarDisplayMode
    @Published var itemName: String
    @Published var dailyTarget: Int
    @Published var initialCount: Int
    @Published var iconStyle: IconStyle
    @Published var applyInitialCountToToday = false
    @Published var message: String?
    @Published var messageKind: SettingsMessageKind = .success

    private let counterController: CounterController
    private let launchAtLoginService: LaunchAtLoginService
    private var clearMessageTask: Task<Void, Never>?

    init(counterController: CounterController, launchAtLoginService: LaunchAtLoginService) {
        self.counterController = counterController
        self.launchAtLoginService = launchAtLoginService

        let snapshot = counterController.snapshot
        self.launchAtLogin = snapshot.settings.launchAtLogin
        self.showIncrementFeedback = snapshot.settings.showIncrementFeedback
        self.notifyWhenGoalReached = snapshot.settings.notifyWhenGoalReached
        self.menuBarDisplayMode = snapshot.settings.menuBarDisplayMode
        self.itemName = snapshot.item.name
        self.dailyTarget = snapshot.item.dailyTarget
        self.initialCount = snapshot.item.initialCount
        self.iconStyle = snapshot.item.iconStyle
    }

    deinit {
        clearMessageTask?.cancel()
    }

    var itemNameValidationMessage: String? {
        itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "保存时将使用默认名称“喝水”。"
            : nil
    }

    func save() {
        clearMessageTask?.cancel()
        message = nil
        messageKind = .success

        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedName = trimmedName.isEmpty ? "喝水" : trimmedName
        let sanitizedDailyTarget = max(1, min(99, dailyTarget))
        let sanitizedInitialCount = max(0, min(99, initialCount))

        var validationNotes: [String] = []
        if trimmedName.isEmpty {
            validationNotes.append("事项名称为空，已恢复为“喝水”。")
        } else if sanitizedName != itemName {
            validationNotes.append("事项名称首尾空格已清理。")
        }
        if dailyTarget != sanitizedDailyTarget {
            validationNotes.append("每日目标已限制在 1-99。")
        }
        if initialCount != sanitizedInitialCount {
            validationNotes.append("今日初始次数已限制在 0-99。")
        }

        itemName = sanitizedName
        dailyTarget = sanitizedDailyTarget
        initialCount = sanitizedInitialCount

        let nextItem = CounterItem(
            name: sanitizedName,
            dailyTarget: sanitizedDailyTarget,
            initialCount: sanitizedInitialCount,
            iconStyle: iconStyle
        )
        let nextSettings = AppSettings(
            launchAtLogin: launchAtLogin,
            showIncrementFeedback: showIncrementFeedback,
            notifyWhenGoalReached: notifyWhenGoalReached,
            menuBarDisplayMode: menuBarDisplayMode
        )

        do {
            try counterController.updateItem(nextItem, applyInitialCountToToday: applyInitialCountToToday)
            counterController.updateSettings(nextSettings)
        } catch {
            setMessage("保存失败：\(error.localizedDescription)", kind: .error)
            return
        }

        do {
            try launchAtLoginService.setEnabled(launchAtLogin)
            if validationNotes.isEmpty {
                setMessage("已保存，菜单栏已更新。", kind: .success, autoClear: true)
            } else {
                setMessage(validationNotes.joined(separator: " "), kind: .warning)
            }
        } catch {
            setMessage("设置已保存，但开机自启更新失败：\(error.localizedDescription)", kind: .error)
        }

        NotificationCenter.default.post(name: .dianYiDianCounterDidChange, object: nil)
    }

    private func setMessage(_ text: String, kind: SettingsMessageKind, autoClear: Bool = false) {
        message = text
        messageKind = kind

        guard autoClear else {
            return
        }

        clearMessageTask?.cancel()
        clearMessageTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                if self?.message == text {
                    self?.message = nil
                }
            }
        }
    }
}
