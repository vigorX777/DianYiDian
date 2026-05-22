import Foundation

public enum CounterStoreError: Error, Equatable {
    case couldNotCreateStorageDirectory
}

public final class CounterStore {
    private enum Key {
        static let item = "dianyidian.item"
        static let state = "dianyidian.state"
        static let settings = "dianyidian.settings"
        static let scenarios = "dianyidian.scenarios"
        static let scenarioStates = "dianyidian.scenarioStates"
        static let currentScenarioID = "dianyidian.currentScenarioID"
    }

    private let userDefaults: UserDefaults
    private let historyURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(userDefaults: UserDefaults = .standard, historyURL: URL? = nil) {
        self.userDefaults = userDefaults
        let baseURL = historyURL?.deletingLastPathComponent()
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("DianYiDian", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("DianYiDian", isDirectory: true)
        self.historyURL = historyURL ?? baseURL.appendingPathComponent("history.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public var historyFileURL: URL {
        historyURL
    }

    public func loadItem() -> CounterItem {
        load(CounterItem.self, key: Key.item) ?? CounterItem()
    }

    public func saveItem(_ item: CounterItem) {
        save(sanitized(item), key: Key.item)
    }

    public func loadSettings() -> AppSettings {
        load(AppSettings.self, key: Key.settings) ?? AppSettings()
    }

    public func saveSettings(_ settings: AppSettings) {
        save(settings, key: Key.settings)
    }

    public func loadState(currentDayID: String, item: CounterItem) -> CounterState {
        if let state = load(LegacyCounterState.self, key: Key.state) {
            return CounterState(
                scenarioID: UUID(),
                dayID: state.dayID,
                count: state.count,
                hasUndoableIncrement: state.hasUndoableIncrement
            )
        }
        return CounterState(scenarioID: UUID(), dayID: currentDayID, count: clampedInitialCount(item.initialCount))
    }

    public func saveState(_ state: CounterState) {
        let legacy = LegacyCounterState(
            dayID: state.dayID,
            count: max(0, min(999, state.count)),
            hasUndoableIncrement: state.hasUndoableIncrement
        )
        save(legacy, key: Key.state)
    }

    public func loadScenarios() -> [CheckInScenario] {
        if let scenarios = load([CheckInScenario].self, key: Key.scenarios), !scenarios.isEmpty {
            return sanitized(scenarios).sorted { $0.sortOrder < $1.sortOrder }
        }

        let scenario = CheckInScenario(item: loadItem())
        return [sanitized(scenario)]
    }

    public func saveScenarios(_ scenarios: [CheckInScenario]) {
        let sanitizedScenarios = sanitized(scenarios)
        save(sanitizedScenarios, key: Key.scenarios)
        if let firstEnabled = sanitizedScenarios.first(where: \.isEnabled),
           loadCurrentScenarioID(scenarios: sanitizedScenarios) == nil {
            saveCurrentScenarioID(firstEnabled.id)
        }
    }

    public func loadCurrentScenarioID(scenarios: [CheckInScenario]) -> UUID? {
        guard !scenarios.isEmpty else {
            return nil
        }

        if let idString = userDefaults.string(forKey: Key.currentScenarioID),
           let id = UUID(uuidString: idString),
           scenarios.contains(where: { $0.id == id && $0.isEnabled }) {
            return id
        }

        return scenarios.first(where: \.isEnabled)?.id ?? scenarios.first?.id
    }

    public func saveCurrentScenarioID(_ id: UUID) {
        userDefaults.set(id.uuidString, forKey: Key.currentScenarioID)
    }

    public func loadScenarioStates(currentDayID: String, scenarios: [CheckInScenario]) -> [ScenarioState] {
        if let states = load([ScenarioState].self, key: Key.scenarioStates), !states.isEmpty {
            return reconciled(states: states, currentDayID: currentDayID, scenarios: scenarios)
        }

        var states: [ScenarioState] = []
        if let firstScenario = scenarios.first {
            if let legacy = load(LegacyCounterState.self, key: Key.state) {
                states.append(ScenarioState(
                    scenarioID: firstScenario.id,
                    dayID: legacy.dayID,
                    count: legacy.count,
                    hasUndoableIncrement: legacy.hasUndoableIncrement
                ))
            } else {
                states.append(ScenarioState(
                    scenarioID: firstScenario.id,
                    dayID: currentDayID,
                    count: firstScenario.initialCount
                ))
            }
        }

        return reconciled(states: states, currentDayID: currentDayID, scenarios: scenarios)
    }

    public func saveScenarioStates(_ states: [ScenarioState]) {
        save(states.map(sanitized), key: Key.scenarioStates)
    }

    public func appendHistoryRecord(_ record: HistoryRecord) throws {
        try ensureHistoryDirectory()
        var records = loadHistoryRecords()
        records.append(record)
        let data = try encoder.encode(records)
        try data.write(to: historyURL, options: [.atomic])
    }

    public func appendHistoryRecords(_ newRecords: [HistoryRecord]) throws {
        guard !newRecords.isEmpty else {
            return
        }
        try ensureHistoryDirectory()
        var records = loadHistoryRecords()
        records.append(contentsOf: newRecords)
        let data = try encoder.encode(records)
        try data.write(to: historyURL, options: [.atomic])
    }

    public func loadHistoryRecords() -> [HistoryRecord] {
        guard FileManager.default.fileExists(atPath: historyURL.path),
              let data = try? Data(contentsOf: historyURL),
              !data.isEmpty,
              let records = try? decoder.decode([HistoryRecord].self, from: data)
        else {
            return []
        }
        return records
    }

    public func saveHistoryRecords(_ records: [HistoryRecord]) throws {
        try ensureHistoryDirectory()
        let data = try encoder.encode(records)
        try data.write(to: historyURL, options: [.atomic])
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        return try? decoder.decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else {
            return
        }
        userDefaults.set(data, forKey: key)
    }

    private func ensureHistoryDirectory() throws {
        let directory = historyURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw CounterStoreError.couldNotCreateStorageDirectory
        }
    }

    private func reconciled(
        states: [ScenarioState],
        currentDayID: String,
        scenarios: [CheckInScenario]
    ) -> [ScenarioState] {
        var statesByID = Dictionary(states.map { ($0.scenarioID, sanitized($0)) }, uniquingKeysWith: { _, latest in latest })
        for scenario in scenarios where statesByID[scenario.id] == nil {
            statesByID[scenario.id] = ScenarioState(
                scenarioID: scenario.id,
                dayID: currentDayID,
                count: clampedInitialCount(scenario.initialCount)
            )
        }
        return scenarios.compactMap { statesByID[$0.id] }
    }

    private func sanitized(_ item: CounterItem) -> CounterItem {
        CounterItem(
            name: item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "喝水" : item.name,
            dailyTarget: max(1, min(99, item.dailyTarget)),
            initialCount: clampedInitialCount(item.initialCount),
            iconStyle: item.iconStyle
        )
    }

    private func sanitized(_ scenarios: [CheckInScenario]) -> [CheckInScenario] {
        scenarios.enumerated().map { offset, scenario in
            var next = sanitized(scenario)
            if next.sortOrder < 0 {
                next.sortOrder = offset
            }
            return next
        }
    }

    private func sanitized(_ scenario: CheckInScenario) -> CheckInScenario {
        CheckInScenario(
            id: scenario.id,
            type: .count,
            name: scenario.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "喝水" : scenario.name,
            dailyTarget: max(1, min(99, scenario.dailyTarget)),
            initialCount: clampedInitialCount(scenario.initialCount),
            iconStyle: scenario.iconStyle,
            themeColor: scenario.themeColor,
            isEnabled: scenario.isEnabled,
            isPinnedToMenuBar: scenario.isPinnedToMenuBar,
            sortOrder: scenario.sortOrder
        )
    }

    private func sanitized(_ state: ScenarioState) -> ScenarioState {
        ScenarioState(
            scenarioID: state.scenarioID,
            dayID: state.dayID,
            count: max(0, min(999, state.count)),
            hasUndoableIncrement: state.hasUndoableIncrement
        )
    }

    private func clampedInitialCount(_ count: Int) -> Int {
        max(0, min(99, count))
    }
}

private struct LegacyCounterState: Codable {
    var dayID: String
    var count: Int
    var hasUndoableIncrement: Bool
}
