import AppKit
import DianYiDianCore

@MainActor
final class SoundFeedbackService {
    private let incrementSoundName = NSSound.Name("Pop")
    private let goalReachedSoundName = NSSound.Name("Glass")

    func playIncrementIfNeeded(settings: AppSettings) {
        guard settings.showIncrementFeedback else {
            return
        }
        NSSound(named: incrementSoundName)?.play()
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
        NSSound(named: goalReachedSoundName)?.play()
    }
}
