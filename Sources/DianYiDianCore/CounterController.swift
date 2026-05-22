import Foundation

public struct CounterSnapshot: Equatable, Sendable {
    public var scenario: CheckInScenario
    public var state: ScenarioState
    public var scenarios: [CheckInScenario]
    public var states: [ScenarioState]
    public var settings: AppSettings

    public init(
        scenario: CheckInScenario,
        state: ScenarioState,
        scenarios: [CheckInScenario],
        states: [ScenarioState],
        settings: AppSettings
    ) {
        self.scenario = scenario
        self.state = state
        self.scenarios = scenarios
        self.states = states
        self.settings = settings
    }

    public var item: CounterItem {
        scenario.counterItem
    }

    public var progress: Double {
        guard scenario.dailyTarget > 0 else {
            return 1
        }
        return min(1, Double(state.count) / Double(scenario.dailyTarget))
    }

    public var reachedGoal: Bool {
        state.count >= scenario.dailyTarget
    }
}

public final class CounterController {
    private let store: CounterStore
    private var dayProvider: DayProviding

    public private(set) var scenarios: [CheckInScenario]
    public private(set) var states: [UUID: ScenarioState]
    public private(set) var currentScenarioID: UUID
    public private(set) var settings: AppSettings

    public var item: CounterItem {
        currentScenario.counterItem
    }

    public var state: CounterState {
        currentState
    }

    public init(store: CounterStore = CounterStore(), dayProvider: DayProviding = SystemDayProvider()) {
        self.store = store
        self.dayProvider = dayProvider
        self.scenarios = store.loadScenarios()
        self.settings = store.loadSettings()
        let loadedCurrentID = store.loadCurrentScenarioID(scenarios: scenarios)
        self.currentScenarioID = loadedCurrentID ?? scenarios.first?.id ?? CheckInScenario().id
        let loadedStates = store.loadScenarioStates(
            currentDayID: dayProvider.currentDayID(),
            scenarios: scenarios
        )
        self.states = Dictionary(loadedStates.map { ($0.scenarioID, $0) }, uniquingKeysWith: { _, latest in latest })
        ensureUsableScenario()
        persistScenarioData()
        _ = try? rolloverIfNeeded()
    }

    public var snapshot: CounterSnapshot {
        snapshot(for: currentScenarioID)
    }

    public var enabledScenarios: [CheckInScenario] {
        scenarios.filter(\.isEnabled).sorted { $0.sortOrder < $1.sortOrder }
    }

    public var pinnedScenarios: [CheckInScenario] {
        enabledScenarios.filter(\.isPinnedToMenuBar)
    }

    public func setDayProvider(_ dayProvider: DayProviding) {
        self.dayProvider = dayProvider
    }

    public func snapshot(for scenarioID: UUID) -> CounterSnapshot {
        let scenario = scenario(withID: scenarioID) ?? currentScenario
        let state = state(for: scenario.id)
        return CounterSnapshot(
            scenario: scenario,
            state: state,
            scenarios: scenarios,
            states: orderedStates,
            settings: settings
        )
    }

    @discardableResult
    public func increment() throws -> CounterSnapshot {
        try increment(scenarioID: currentScenarioID)
    }

    @discardableResult
    public func increment(scenarioID: UUID) throws -> CounterSnapshot {
        try rolloverIfNeeded()
        guard let scenario = scenario(withID: scenarioID), scenario.isEnabled else {
            return snapshot
        }
        var nextState = state(for: scenario.id)
        nextState.count = min(999, nextState.count + 1)
        nextState.hasUndoableIncrement = true
        states[scenario.id] = nextState
        store.saveScenarioStates(orderedStates)
        return snapshot(for: scenario.id)
    }

    @discardableResult
    public func undoLastIncrement() throws -> CounterSnapshot {
        try undoLastIncrement(scenarioID: currentScenarioID)
    }

    @discardableResult
    public func undoLastIncrement(scenarioID: UUID) throws -> CounterSnapshot {
        try rolloverIfNeeded()
        guard let scenario = scenario(withID: scenarioID), scenario.isEnabled else {
            return snapshot
        }
        var nextState = state(for: scenario.id)
        guard nextState.hasUndoableIncrement, nextState.count > 0 else {
            return snapshot(for: scenario.id)
        }
        nextState.count -= 1
        nextState.hasUndoableIncrement = false
        states[scenario.id] = nextState
        store.saveScenarioStates(orderedStates)
        return snapshot(for: scenario.id)
    }

    @discardableResult
    public func resetToday() throws -> CounterSnapshot {
        try resetToday(scenarioID: currentScenarioID)
    }

    @discardableResult
    public func resetToday(scenarioID: UUID) throws -> CounterSnapshot {
        try rolloverIfNeeded()
        guard let scenario = scenario(withID: scenarioID), scenario.isEnabled else {
            return snapshot
        }
        states[scenario.id] = ScenarioState(
            scenarioID: scenario.id,
            dayID: dayProvider.currentDayID(),
            count: scenario.initialCount,
            hasUndoableIncrement: false
        )
        store.saveScenarioStates(orderedStates)
        return snapshot(for: scenario.id)
    }

    public func updateItem(_ newItem: CounterItem, applyInitialCountToToday: Bool) throws {
        var scenario = currentScenario
        scenario.name = newItem.name
        scenario.dailyTarget = newItem.dailyTarget
        scenario.initialCount = newItem.initialCount
        scenario.iconStyle = newItem.iconStyle
        try updateScenario(scenario, applyInitialCountToToday: applyInitialCountToToday)
    }

    @discardableResult
    public func addScenario(_ scenario: CheckInScenario) throws -> CounterSnapshot {
        try rolloverIfNeeded()
        var next = sanitized(scenario)
        let nextOrder = (scenarios.map(\.sortOrder).max() ?? -1) + 1
        next.sortOrder = nextOrder
        scenarios.append(next)
        states[next.id] = ScenarioState(
            scenarioID: next.id,
            dayID: dayProvider.currentDayID(),
            count: next.initialCount
        )
        currentScenarioID = next.id
        persistScenarioData()
        return snapshot
    }

    public func updateScenario(_ scenario: CheckInScenario, applyInitialCountToToday: Bool) throws {
        try rolloverIfNeeded()
        let next = sanitized(scenario)
        guard let index = scenarios.firstIndex(where: { $0.id == next.id }) else {
            return
        }
        scenarios[index] = next
        if applyInitialCountToToday {
            states[next.id] = ScenarioState(
                scenarioID: next.id,
                dayID: dayProvider.currentDayID(),
                count: next.initialCount,
                hasUndoableIncrement: false
            )
        }
        ensureUsableScenario()
        persistScenarioData()
    }

    public func deactivateScenario(id: UUID) throws {
        try rolloverIfNeeded()
        guard let index = scenarios.firstIndex(where: { $0.id == id }) else {
            return
        }
        scenarios[index].isEnabled = false
        scenarios[index].isPinnedToMenuBar = false
        ensureUsableScenario()
        persistScenarioData()
    }

    public func selectScenario(id: UUID) {
        guard let scenario = scenario(withID: id), scenario.isEnabled else {
            return
        }
        currentScenarioID = id
        store.saveCurrentScenarioID(id)
    }

    public func selectScenarioByShortcutIndex(_ index: Int) {
        let sortedScenarios = enabledScenarios
        guard index >= 0, index < sortedScenarios.count, index < 9 else {
            return
        }
        selectScenario(id: sortedScenarios[index].id)
    }

    public func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        store.saveSettings(settings)
    }

    public func currentMonthProgress(today: Date = Date()) -> MonthProgress {
        currentMonthProgress(scenarioID: currentScenarioID, today: today)
    }

    public func currentMonthProgress(scenarioID: UUID, today: Date = Date()) -> MonthProgress {
        MonthProgressBuilder().build(
            snapshot: snapshot(for: scenarioID),
            historyRecords: store.loadHistoryRecords(),
            today: today
        )
    }

    @discardableResult
    public func rolloverIfNeeded() throws -> Bool {
        let currentDayID = dayProvider.currentDayID()
        let staleStates = orderedStates.filter { $0.dayID != currentDayID }
        guard !staleStates.isEmpty else {
            return false
        }

        let records = staleStates.compactMap { state -> HistoryRecord? in
            guard let scenario = scenario(withID: state.scenarioID) else {
                return nil
            }
            guard scenario.isEnabled else {
                return nil
            }
            return HistoryRecord(
                date: state.dayID,
                scenarioID: scenario.id,
                itemName: scenario.name,
                finalCount: state.count,
                targetCount: scenario.dailyTarget,
                reachedGoal: state.count >= scenario.dailyTarget
            )
        }
        try store.appendHistoryRecords(records)

        for scenario in scenarios {
            states[scenario.id] = ScenarioState(
                scenarioID: scenario.id,
                dayID: currentDayID,
                count: scenario.initialCount,
                hasUndoableIncrement: false
            )
        }
        store.saveScenarioStates(orderedStates)
        return true
    }

    private var currentScenario: CheckInScenario {
        scenario(withID: currentScenarioID)
            ?? enabledScenarios.first
            ?? scenarios.first
            ?? CheckInScenario()
    }

    private var currentState: ScenarioState {
        state(for: currentScenario.id)
    }

    private var orderedStates: [ScenarioState] {
        scenarios.map { state(for: $0.id) }
    }

    private func scenario(withID id: UUID) -> CheckInScenario? {
        scenarios.first { $0.id == id }
    }

    private func state(for scenarioID: UUID) -> ScenarioState {
        if let state = states[scenarioID] {
            return state
        }
        let scenario = scenario(withID: scenarioID) ?? CheckInScenario(id: scenarioID)
        return ScenarioState(
            scenarioID: scenarioID,
            dayID: dayProvider.currentDayID(),
            count: scenario.initialCount
        )
    }

    private func ensureUsableScenario() {
        if scenarios.isEmpty {
            scenarios = [CheckInScenario()]
        }
        if !scenarios.contains(where: \.isEnabled) {
            scenarios[0].isEnabled = true
        }
        if !scenarios.contains(where: { $0.id == currentScenarioID && $0.isEnabled }) {
            currentScenarioID = enabledScenarios.first?.id ?? scenarios[0].id
        }
        for scenario in scenarios where states[scenario.id] == nil {
            states[scenario.id] = ScenarioState(
                scenarioID: scenario.id,
                dayID: dayProvider.currentDayID(),
                count: scenario.initialCount
            )
        }
    }

    private func persistScenarioData() {
        scenarios = scenarios.sorted { $0.sortOrder < $1.sortOrder }
        store.saveScenarios(scenarios)
        store.saveScenarioStates(orderedStates)
        store.saveCurrentScenarioID(currentScenarioID)
    }

    private func sanitized(_ scenario: CheckInScenario) -> CheckInScenario {
        CheckInScenario(
            id: scenario.id,
            type: .count,
            name: scenario.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "喝水" : scenario.name,
            dailyTarget: max(1, min(99, scenario.dailyTarget)),
            initialCount: max(0, min(99, scenario.initialCount)),
            iconStyle: scenario.iconStyle,
            themeColor: scenario.themeColor,
            isEnabled: scenario.isEnabled,
            isPinnedToMenuBar: scenario.isPinnedToMenuBar,
            sortOrder: scenario.sortOrder
        )
    }
}
