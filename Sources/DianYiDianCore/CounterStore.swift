import Foundation

public enum CounterStoreError: Error, Equatable {
    case couldNotCreateStorageDirectory
}

public final class CounterStore {
    private enum Key {
        static let item = "dianyidian.item"
        static let state = "dianyidian.state"
        static let settings = "dianyidian.settings"
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
        if let state = load(CounterState.self, key: Key.state) {
            return state
        }
        let count = clampedInitialCount(item.initialCount)
        let state = CounterState(dayID: currentDayID, count: count, hasUndoableIncrement: false)
        saveState(state)
        return state
    }

    public func saveState(_ state: CounterState) {
        save(CounterState(
            dayID: state.dayID,
            count: max(0, min(999, state.count)),
            hasUndoableIncrement: state.hasUndoableIncrement
        ), key: Key.state)
    }

    public func appendHistoryRecord(_ record: HistoryRecord) throws {
        try ensureHistoryDirectory()
        var records = loadHistoryRecords()
        records.append(record)
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

    private func sanitized(_ item: CounterItem) -> CounterItem {
        CounterItem(
            name: item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "喝水" : item.name,
            dailyTarget: max(1, min(99, item.dailyTarget)),
            initialCount: clampedInitialCount(item.initialCount),
            iconStyle: item.iconStyle
        )
    }

    private func clampedInitialCount(_ count: Int) -> Int {
        max(0, min(99, count))
    }
}
