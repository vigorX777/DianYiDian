import Foundation

public enum CheckInType: String, Codable, Equatable, Sendable {
    case count
}

public enum ThemeColor: String, Codable, CaseIterable, Equatable, Sendable {
    case blue
    case teal
    case green
    case orange
    case purple
    case pink
    case gray

    public var displayName: String {
        switch self {
        case .blue: "蓝色"
        case .teal: "青色"
        case .green: "绿色"
        case .orange: "橙色"
        case .purple: "紫色"
        case .pink: "粉色"
        case .gray: "灰色"
        }
    }
}

public enum IconStyle: String, Codable, CaseIterable, Equatable, Sendable {
    case waterDrop
    case coffee
    case pill
    case figureWalk
    case figureStand
    case book
    case pencil
    case brain
    case moon
    case checklist
    case dot
    case checkmark
    case star

    public var displayName: String {
        switch self {
        case .waterDrop: "喝水"
        case .coffee: "咖啡"
        case .pill: "用药"
        case .figureWalk: "运动"
        case .figureStand: "站立"
        case .book: "阅读"
        case .pencil: "写作"
        case .brain: "学习"
        case .moon: "睡眠"
        case .checklist: "清单"
        case .dot: "圆点"
        case .checkmark: "对勾"
        case .star: "星标"
        }
    }

    public var symbolName: String {
        switch self {
        case .waterDrop: "drop.fill"
        case .coffee: "cup.and.saucer.fill"
        case .pill: "pills.fill"
        case .figureWalk: "figure.walk"
        case .figureStand: "figure.stand"
        case .book: "book.fill"
        case .pencil: "pencil"
        case .brain: "brain.head.profile"
        case .moon: "moon.fill"
        case .checklist: "checklist"
        case .dot: "circle.fill"
        case .checkmark: "checkmark"
        case .star: "star.fill"
        }
    }
}

public enum ReminderMode: String, Codable, CaseIterable, Equatable, Sendable {
    case none
    case interval
    case fixedTime

    public var displayName: String {
        switch self {
        case .none: "不提醒"
        case .interval: "每隔一段时间"
        case .fixedTime: "每天固定时间"
        }
    }
}

public struct ReminderTime: Codable, Equatable, Hashable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int = 10, minute: Int = 0) {
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
    }

    public var displayText: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

public struct ReminderSettings: Codable, Equatable, Sendable {
    public var mode: ReminderMode
    public var intervalMinutes: Int
    public var fixedHour: Int
    public var fixedMinute: Int
    public var fixedTimes: [ReminderTime]
    public var menuBarHintEnabled: Bool

    private enum CodingKeys: String, CodingKey {
        case mode
        case intervalMinutes
        case fixedHour
        case fixedMinute
        case fixedTimes
        case menuBarHintEnabled
    }

    public init(
        mode: ReminderMode = .none,
        intervalMinutes: Int = 60,
        fixedHour: Int = 10,
        fixedMinute: Int = 0,
        fixedTimes: [ReminderTime]? = nil,
        menuBarHintEnabled: Bool = true
    ) {
        let sanitizedFixedTimes = Self.sanitizeFixedTimes(fixedTimes ?? [ReminderTime(hour: fixedHour, minute: fixedMinute)])
        self.mode = mode
        self.intervalMinutes = max(1, intervalMinutes)
        self.fixedTimes = sanitizedFixedTimes
        self.fixedHour = sanitizedFixedTimes[0].hour
        self.fixedMinute = sanitizedFixedTimes[0].minute
        self.menuBarHintEnabled = menuBarHintEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            mode: try container.decodeIfPresent(ReminderMode.self, forKey: .mode) ?? .none,
            intervalMinutes: try container.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? 60,
            fixedHour: try container.decodeIfPresent(Int.self, forKey: .fixedHour) ?? 10,
            fixedMinute: try container.decodeIfPresent(Int.self, forKey: .fixedMinute) ?? 0,
            fixedTimes: try container.decodeIfPresent([ReminderTime].self, forKey: .fixedTimes),
            menuBarHintEnabled: try container.decodeIfPresent(Bool.self, forKey: .menuBarHintEnabled) ?? true
        )
    }

    private static func sanitizeFixedTimes(_ fixedTimes: [ReminderTime]) -> [ReminderTime] {
        let unique = Set(fixedTimes.map { ReminderTime(hour: $0.hour, minute: $0.minute) })
        let sorted = unique.sorted {
            if $0.hour == $1.hour {
                return $0.minute < $1.minute
            }
            return $0.hour < $1.hour
        }
        return sorted.isEmpty ? [ReminderTime()] : sorted
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

public struct CheckInScenario: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var type: CheckInType
    public var name: String
    public var dailyTarget: Int
    public var initialCount: Int
    public var iconStyle: IconStyle
    public var themeColor: ThemeColor
    public var reminderSettings: ReminderSettings
    public var isEnabled: Bool
    public var isPinnedToMenuBar: Bool
    public var sortOrder: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case dailyTarget
        case initialCount
        case iconStyle
        case themeColor
        case reminderSettings
        case isEnabled
        case isPinnedToMenuBar
        case sortOrder
    }

    public init(
        id: UUID = UUID(),
        type: CheckInType = .count,
        name: String = "喝水",
        dailyTarget: Int = 8,
        initialCount: Int = 0,
        iconStyle: IconStyle = .waterDrop,
        themeColor: ThemeColor = .blue,
        reminderSettings: ReminderSettings = ReminderSettings(),
        isEnabled: Bool = true,
        isPinnedToMenuBar: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.dailyTarget = dailyTarget
        self.initialCount = initialCount
        self.iconStyle = iconStyle
        self.themeColor = themeColor
        self.reminderSettings = reminderSettings
        self.isEnabled = isEnabled
        self.isPinnedToMenuBar = isPinnedToMenuBar
        self.sortOrder = sortOrder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            type: try container.decodeIfPresent(CheckInType.self, forKey: .type) ?? .count,
            name: try container.decodeIfPresent(String.self, forKey: .name) ?? "喝水",
            dailyTarget: try container.decodeIfPresent(Int.self, forKey: .dailyTarget) ?? 8,
            initialCount: try container.decodeIfPresent(Int.self, forKey: .initialCount) ?? 0,
            iconStyle: try container.decodeIfPresent(IconStyle.self, forKey: .iconStyle) ?? .waterDrop,
            themeColor: try container.decodeIfPresent(ThemeColor.self, forKey: .themeColor) ?? .blue,
            reminderSettings: try container.decodeIfPresent(ReminderSettings.self, forKey: .reminderSettings) ?? ReminderSettings(),
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true,
            isPinnedToMenuBar: try container.decodeIfPresent(Bool.self, forKey: .isPinnedToMenuBar) ?? false,
            sortOrder: try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        )
    }

    public init(item: CounterItem, id: UUID = UUID(), sortOrder: Int = 0) {
        self.init(
            id: id,
            name: item.name,
            dailyTarget: item.dailyTarget,
            initialCount: item.initialCount,
            iconStyle: item.iconStyle,
            themeColor: .blue,
            isEnabled: true,
            isPinnedToMenuBar: false,
            sortOrder: sortOrder
        )
    }

    public var counterItem: CounterItem {
        CounterItem(
            name: name,
            dailyTarget: dailyTarget,
            initialCount: initialCount,
            iconStyle: iconStyle
        )
    }
}

public struct ScenarioState: Codable, Equatable, Sendable {
    public var scenarioID: UUID
    public var dayID: String
    public var count: Int
    public var hasUndoableIncrement: Bool
    public var lastCheckInAt: Date?
    public var lastReminderSentAt: Date?

    private enum CodingKeys: String, CodingKey {
        case scenarioID
        case dayID
        case count
        case hasUndoableIncrement
        case lastCheckInAt
        case lastReminderSentAt
    }

    public init(
        scenarioID: UUID,
        dayID: String,
        count: Int = 0,
        hasUndoableIncrement: Bool = false,
        lastCheckInAt: Date? = nil,
        lastReminderSentAt: Date? = nil
    ) {
        self.scenarioID = scenarioID
        self.dayID = dayID
        self.count = count
        self.hasUndoableIncrement = hasUndoableIncrement
        self.lastCheckInAt = lastCheckInAt
        self.lastReminderSentAt = lastReminderSentAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            scenarioID: try container.decode(UUID.self, forKey: .scenarioID),
            dayID: try container.decode(String.self, forKey: .dayID),
            count: try container.decodeIfPresent(Int.self, forKey: .count) ?? 0,
            hasUndoableIncrement: try container.decodeIfPresent(Bool.self, forKey: .hasUndoableIncrement) ?? false,
            lastCheckInAt: try container.decodeIfPresent(Date.self, forKey: .lastCheckInAt),
            lastReminderSentAt: try container.decodeIfPresent(Date.self, forKey: .lastReminderSentAt)
        )
    }
}

public typealias CounterState = ScenarioState

public struct AppSettings: Codable, Equatable, Sendable {
    public var launchAtLogin: Bool
    public var showIncrementFeedback: Bool
    public var notifyWhenGoalReached: Bool
    public var menuBarDisplayMode: MenuBarDisplayMode
    public var scenarioDisplayMode: ScenarioDisplayMode
    public var checkInAnimationEnabled: Bool
    public var goalCelebrationEnabled: Bool

    private enum CodingKeys: String, CodingKey {
        case launchAtLogin
        case showIncrementFeedback
        case notifyWhenGoalReached
        case menuBarDisplayMode
        case scenarioDisplayMode
        case checkInAnimationEnabled
        case goalCelebrationEnabled
    }

    public init(
        launchAtLogin: Bool = false,
        showIncrementFeedback: Bool = true,
        notifyWhenGoalReached: Bool = true,
        menuBarDisplayMode: MenuBarDisplayMode = .iconAndText,
        scenarioDisplayMode: ScenarioDisplayMode = .currentScenario,
        checkInAnimationEnabled: Bool = true,
        goalCelebrationEnabled: Bool = true
    ) {
        self.launchAtLogin = launchAtLogin
        self.showIncrementFeedback = showIncrementFeedback
        self.notifyWhenGoalReached = notifyWhenGoalReached
        self.menuBarDisplayMode = menuBarDisplayMode
        self.scenarioDisplayMode = scenarioDisplayMode
        self.checkInAnimationEnabled = checkInAnimationEnabled
        self.goalCelebrationEnabled = goalCelebrationEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        self.showIncrementFeedback = try container.decodeIfPresent(Bool.self, forKey: .showIncrementFeedback) ?? true
        self.notifyWhenGoalReached = try container.decodeIfPresent(Bool.self, forKey: .notifyWhenGoalReached) ?? true
        self.menuBarDisplayMode = try container.decodeIfPresent(MenuBarDisplayMode.self, forKey: .menuBarDisplayMode) ?? .iconAndText
        self.scenarioDisplayMode = try container.decodeIfPresent(ScenarioDisplayMode.self, forKey: .scenarioDisplayMode) ?? .currentScenario
        self.checkInAnimationEnabled = try container.decodeIfPresent(Bool.self, forKey: .checkInAnimationEnabled) ?? true
        self.goalCelebrationEnabled = try container.decodeIfPresent(Bool.self, forKey: .goalCelebrationEnabled) ?? true
    }
}

public enum MenuBarDisplayMode: String, Codable, CaseIterable, Equatable, Sendable {
    case iconOnly
    case iconAndText

    public var displayName: String {
        switch self {
        case .iconOnly: "只显示图标"
        case .iconAndText: "图标 + 数字"
        }
    }
}

public enum ScenarioDisplayMode: String, Codable, CaseIterable, Equatable, Sendable {
    case currentScenario
    case pinnedScenarios

    public var displayName: String {
        switch self {
        case .currentScenario: "当前场景"
        case .pinnedScenarios: "固定场景多图标"
        }
    }
}

public struct HistoryRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var date: String
    public var scenarioID: UUID?
    public var itemName: String
    public var finalCount: Int
    public var targetCount: Int
    public var reachedGoal: Bool

    public init(
        id: UUID = UUID(),
        date: String,
        scenarioID: UUID? = nil,
        itemName: String,
        finalCount: Int,
        targetCount: Int,
        reachedGoal: Bool
    ) {
        self.id = id
        self.date = date
        self.scenarioID = scenarioID
        self.itemName = itemName
        self.finalCount = finalCount
        self.targetCount = targetCount
        self.reachedGoal = reachedGoal
    }
}
