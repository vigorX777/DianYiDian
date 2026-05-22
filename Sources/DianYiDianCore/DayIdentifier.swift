import Foundation

public protocol DayProviding: Sendable {
    func currentDayID() -> String
}

public struct SystemDayProvider: DayProviding {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func currentDayID() -> String {
        Self.dayID(for: Date(), calendar: calendar)
    }

    public static func dayID(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

public struct FixedDayProvider: DayProviding {
    private let dayID: String

    public init(dayID: String) {
        self.dayID = dayID
    }

    public func currentDayID() -> String {
        dayID
    }
}
