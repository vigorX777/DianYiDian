import DianYiDianCore
import Foundation
import UserNotifications

@MainActor
final class ReminderService: NSObject, UNUserNotificationCenterDelegate {
    private let counterController: CounterController
    private let scheduler = ReminderScheduler()
    private let center = UNUserNotificationCenter.current()
    private var timer: Timer?

    private(set) var notificationPermissionWarning: String?

    init(counterController: CounterController) {
        self.counterController = counterController
        super.init()
        center.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(counterDidChange),
            name: .dianYiDianCounterDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if center.delegate === self {
            center.delegate = nil
        }
    }

    func start() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncReminders()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        syncReminders()
    }

    func syncReminders(now: Date = Date()) {
        guard hasReminderEnabledScenario(now: now) else {
            notificationPermissionWarning = nil
            return
        }

        center.getNotificationSettings { [weak self] settings in
            let authorizationStatus = settings.authorizationStatus
            Task { @MainActor in
                guard let self else {
                    return
                }

                switch authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self.notificationPermissionWarning = nil
                    self.sendDueReminders(now: now)
                case .notDetermined:
                    self.notificationPermissionWarning = nil
                    self.requestAuthorizationIfNeeded()
                default:
                    self.notificationPermissionWarning = "需要在系统设置中允许通知。"
                    self.sendMenuBarOnlyReminders(now: now)
                }
            }
        }
    }

    @objc private func counterDidChange() {
        syncReminders()
    }

    private func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .notDetermined else {
                return
            }

            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                Task { @MainActor in
                    guard let self else {
                        return
                    }
                    self.notificationPermissionWarning = granted ? nil : "需要在系统设置中允许通知。"
                    if granted {
                        self.syncReminders()
                    }
                }
            }
        }
    }

    private func sendDueReminders(now: Date) {
        let snapshots = scheduler.scenariosToRemind(snapshots: counterController.reminderSnapshots(now: now), now: now)
        for snapshot in snapshots {
            deliverMenuBarHintIfNeeded(snapshot: snapshot)

            let content = UNMutableNotificationContent()
            content.title = snapshot.scenario.name
            content.body = "\(reminderVerb(for: snapshot.scenario.name))了"
            content.sound = .default
            content.userInfo = ["scenarioID": snapshot.scenario.id.uuidString]

            let identifier = "dianyidian.reminder.\(snapshot.scenario.id.uuidString).\(Int(now.timeIntervalSince1970))"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )

            center.add(request)
            { [weak self] error in
                Task { @MainActor in
                    guard let self else {
                        return
                    }
                    if let error {
                        self.notificationPermissionWarning = "提醒发送失败：\(error.localizedDescription)"
                        return
                    }
                    self.notificationPermissionWarning = nil
                    self.counterController.markReminderSent(scenarioID: snapshot.scenario.id, at: now)
                }
            }
        }
    }

    private func sendMenuBarOnlyReminders(now: Date) {
        let snapshots = scheduler.scenariosToRemind(snapshots: counterController.reminderSnapshots(now: now), now: now)
        for snapshot in snapshots where snapshot.scenario.reminderSettings.menuBarHintEnabled {
            deliverMenuBarHintIfNeeded(snapshot: snapshot)
            counterController.markReminderSent(scenarioID: snapshot.scenario.id, at: now)
        }
    }

    private func deliverMenuBarHintIfNeeded(snapshot: CounterSnapshot) {
        guard snapshot.scenario.reminderSettings.menuBarHintEnabled else {
            return
        }

        NotificationCenter.default.post(
            name: .dianYiDianReminderDidFire,
            object: self,
            userInfo: [
                "scenarioID": snapshot.scenario.id.uuidString,
                "scenarioName": snapshot.scenario.name
            ]
        )
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    private func hasReminderEnabledScenario(now: Date) -> Bool {
        counterController.reminderSnapshots(now: now).contains { snapshot in
            snapshot.scenario.isEnabled && snapshot.scenario.reminderSettings.mode != .none
        }
    }

    private func reminderVerb(for scenarioName: String) -> String {
        let trimmedName = scenarioName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return "该打卡"
        }
        if trimmedName.hasPrefix("喝") || trimmedName.hasPrefix("吃") || trimmedName.hasPrefix("运动") {
            return "该\(trimmedName)"
        }
        return "该\(trimmedName)"
    }
}
