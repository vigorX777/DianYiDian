import Foundation

public struct DayProgress: Equatable, Sendable {
    public var dayID: String
    public var dayNumber: Int
    public var count: Int
    public var target: Int
    public var completionRatio: Double
    public var isToday: Bool
    public var isFuture: Bool
    public var hasRecord: Bool

    public init(
        dayID: String,
        dayNumber: Int,
        count: Int,
        target: Int,
        completionRatio: Double,
        isToday: Bool,
        isFuture: Bool,
        hasRecord: Bool
    ) {
        self.dayID = dayID
        self.dayNumber = dayNumber
        self.count = count
        self.target = target
        self.completionRatio = min(1, max(0, completionRatio))
        self.isToday = isToday
        self.isFuture = isFuture
        self.hasRecord = hasRecord
    }
}

public struct MonthProgress: Equatable, Sendable {
    public var monthID: String
    public var monthTitle: String
    public var weekdaySymbols: [String]
    public var leadingBlankCount: Int
    public var days: [DayProgress]

    public init(
        monthID: String,
        monthTitle: String,
        weekdaySymbols: [String],
        leadingBlankCount: Int,
        days: [DayProgress]
    ) {
        self.monthID = monthID
        self.monthTitle = monthTitle
        self.weekdaySymbols = weekdaySymbols
        self.leadingBlankCount = leadingBlankCount
        self.days = days
    }
}

public struct MonthProgressBuilder: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func build(
        snapshot: CounterSnapshot,
        historyRecords: [HistoryRecord],
        today: Date = Date()
    ) -> MonthProgress {
        var calendar = calendar
        calendar.firstWeekday = 2

        let todayDayID = SystemDayProvider.dayID(for: today, calendar: calendar)
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        let year = todayComponents.year ?? 1970
        let month = todayComponents.month ?? 1
        let monthID = String(format: "%04d-%02d", year, month)

        let startComponents = DateComponents(year: year, month: month, day: 1)
        let startOfMonth = calendar.date(from: startComponents) ?? today
        let dayRange = calendar.range(of: .day, in: .month, for: startOfMonth) ?? 1..<1
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingBlankCount = (firstWeekday - calendar.firstWeekday + 7) % 7

        let scenarioHistoryRecords = historyRecords.filter { record in
            if let scenarioID = record.scenarioID {
                return scenarioID == snapshot.scenario.id
            }
            return snapshot.scenarios.count == 1 || record.itemName == snapshot.scenario.name
        }
        let historyByDate = Dictionary(scenarioHistoryRecords.map { ($0.date, $0) }, uniquingKeysWith: { _, latest in latest })
        let days = dayRange.compactMap { day -> DayProgress? in
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
                return nil
            }
            let dayID = SystemDayProvider.dayID(for: date, calendar: calendar)
            let isToday = dayID == todayDayID
            let isFuture = date > today && !isToday

            if isToday {
                return makeDayProgress(
                    dayID: dayID,
                    dayNumber: day,
                    count: snapshot.state.count,
                    target: snapshot.scenario.dailyTarget,
                    isToday: true,
                    isFuture: false,
                    hasRecord: true
                )
            }

            if isFuture {
                return makeDayProgress(
                    dayID: dayID,
                    dayNumber: day,
                    count: 0,
                    target: snapshot.scenario.dailyTarget,
                    isToday: false,
                    isFuture: true,
                    hasRecord: false
                )
            }

            if let record = historyByDate[dayID] {
                return makeDayProgress(
                    dayID: dayID,
                    dayNumber: day,
                    count: record.finalCount,
                    target: record.targetCount,
                    isToday: false,
                    isFuture: false,
                    hasRecord: true
                )
            }

            return makeDayProgress(
                dayID: dayID,
                dayNumber: day,
                count: 0,
                target: snapshot.scenario.dailyTarget,
                isToday: false,
                isFuture: false,
                hasRecord: false
            )
        }

        return MonthProgress(
            monthID: monthID,
            monthTitle: "\(year)年\(month)月",
            weekdaySymbols: ["一", "二", "三", "四", "五", "六", "日"],
            leadingBlankCount: leadingBlankCount,
            days: days
        )
    }

    private func makeDayProgress(
        dayID: String,
        dayNumber: Int,
        count: Int,
        target: Int,
        isToday: Bool,
        isFuture: Bool,
        hasRecord: Bool
    ) -> DayProgress {
        let sanitizedTarget = max(1, target)
        let ratio = isFuture ? 0 : min(1, Double(max(0, count)) / Double(sanitizedTarget))
        return DayProgress(
            dayID: dayID,
            dayNumber: dayNumber,
            count: max(0, count),
            target: sanitizedTarget,
            completionRatio: ratio,
            isToday: isToday,
            isFuture: isFuture,
            hasRecord: hasRecord
        )
    }
}
