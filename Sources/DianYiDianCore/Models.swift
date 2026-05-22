import Foundation

public enum IconStyle: String, Codable, CaseIterable, Equatable, Sendable {
    case waterDrop
    case dot
    case checkmark

    public var displayName: String {
        switch self {
        case .waterDrop:
            "水滴"
        case .dot:
            "圆点"
        case .checkmark:
            "对勾"
        }
    }
}

public struct CounterItem: Codable, Equatable, Sendable {
    public var name: String
    public var dailyTarget: Int
    public var initialCount: Int
    public var iconStyle: IconStyle

    public init(
        name: String = "喝水",
        dailyTarget: Int = 8,
        initialCount: Int = 0,
        iconStyle: IconStyle = .waterDrop
    ) {
        self.name = name
        self.dailyTarget = dailyTarget
        self.initialCount = initialCount
        self.iconStyle = iconStyle
    }
}

public struct CounterState: Codable, Equatable, Sendable {
    public var dayID: String
    public var count: Int
    public var hasUndoableIncrement: Bool

    public init(dayID: String, count: Int = 0, hasUndoableIncrement: Bool = false) {
        self.dayID = dayID
        self.count = count
        self.hasUndoableIncrement = hasUndoableIncrement
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var launchAtLogin: Bool
    public var showIncrementFeedback: Bool
    public var notifyWhenGoalReached: Bool
    public var menuBarDisplayMode: MenuBarDisplayMode

    private enum CodingKeys: String, CodingKey {
        case launchAtLogin
        case showIncrementFeedback
        case notifyWhenGoalReached
        case menuBarDisplayMode
    }

    public init(
        launchAtLogin: Bool = false,
        showIncrementFeedback: Bool = true,
        notifyWhenGoalReached: Bool = true,
        menuBarDisplayMode: MenuBarDisplayMode = .iconAndText
    ) {
        self.launchAtLogin = launchAtLogin
        self.showIncrementFeedback = showIncrementFeedback
        self.notifyWhenGoalReached = notifyWhenGoalReached
        self.menuBarDisplayMode = menuBarDisplayMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        self.showIncrementFeedback = try container.decodeIfPresent(Bool.self, forKey: .showIncrementFeedback) ?? true
        self.notifyWhenGoalReached = try container.decodeIfPresent(Bool.self, forKey: .notifyWhenGoalReached) ?? true
        self.menuBarDisplayMode = try container.decodeIfPresent(MenuBarDisplayMode.self, forKey: .menuBarDisplayMode) ?? .iconAndText
    }
}

public enum MenuBarDisplayMode: String, Codable, CaseIterable, Equatable, Sendable {
    case iconOnly
    case iconAndText

    public var displayName: String {
        switch self {
        case .iconOnly:
            "只显示图标"
        case .iconAndText:
            "图标 + 数字"
        }
    }
}

public struct HistoryRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var date: String
    public var itemName: String
    public var finalCount: Int
    public var targetCount: Int
    public var reachedGoal: Bool

    public init(
        id: UUID = UUID(),
        date: String,
        itemName: String,
        finalCount: Int,
        targetCount: Int,
        reachedGoal: Bool
    ) {
        self.id = id
        self.date = date
        self.itemName = itemName
        self.finalCount = finalCount
        self.targetCount = targetCount
        self.reachedGoal = reachedGoal
    }
}
