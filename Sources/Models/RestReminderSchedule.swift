import Foundation

enum RestReminderLevel {
    case gentle
    case strong
}

/// Uses elapsed work time so delayed timer ticks never replay a queue of alerts.
struct RestReminderSchedule {
    static let gentleThreshold: TimeInterval = 30 * 60
    static let strongThreshold: TimeInterval = 60 * 60
    static let repeatInterval: TimeInterval = 15 * 60
    static let snoozeInterval: TimeInterval = 10 * 60

    private(set) var gentleDelivered = false
    private(set) var lastStrongElapsed: TimeInterval?
    private(set) var snoozedUntilElapsed: TimeInterval?

    mutating func nextReminder(elapsed: TimeInterval, enabled: Bool, isWorking: Bool) -> RestReminderLevel? {
        guard enabled, isWorking else {
            reset()
            return nil
        }
        guard elapsed.isFinite, elapsed >= 0 else { return nil }
        if elapsed < Self.gentleThreshold {
            reset()
            return nil
        }
        if let until = snoozedUntilElapsed {
            guard elapsed >= until else { return nil }
            snoozedUntilElapsed = nil
            lastStrongElapsed = elapsed
            return .strong
        }
        if elapsed >= Self.strongThreshold {
            if let previous = lastStrongElapsed, elapsed - previous < Self.repeatInterval { return nil }
            lastStrongElapsed = elapsed
            return .strong
        }
        guard !gentleDelivered else { return nil }
        gentleDelivered = true
        return .gentle
    }

    mutating func snooze(elapsed: TimeInterval) {
        snoozedUntilElapsed = elapsed + Self.snoozeInterval
    }

    func nextThreshold(elapsed: TimeInterval) -> TimeInterval {
        if let until = snoozedUntilElapsed { return until }
        if elapsed < Self.gentleThreshold && !gentleDelivered { return Self.gentleThreshold }
        return lastStrongElapsed.map { $0 + Self.repeatInterval } ?? Self.strongThreshold
    }

    mutating func reset() {
        gentleDelivered = false
        lastStrongElapsed = nil
        snoozedUntilElapsed = nil
    }
}
