import DianYiDianCore
import Foundation

@main
enum CoreChecks {
    static func main() throws {
        try defaultConfigurationIsCreatedOnFirstLaunch()
        try incrementAddsOneToTodayCount()
        try undoSubtractsOneWhenLastActionWasIncrement()
        try undoIsDisabledWhenCountIsZero()
        try resetUsesInitialCountAndClearsUndo()
        try progressCapsAtOneAfterTargetReached()
        try changingDailyTargetRecalculatesProgress()
        try rolloverArchivesPreviousDayAndResetsToday()
        try historyReadsInvalidFileAsEmptyRecords()
        print("DianYiDianCoreChecks passed")
    }

    private static func defaultConfigurationIsCreatedOnFirstLaunch() throws {
        let fixture = makeFixture()
        let controller = CounterController(
            store: fixture.store,
            dayProvider: FixedDayProvider(dayID: "2026-05-21")
        )

        check(controller.snapshot.item.name == "喝水", "default item name")
        check(controller.snapshot.item.dailyTarget == 8, "default daily target")
        check(controller.snapshot.item.initialCount == 0, "default initial count")
        check(controller.snapshot.state.dayID == "2026-05-21", "default day")
        check(controller.snapshot.state.count == 0, "default count")
        check(controller.snapshot.state.hasUndoableIncrement == false, "default undo flag")
    }

    private static func incrementAddsOneToTodayCount() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-21")
        )

        let snapshot = try controller.increment()

        check(snapshot.state.count == 1, "increment count")
        check(snapshot.state.hasUndoableIncrement, "increment undo flag")
    }

    private static func undoSubtractsOneWhenLastActionWasIncrement() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-21")
        )
        _ = try controller.increment()

        let snapshot = try controller.undoLastIncrement()

        check(snapshot.state.count == 0, "undo count")
        check(snapshot.state.hasUndoableIncrement == false, "undo flag")
    }

    private static func undoIsDisabledWhenCountIsZero() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-21")
        )

        let snapshot = try controller.undoLastIncrement()

        check(snapshot.state.count == 0, "disabled undo count")
        check(snapshot.state.hasUndoableIncrement == false, "disabled undo flag")
    }

    private static func resetUsesInitialCountAndClearsUndo() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-21")
        )
        try controller.updateItem(
            CounterItem(name: "喝水", dailyTarget: 8, initialCount: 2, iconStyle: .waterDrop),
            applyInitialCountToToday: false
        )
        _ = try controller.increment()

        let snapshot = try controller.resetToday()
        let undoSnapshot = try controller.undoLastIncrement()

        check(snapshot.state.count == 2, "reset count")
        check(snapshot.state.hasUndoableIncrement == false, "reset undo flag")
        check(undoSnapshot.state.count == 2, "reset cannot undo")
    }

    private static func progressCapsAtOneAfterTargetReached() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-21")
        )
        try controller.updateItem(
            CounterItem(name: "喝水", dailyTarget: 2, initialCount: 0, iconStyle: .waterDrop),
            applyInitialCountToToday: false
        )

        _ = try controller.increment()
        _ = try controller.increment()
        let snapshot = try controller.increment()

        check(snapshot.state.count == 3, "over target count")
        check(snapshot.progress == 1, "progress cap")
        check(snapshot.reachedGoal, "goal reached")
    }

    private static func changingDailyTargetRecalculatesProgress() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-21")
        )
        _ = try controller.increment()
        _ = try controller.increment()

        try controller.updateItem(
            CounterItem(name: "喝水", dailyTarget: 4, initialCount: 0, iconStyle: .waterDrop),
            applyInitialCountToToday: false
        )

        check(controller.snapshot.progress == 0.5, "target change progress")
    }

    private static func rolloverArchivesPreviousDayAndResetsToday() throws {
        let fixture = makeFixture()
        let controller = CounterController(
            store: fixture.store,
            dayProvider: FixedDayProvider(dayID: "2026-05-20")
        )
        try controller.updateItem(
            CounterItem(name: "喝水", dailyTarget: 2, initialCount: 1, iconStyle: .waterDrop),
            applyInitialCountToToday: false
        )
        _ = try controller.increment()
        _ = try controller.increment()

        controller.setDayProvider(FixedDayProvider(dayID: "2026-05-21"))
        let didRollover = try controller.rolloverIfNeeded()

        check(didRollover, "rollover happened")
        check(controller.snapshot.state.dayID == "2026-05-21", "rollover day")
        check(controller.snapshot.state.count == 1, "rollover reset count")
        check(controller.snapshot.state.hasUndoableIncrement == false, "rollover undo flag")

        let records = fixture.store.loadHistoryRecords()
        check(records.count == 1, "history count")
        check(records.first?.date == "2026-05-20", "history date")
        check(records.first?.itemName == "喝水", "history item")
        check(records.first?.finalCount == 2, "history final count")
        check(records.first?.targetCount == 2, "history target")
        check(records.first?.reachedGoal == true, "history goal")
    }

    private static func historyReadsInvalidFileAsEmptyRecords() throws {
        let fixture = makeFixture()
        try Data("not-json".utf8).write(to: fixture.historyURL)

        check(fixture.store.loadHistoryRecords() == [], "invalid history")
    }

    private static func makeFixture() -> (store: CounterStore, historyURL: URL) {
        let suiteName = "DianYiDianChecks-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DianYiDianChecks-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let historyURL = directory.appendingPathComponent("history.json")

        return (CounterStore(userDefaults: defaults, historyURL: historyURL), historyURL)
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ name: String) {
        guard condition() else {
            fatalError("Check failed: \(name)")
        }
    }
}
