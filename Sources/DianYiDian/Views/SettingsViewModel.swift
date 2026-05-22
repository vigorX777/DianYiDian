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
    @Published var applyInitialCountToToday = false
    @Published var message: String?
    @Published var messageKind: SettingsMessageKind = .success

    private let counterController: CounterController
    private let launchAtLoginService: LaunchAtLoginService
    private let shortcutWarningProvider: () -> String?
    private var savedLaunchAtLogin: Bool
    private var clearMessageTask: Task<Void, Never>?

    init(
        counterController: CounterController,
        launchAtLoginService: LaunchAtLoginService,
        shortcutWarningProvider: @escaping () -> String?
    ) {
        self.counterController = counterController
        self.launchAtLoginService = launchAtLoginService
        self.shortcutWarningProvider = shortcutWarningProvider

        let snapshot = counterController.snapshot
        let launchAtLoginEnabled = launchAtLoginService.isEnabled || snapshot.settings.launchAtLogin
        self.launchAtLogin = launchAtLoginEnabled
        self.savedLaunchAtLogin = launchAtLoginEnabled
        self.showIncrementFeedback = snapshot.settings.showIncrementFeedback
        self.notifyWhenGoalReached = snapshot.settings.notifyWhenGoalReached
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

        itemName = sanitizedName
        dailyTarget = sanitizedDailyTarget
        initialCount = sanitizedInitialCount

        scenario.name = sanitizedName
        scenario.dailyTarget = sanitizedDailyTarget
        scenario.initialCount = sanitizedInitialCount
        scenario.iconStyle = iconStyle
        scenario.themeColor = themeColor
        scenario.isEnabled = isEnabled
        scenario.isPinnedToMenuBar = isPinnedToMenuBar

        let shouldUpdateLaunchAtLogin = launchAtLogin != savedLaunchAtLogin
        let nextSettings = AppSettings(
            launchAtLogin: launchAtLogin,
            showIncrementFeedback: showIncrementFeedback,
            notifyWhenGoalReached: notifyWhenGoalReached,
            menuBarDisplayMode: menuBarDisplayMode,
            scenarioDisplayMode: scenarioDisplayMode
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
        applyInitialCountToToday = false
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
