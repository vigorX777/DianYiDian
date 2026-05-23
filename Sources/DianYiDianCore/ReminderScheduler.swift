import Foundation

public struct ReminderDecision: Equatable, Sendable {
    public var shouldRemind: Bool
    public var reason: ReminderMode

    public init(shouldRemind: Bool, reason: ReminderMode) {
        self.shouldRemind = shouldRemind
        self.reason = reason
    }
}

public struct ReminderScheduler: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func decision(
        scenario: CheckInScenario,
        state: ScenarioState,
        now: Date
    ) -> ReminderDecision {
        guard scenario.isEnabled,
              state.count < scenario.dailyTarget
        else {
            return ReminderDecision(shouldRemind: false, reason: scenario.reminderSettings.mode)
        }

        switch scenario.reminderSettings.mode {
        case .none:
            return ReminderDecision(shouldRemind: false, reason: .none)
        case .interval:
            return intervalDecision(scenario: scenario, state: state, now: now)
        case .fixedTime:
            return fixedTimeDecision(scenario: scenario, state: state, now: now)
        }
    }

    public func scenariosToRemind(
        snapshots: [CounterSnapshot],
        now: Date
    ) -> [CounterSnapshot] {
        snapshots.filter { snapshot in
            decision(scenario: snapshot.scenario, state: snapshot.state, now: now).shouldRemind
        }
    }

    private func intervalDecision(
        scenario: CheckInScenario,
        state: ScenarioState,
        now: Date
    ) -> ReminderDecision {
        let startOfToday = calendar.startOfDay(for: now)
        let lastActivity = state.lastCheckInAt ?? startOfToday
        let lastReminder = state.lastReminderSentAt ?? .distantPast
        let interval = TimeInterval(scenario.reminderSettings.intervalMinutes * 60)
        let dueAt = lastActivity.addingTimeInterval(interval)

        guard now >= dueAt,
              lastReminder < dueAt
        else {
            return ReminderDecision(shouldRemind: false, reason: .interval)
        }
        return ReminderDecision(shouldRemind: true, reason: .interval)
    }

    private func fixedTimeDecision(
        scenario: CheckInScenario,
        state: ScenarioState,
        now: Date
    ) -> ReminderDecision {
        let settings = scenario.reminderSettings
        let lastReminder = state.lastReminderSentAt ?? .distantPast
        let hasDueTime = settings.fixedTimes.contains { reminderTime in
            guard let dueAt = calendar.date(
                bySettingHour: reminderTime.hour,
                minute: reminderTime.minute,
                second: 0,
                of: now
            ) else {
                return false
            }
            return now >= dueAt && lastReminder < dueAt
        }

        guard hasDueTime else {
            return ReminderDecision(shouldRemind: false, reason: .fixedTime)
        }
        return ReminderDecision(shouldRemind: true, reason: .fixedTime)
    }
}
