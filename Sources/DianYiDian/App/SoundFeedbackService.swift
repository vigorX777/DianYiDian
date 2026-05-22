import AppKit
import DianYiDianCore

@MainActor
final class SoundFeedbackService {
    private let incrementSound: NSSound?
    private let goalReachedSound: NSSound?

    init() {
        self.incrementSound = Self.loadSystemSound(named: "Ping")
        self.goalReachedSound = Self.loadSystemSound(named: "Glass")
        self.incrementSound?.volume = 1
        self.goalReachedSound?.volume = 1
    }

    func playIncrementIfNeeded(settings: AppSettings) {
        guard settings.showIncrementFeedback else {
            return
        }
        play(incrementSound)
    }

    func playGoalReachedIfNeeded(
        snapshot: CounterSnapshot,
        reachedGoalBeforeIncrement: Bool
    ) {
        guard snapshot.settings.notifyWhenGoalReached,
              snapshot.reachedGoal,
              !reachedGoalBeforeIncrement
        else {
            return
        }
        play(goalReachedSound)
    }

    private func play(_ sound: NSSound?) {
        guard let sound else {
            return
        }
        if sound.isPlaying {
            sound.stop()
        }
        sound.currentTime = 0
        sound.play()
    }

    private static func loadSystemSound(named name: String) -> NSSound? {
        let url = URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff")
        if let sound = NSSound(contentsOf: url, byReference: true) {
            return sound
        }
        return NSSound(named: NSSound.Name(name))
    }
}
