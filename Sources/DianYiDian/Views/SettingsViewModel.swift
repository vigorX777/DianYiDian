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
    @Published var checkInAnimationEnabled: Bool
    @Published var goalCelebrationEnabled: Bool
    @Published var reminderSystemNotificationEnabled: Bool
    @Published var reminderMenuBarBubbleEnabled: Bool
    @Published var developerReminderBubbleDurationSeconds: Double
    @Published var menuBarDisplayMode: MenuBarDisplayMode
    @Published var scenarioDisplayMode: ScenarioDisplayMode
    @Published var scenarios: [CheckInScenario]
    @Published var selectedScenarioID: UUID? {
        didSet {
            guard oldValue != selectedScenarioID else {
                return
            }
            loadSelectedScenarioForm()
        }
    }
    @Published var itemName: String
    @Published var dailyTarget: Int
    @Published var initialCount: Int
    @Published var iconStyle: IconStyle
    @Published var themeColor: ThemeColor
    @Published var isEnabled: Bool
    @Published var isPinnedToMenuBar: Bool
    @Published var reminderMode: ReminderMode
    @Published var reminderIntervalMinutes: Int
    @Published var reminderFixedHour: Int
    @Published var reminderFixedMinute: Int
    @Published var reminderFixedTimes: [ReminderTime]
    @Published var reminderMenuBarHintEnabled: Bool
    @Published var applyInitialCountToToday = false
    @Published var message: String?
    @Published var messageKind: SettingsMessageKind = .success

    private let counterController: CounterController
    private let launchAtLoginService: LaunchAtLoginService
    private let shortcutWarningProvider: () -> String?
    private let notificationWarningProvider: () -> String?
    private var savedLaunchAtLogin: Bool
    private var clearMessageTask: Task<Void, Never>?

    init(
        counterController: CounterController,
        launchAtLoginService: LaunchAtLoginService,
        shortcutWarningProvider: @escaping () -> String?,
        notificationWarningProvider: @escaping () -> String?
    ) {
        self.counterController = counterController
        self.launchAtLoginService = launchAtLoginService
        self.shortcutWarningProvider = shortcutWarningProvider
        self.notificationWarningProvider = notificationWarningProvider

        let snapshot = counterController.snapshot
        let launchAtLoginEnabled = launchAtLoginService.isEnabled || snapshot.settings.launchAtLogin
        self.launchAtLogin = launchAtLoginEnabled
        self.savedLaunchAtLogin = launchAtLoginEnabled
        self.showIncrementFeedback = snapshot.settings.showIncrementFeedback
        self.notifyWhenGoalReached = snapshot.settings.notifyWhenGoalReached
        self.checkInAnimationEnabled = snapshot.settings.checkInAnimationEnabled
        self.goalCelebrationEnabled = snapshot.settings.goalCelebrationEnabled
        self.reminderSystemNotificationEnabled = snapshot.settings.reminderSystemNotificationEnabled
        self.reminderMenuBarBubbleEnabled = snapshot.settings.reminderMenuBarBubbleEnabled
        self.developerReminderBubbleDurationSeconds = snapshot.settings.developerReminderBubbleDurationSeconds
        self.menuBarDisplayMode = snapshot.settings.menuBarDisplayMode
        self.scenarioDisplayMode = snapshot.settings.scenarioDisplayMode
        self.scenarios = snapshot.scenarios
        self.selectedScenarioID = snapshot.scenario.id
        self.itemName = snapshot.scenario.name
        self.dailyTarget = snapshot.scenario.dailyTarget
        self.initialCount = snapshot.scenario.initialCount
        self.iconStyle = snapshot.scenario.iconStyle
        self.themeColor = snapshot.scenario.themeColor
        self.isEnabled = snapshot.scenario.isEnabled
        self.isPinnedToMenuBar = snapshot.scenario.isPinnedToMenuBar
        self.reminderMode = snapshot.scenario.reminderSettings.mode
        self.reminderIntervalMinutes = snapshot.scenario.reminderSettings.intervalMinutes
        self.reminderFixedHour = snapshot.scenario.reminderSettings.fixedHour
        self.reminderFixedMinute = snapshot.scenario.reminderSettings.fixedMinute
        self.reminderFixedTimes = snapshot.scenario.reminderSettings.fixedTimes
        self.reminderMenuBarHintEnabled = snapshot.scenario.reminderSettings.menuBarHintEnabled
    }

    deinit {
        clearMessageTask?.cancel()
    }

    var itemNameValidationMessage: String? {
        itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "保存时将使用默认名称“喝水”。"
            : nil
    }

    var shortcutWarning: String? {
        shortcutWarningProvider()
    }

    var notificationWarning: String? {
        notificationWarningProvider()
    }

    var selectedScenario: CheckInScenario? {
        guard let selectedScenarioID else {
            return nil
        }
        return scenarios.first { $0.id == selectedScenarioID }
    }

    func addScenario() {
        clearMessageTask?.cancel()
        let scenario = CheckInScenario(
            name: "新场景",
            dailyTarget: 1,
            initialCount: 0,
            iconStyle: .dot,
            themeColor: .blue,
            isEnabled: true,
            isPinnedToMenuBar: false
        )

        do {
            let snapshot = try counterController.addScenario(scenario)
            reloadFromController(selectedID: snapshot.scenario.id)
            setMessage("已新增场景。", kind: .success, autoClear: true)
            NotificationCenter.default.post(name: .dianYiDianCounterDidChange, object: nil)
        } catch {
            setMessage("新增失败：\(error.localizedDescription)", kind: .error)
        }
    }

    func deactivateSelectedScenario() {
        guard let selectedScenarioID else {
            return
        }

        do {
            try counterController.deactivateScenario(id: selectedScenarioID)
            reloadFromController(selectedID: counterController.currentScenarioID)
            setMessage("场景已停用，历史记录已保留。", kind: .warning)
            NotificationCenter.default.post(name: .dianYiDianCounterDidChange, object: nil)
        } catch {
            setMessage("停用失败：\(error.localizedDescription)", kind: .error)
        }
    }

    func save() {
        clearMessageTask?.cancel()
        message = nil
        messageKind = .success

        guard var scenario = selectedScenario else {
            setMessage("没有可保存的场景。", kind: .error)
            return
        }

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
        let sanitizedReminderInterval = max(1, reminderIntervalMinutes)
        let sanitizedReminderHour = max(0, min(23, reminderFixedHour))
        let sanitizedReminderMinute = max(0, min(59, reminderFixedMinute))
        let sanitizedFixedTimes = sanitizedReminderFixedTimes()
        if reminderIntervalMinutes != sanitizedReminderInterval {
            validationNotes.append("提醒间隔必须大于 0 分钟。")
        }
        if reminderFixedHour != sanitizedReminderHour || reminderFixedMinute != sanitizedReminderMinute || reminderFixedTimes != sanitizedFixedTimes {
            validationNotes.append("固定提醒时间已修正。")
        }
        let sanitizedBubbleDuration = AppSettings.sanitizeReminderBubbleDuration(developerReminderBubbleDurationSeconds)
        if developerReminderBubbleDurationSeconds != sanitizedBubbleDuration {
            validationNotes.append("轻提示显示秒数已限制在 0.5-10 秒。")
        }

        itemName = sanitizedName
        dailyTarget = sanitizedDailyTarget
        initialCount = sanitizedInitialCount
        reminderIntervalMinutes = sanitizedReminderInterval
        reminderFixedTimes = sanitizedFixedTimes
        reminderFixedHour = sanitizedFixedTimes[0].hour
        reminderFixedMinute = sanitizedFixedTimes[0].minute
        developerReminderBubbleDurationSeconds = sanitizedBubbleDuration

        scenario.name = sanitizedName
        scenario.dailyTarget = sanitizedDailyTarget
        scenario.initialCount = sanitizedInitialCount
        scenario.iconStyle = iconStyle
        scenario.themeColor = themeColor
        scenario.isEnabled = isEnabled
        scenario.isPinnedToMenuBar = isPinnedToMenuBar
        scenario.reminderSettings = ReminderSettings(
            mode: reminderMode,
            intervalMinutes: sanitizedReminderInterval,
            fixedHour: sanitizedFixedTimes[0].hour,
            fixedMinute: sanitizedFixedTimes[0].minute,
            fixedTimes: sanitizedFixedTimes,
            menuBarHintEnabled: reminderMenuBarHintEnabled
        )

        let shouldUpdateLaunchAtLogin = launchAtLogin != savedLaunchAtLogin
        let nextSettings = AppSettings(
            launchAtLogin: launchAtLogin,
            showIncrementFeedback: showIncrementFeedback,
            notifyWhenGoalReached: notifyWhenGoalReached,
            menuBarDisplayMode: menuBarDisplayMode,
            scenarioDisplayMode: scenarioDisplayMode,
            checkInAnimationEnabled: checkInAnimationEnabled,
            goalCelebrationEnabled: goalCelebrationEnabled,
            reminderSystemNotificationEnabled: reminderSystemNotificationEnabled,
            reminderMenuBarBubbleEnabled: reminderMenuBarBubbleEnabled,
            developerReminderBubbleDurationSeconds: sanitizedBubbleDuration
        )

        do {
            try counterController.updateScenario(scenario, applyInitialCountToToday: applyInitialCountToToday)
            counterController.updateSettings(nextSettings)
            reloadFromController(selectedID: counterController.currentScenarioID == scenario.id ? scenario.id : counterController.currentScenarioID)
        } catch {
            setMessage("保存失败：\(error.localizedDescription)", kind: .error)
            return
        }

        do {
            if shouldUpdateLaunchAtLogin {
                try launchAtLoginService.setEnabled(launchAtLogin)
                savedLaunchAtLogin = launchAtLogin
            }
            if validationNotes.isEmpty {
                setMessage("已保存，菜单栏已更新。", kind: .success, autoClear: true)
            } else {
                setMessage(validationNotes.joined(separator: " "), kind: .warning)
            }
        } catch {
            setMessage("设置已保存，但开机自启更新失败。", kind: .error)
        }

        NotificationCenter.default.post(name: .dianYiDianCounterDidChange, object: nil)
    }

    private func reloadFromController(selectedID: UUID?) {
        let snapshot = counterController.snapshot
        scenarios = snapshot.scenarios
        let launchAtLoginEnabled = launchAtLoginService.isEnabled || snapshot.settings.launchAtLogin
        launchAtLogin = launchAtLoginEnabled
        savedLaunchAtLogin = launchAtLoginEnabled
        showIncrementFeedback = snapshot.settings.showIncrementFeedback
        notifyWhenGoalReached = snapshot.settings.notifyWhenGoalReached
        checkInAnimationEnabled = snapshot.settings.checkInAnimationEnabled
        goalCelebrationEnabled = snapshot.settings.goalCelebrationEnabled
        reminderSystemNotificationEnabled = snapshot.settings.reminderSystemNotificationEnabled
        reminderMenuBarBubbleEnabled = snapshot.settings.reminderMenuBarBubbleEnabled
        developerReminderBubbleDurationSeconds = snapshot.settings.developerReminderBubbleDurationSeconds
        menuBarDisplayMode = snapshot.settings.menuBarDisplayMode
        scenarioDisplayMode = snapshot.settings.scenarioDisplayMode
        selectedScenarioID = selectedID ?? snapshot.scenario.id
        loadSelectedScenarioForm()
    }

    private func loadSelectedScenarioForm() {
        guard let scenario = selectedScenario else {
            return
        }
        itemName = scenario.name
        dailyTarget = scenario.dailyTarget
        initialCount = scenario.initialCount
        iconStyle = scenario.iconStyle
        themeColor = scenario.themeColor
        isEnabled = scenario.isEnabled
        isPinnedToMenuBar = scenario.isPinnedToMenuBar
        reminderMode = scenario.reminderSettings.mode
        reminderIntervalMinutes = scenario.reminderSettings.intervalMinutes
        reminderFixedHour = scenario.reminderSettings.fixedHour
        reminderFixedMinute = scenario.reminderSettings.fixedMinute
        reminderFixedTimes = scenario.reminderSettings.fixedTimes
        reminderMenuBarHintEnabled = scenario.reminderSettings.menuBarHintEnabled
        applyInitialCountToToday = false
    }

    func addFixedReminderTime() {
        let lastTime = reminderFixedTimes.last ?? ReminderTime()
        let nextMinute = lastTime.minute + 1
        let nextTime = ReminderTime(
            hour: nextMinute >= 60 ? min(23, lastTime.hour + 1) : lastTime.hour,
            minute: nextMinute >= 60 ? 0 : nextMinute
        )
        reminderFixedTimes.append(nextTime)
    }

    func removeFixedReminderTime(at index: Int) {
        guard reminderFixedTimes.indices.contains(index),
              reminderFixedTimes.count > 1
        else {
            return
        }
        reminderFixedTimes.remove(at: index)
    }

    private func sanitizedReminderFixedTimes() -> [ReminderTime] {
        let unique = Set(reminderFixedTimes.map { ReminderTime(hour: $0.hour, minute: $0.minute) })
        let sorted = unique.sorted {
            if $0.hour == $1.hour {
                return $0.minute < $1.minute
            }
            return $0.hour < $1.hour
        }
        return sorted.isEmpty ? [ReminderTime()] : sorted
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
