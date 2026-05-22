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
        try monthProgressBuildsCurrentMonthDays()
        try monthProgressUsesMondayGridOffset()
        try monthProgressMapsHistoryAndToday()
        try monthProgressMarksFutureDaysAndCapsRatio()
        try monthProgressBuildsWithEmptyHistory()
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

    private static func monthProgressBuildsCurrentMonthDays() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-22")
        )
        let today = makeDate(year: 2026, month: 5, day: 22)
        let month = MonthProgressBuilder(calendar: gregorianCalendar()).build(
            snapshot: controller.snapshot,
            historyRecords: [],
            today: today
        )

        check(month.monthID == "2026-05", "month id")
        check(month.monthTitle == "2026年5月", "month title")
        check(month.days.count == 31, "month days")
        check(month.days.first?.dayNumber == 1, "first day")
        check(month.days.last?.dayNumber == 31, "last day")
    }

    private static func monthProgressUsesMondayGridOffset() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-22")
        )
        let month = MonthProgressBuilder(calendar: gregorianCalendar()).build(
            snapshot: controller.snapshot,
            historyRecords: [],
            today: makeDate(year: 2026, month: 5, day: 22)
        )

        check(month.weekdaySymbols == ["一", "二", "三", "四", "五", "六", "日"], "weekday symbols")
        check(month.leadingBlankCount == 4, "monday grid offset")
    }

    private static func monthProgressMapsHistoryAndToday() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-22")
        )
        try controller.updateItem(
            CounterItem(name: "喝水", dailyTarget: 8, initialCount: 0, iconStyle: .waterDrop),
            applyInitialCountToToday: false
        )
        _ = try controller.increment()
        _ = try controller.increment()
        _ = try controller.increment()

        let records = [
            HistoryRecord(date: "2026-05-01", itemName: "喝水", finalCount: 4, targetCount: 8, reachedGoal: false),
            HistoryRecord(date: "2026-05-02", itemName: "喝水", finalCount: 9, targetCount: 8, reachedGoal: true)
        ]
        let month = MonthProgressBuilder(calendar: gregorianCalendar()).build(
            snapshot: controller.snapshot,
            historyRecords: records,
            today: makeDate(year: 2026, month: 5, day: 22)
        )

        let first = month.days[0]
        let second = month.days[1]
        let today = month.days[21]

        check(first.count == 4, "history count")
        check(first.completionRatio == 0.5, "history partial ratio")
        check(first.hasRecord, "history has record")
        check(second.completionRatio == 1, "history capped complete")
        check(today.isToday, "today marker")
        check(today.count == 3, "today count")
        check(today.completionRatio == 0.375, "today ratio")
    }

    private static func monthProgressMarksFutureDaysAndCapsRatio() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-22")
        )
        let records = [
            HistoryRecord(date: "2026-05-21", itemName: "喝水", finalCount: 12, targetCount: 8, reachedGoal: true)
        ]
        let month = MonthProgressBuilder(calendar: gregorianCalendar()).build(
            snapshot: controller.snapshot,
            historyRecords: records,
            today: makeDate(year: 2026, month: 5, day: 22)
        )

        let yesterday = month.days[20]
        let tomorrow = month.days[22]

        check(yesterday.completionRatio == 1, "past capped ratio")
        check(tomorrow.isFuture, "future marker")
        check(tomorrow.completionRatio == 0, "future no water")
        check(tomorrow.hasRecord == false, "future no record")
    }

    private static func monthProgressBuildsWithEmptyHistory() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-22")
        )
        let month = MonthProgressBuilder(calendar: gregorianCalendar()).build(
            snapshot: controller.snapshot,
            historyRecords: [],
            today: makeDate(year: 2026, month: 5, day: 22)
        )

        check(month.days.count == 31, "empty history month days")
        check(month.days[0].hasRecord == false, "empty history no past record")
        check(month.days[21].isToday, "empty history still has today")
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

    private static func gregorianCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        calendar.locale = Locale(identifier: "zh_CN")
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        gregorianCalendar().date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
