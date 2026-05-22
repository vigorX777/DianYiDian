import DianYiDianCore
import Foundation

@main
enum CoreChecks {
    static func main() throws {
        try defaultConfigurationIsCreatedOnFirstLaunch()
        try legacySettingsDecodeWithDefaultDisplayMode()
        try incrementAddsOneToTodayCount()
        try undoSubtractsOneWhenLastActionWasIncrement()
        try undoIsDisabledWhenCountIsZero()
        try resetUsesInitialCountAndClearsUndo()
        try addedScenariosKeepIndependentCounts()
        try selectingScenarioChangesCurrentSnapshot()
        try deactivatingCurrentScenarioSelectsAnotherEnabledScenario()
        try shortcutSelectionUsesEnabledScenarioOrder()
        try progressCapsAtOneAfterTargetReached()
        try changingDailyTargetRecalculatesProgress()
        try rolloverArchivesPreviousDayAndResetsToday()
        try rolloverArchivesEnabledScenariosIndependently()
        try historyReadsInvalidFileAsEmptyRecords()
        try monthProgressBuildsCurrentMonthDays()
        try monthProgressUsesMondayGridOffset()
        try monthProgressMapsHistoryAndToday()
        try monthProgressFiltersRecordsByScenario()
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
        check(controller.snapshot.settings.menuBarDisplayMode == .iconAndText, "default menu bar display mode")
        check(controller.snapshot.settings.scenarioDisplayMode == .currentScenario, "default scenario display mode")
        check(controller.snapshot.scenarios.count == 1, "default scenario count")
        check(controller.snapshot.scenario.name == "喝水", "default scenario name")
    }

    private static func legacySettingsDecodeWithDefaultDisplayMode() throws {
        let data = Data("""
        {
          "launchAtLogin" : true,
          "notifyWhenGoalReached" : false,
          "showIncrementFeedback" : true
        }
        """.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        check(settings.launchAtLogin, "legacy settings launch")
        check(settings.showIncrementFeedback, "legacy settings increment feedback")
        check(settings.notifyWhenGoalReached == false, "legacy settings goal feedback")
        check(settings.menuBarDisplayMode == .iconAndText, "legacy settings display mode default")
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

    private static func addedScenariosKeepIndependentCounts() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-21")
        )
        let defaultID = controller.currentScenarioID
        let writing = try controller.addScenario(CheckInScenario(name: "写作", dailyTarget: 3, iconStyle: .pencil))
        let writingID = writing.scenario.id

        _ = try controller.increment(scenarioID: defaultID)
        _ = try controller.increment(scenarioID: writingID)
        _ = try controller.increment(scenarioID: writingID)

        check(controller.snapshot(for: defaultID).state.count == 1, "default scenario independent count")
        check(controller.snapshot(for: writingID).state.count == 2, "added scenario independent count")
    }

    private static func selectingScenarioChangesCurrentSnapshot() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-21")
        )
        let snapshot = try controller.addScenario(CheckInScenario(name: "阅读", dailyTarget: 5, iconStyle: .book))

        controller.selectScenario(id: snapshot.scenario.id)

        check(controller.snapshot.scenario.name == "阅读", "select scenario")
    }

    private static func deactivatingCurrentScenarioSelectsAnotherEnabledScenario() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-21")
        )
        let defaultID = controller.currentScenarioID
        let snapshot = try controller.addScenario(CheckInScenario(name: "站立", dailyTarget: 6, iconStyle: .figureStand))
        controller.selectScenario(id: snapshot.scenario.id)

        try controller.deactivateScenario(id: snapshot.scenario.id)

        check(controller.currentScenarioID == defaultID, "deactivate current fallback")
        check(controller.snapshot.scenario.isEnabled, "fallback is enabled")
    }

    private static func shortcutSelectionUsesEnabledScenarioOrder() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-21")
        )
        _ = try controller.addScenario(CheckInScenario(name: "咖啡", dailyTarget: 2, iconStyle: .coffee))
        _ = try controller.addScenario(CheckInScenario(name: "学习", dailyTarget: 4, iconStyle: .brain))

        controller.selectScenarioByShortcutIndex(1)

        check(controller.snapshot.scenario.name == "咖啡", "shortcut selects second scenario")
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
        check(records.first?.scenarioID == controller.snapshot.scenario.id, "history scenario id")
        check(records.first?.finalCount == 2, "history final count")
        check(records.first?.targetCount == 2, "history target")
        check(records.first?.reachedGoal == true, "history goal")
    }

    private static func rolloverArchivesEnabledScenariosIndependently() throws {
        let fixture = makeFixture()
        let controller = CounterController(
            store: fixture.store,
            dayProvider: FixedDayProvider(dayID: "2026-05-20")
        )
        let defaultID = controller.currentScenarioID
        let writing = try controller.addScenario(CheckInScenario(name: "写作", dailyTarget: 2, iconStyle: .pencil))
        _ = try controller.increment(scenarioID: defaultID)
        _ = try controller.increment(scenarioID: writing.scenario.id)
        _ = try controller.increment(scenarioID: writing.scenario.id)

        controller.setDayProvider(FixedDayProvider(dayID: "2026-05-21"))
        _ = try controller.rolloverIfNeeded()

        let records = fixture.store.loadHistoryRecords()
        check(records.count == 2, "multi scenario history count")
        check(records.contains { $0.scenarioID == defaultID && $0.finalCount == 1 }, "default scenario history")
        check(records.contains { $0.scenarioID == writing.scenario.id && $0.finalCount == 2 && $0.reachedGoal }, "added scenario history")
        check(controller.snapshot(for: defaultID).state.dayID == "2026-05-21", "default scenario rollover day")
        check(controller.snapshot(for: writing.scenario.id).state.count == 0, "added scenario rollover count")
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

    private static func monthProgressFiltersRecordsByScenario() throws {
        let controller = CounterController(
            store: makeFixture().store,
            dayProvider: FixedDayProvider(dayID: "2026-05-22")
        )
        let waterID = controller.currentScenarioID
        let writing = try controller.addScenario(CheckInScenario(name: "写作", dailyTarget: 4, iconStyle: .pencil))
        let records = [
            HistoryRecord(date: "2026-05-01", scenarioID: waterID, itemName: "喝水", finalCount: 8, targetCount: 8, reachedGoal: true),
            HistoryRecord(date: "2026-05-01", scenarioID: writing.scenario.id, itemName: "写作", finalCount: 2, targetCount: 4, reachedGoal: false)
        ]

        let month = MonthProgressBuilder(calendar: gregorianCalendar()).build(
            snapshot: controller.snapshot(for: writing.scenario.id),
            historyRecords: records,
            today: makeDate(year: 2026, month: 5, day: 22)
        )

        check(month.days[0].count == 2, "scenario filtered history count")
        check(month.days[0].completionRatio == 0.5, "scenario filtered history ratio")
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
