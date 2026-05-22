import Foundation

public struct CounterSnapshot: Equatable, Sendable {
    public var item: CounterItem
    public var state: CounterState
    public var settings: AppSettings

    public init(item: CounterItem, state: CounterState, settings: AppSettings) {
        self.item = item
        self.state = state
        self.settings = settings
    }

    public var progress: Double {
        guard item.dailyTarget > 0 else {
            return 1
        }
        return min(1, Double(state.count) / Double(item.dailyTarget))
    }

    public var reachedGoal: Bool {
        state.count >= item.dailyTarget
    }
}

public final class CounterController {
    private let store: CounterStore
    private var dayProvider: DayProviding

    public private(set) var item: CounterItem
    public private(set) var state: CounterState
    public private(set) var settings: AppSettings

    public init(store: CounterStore = CounterStore(), dayProvider: DayProviding = SystemDayProvider()) {
        self.store = store
        self.dayProvider = dayProvider
        self.item = store.loadItem()
        self.settings = store.loadSettings()
        self.state = store.loadState(currentDayID: dayProvider.currentDayID(), item: item)
        _ = try? rolloverIfNeeded()
    }

    public var snapshot: CounterSnapshot {
        CounterSnapshot(item: item, state: state, settings: settings)
    }

    public func setDayProvider(_ dayProvider: DayProviding) {
        self.dayProvider = dayProvider
    }

    @discardableResult
    public func increment() throws -> CounterSnapshot {
        try rolloverIfNeeded()
        state.count = min(999, state.count + 1)
        state.hasUndoableIncrement = true
        store.saveState(state)
        return snapshot
    }

    @discardableResult
    public func undoLastIncrement() throws -> CounterSnapshot {
        try rolloverIfNeeded()
        guard state.hasUndoableIncrement, state.count > 0 else {
            return snapshot
        }
        state.count -= 1
        state.hasUndoableIncrement = false
        store.saveState(state)
        return snapshot
    }

    @discardableResult
    public func resetToday() throws -> CounterSnapshot {
        try rolloverIfNeeded()
        state.count = item.initialCount
        state.hasUndoableIncrement = false
        store.saveState(state)
        return snapshot
    }

    public func updateItem(_ newItem: CounterItem, applyInitialCountToToday: Bool) throws {
        try rolloverIfNeeded()
        item = sanitized(newItem)
        store.saveItem(item)
        if applyInitialCountToToday {
            state.count = item.initialCount
            state.hasUndoableIncrement = false
            store.saveState(state)
        }
    }

    public func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        store.saveSettings(settings)
    }

    @discardableResult
    public func rolloverIfNeeded() throws -> Bool {
        let currentDayID = dayProvider.currentDayID()
        guard state.dayID != currentDayID else {
            return false
        }

        let record = HistoryRecord(
            date: state.dayID,
            itemName: item.name,
            finalCount: state.count,
            targetCount: item.dailyTarget,
            reachedGoal: state.count >= item.dailyTarget
        )
        try store.appendHistoryRecord(record)

        state = CounterState(
            dayID: currentDayID,
            count: item.initialCount,
            hasUndoableIncrement: false
        )
        store.saveState(state)
        return true
    }

    private func sanitized(_ item: CounterItem) -> CounterItem {
        CounterItem(
            name: item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "喝水" : item.name,
            dailyTarget: max(1, min(99, item.dailyTarget)),
            initialCount: max(0, min(99, item.initialCount)),
            iconStyle: item.iconStyle
        )
    }
}
