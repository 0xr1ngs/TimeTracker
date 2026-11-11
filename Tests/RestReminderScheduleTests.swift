import Foundation

@main
struct RestReminderScheduleTests {
    static func main() {
        var schedule = RestReminderSchedule()
        func next(_ elapsed: TimeInterval) -> RestReminderLevel? {
            schedule.nextReminder(elapsed: elapsed, enabled: true, isWorking: true)
        }
        assert(next(0) == nil)
        assert(next(1799) == nil)
        assert(next(1800) == .gentle)
        assert(next(1802) == nil)
        assert(next(2700) == nil)
        assert(next(3599) == nil)
        assert(next(3600) == .strong)
        assert(next(3602) == nil)
        assert(next(4499) == nil)
        assert(next(4500) == .strong)
        assert(next(5400) == .strong)
        assert(schedule.nextThreshold(elapsed: 5400) == 6300)

        schedule.reset()
        assert(next(7200) == .strong, "A delayed tick must deliver one strong reminder")
        assert(next(7201) == nil, "Do not replay missed reminders")
        schedule.snooze(elapsed: 7200)
        assert(schedule.nextThreshold(elapsed: 7200) == 7800)
        assert(next(7799) == nil)
        assert(next(7800) == .strong)
        assert(next(7802) == nil)
        assert(next(8699) == nil)
        assert(next(8700) == .strong)

        assert(schedule.nextReminder(elapsed: 9999, enabled: false, isWorking: true) == nil)
        assert(schedule.lastStrongElapsed == nil && schedule.snoozedUntilElapsed == nil)
        assert(schedule.nextReminder(elapsed: 9999, enabled: true, isWorking: false) == nil)
        assert(next(1800) == .gentle)
        schedule.reset()
        assert(next(1800) == .gentle, "A new work session has its own gentle reminder")
        assert(next(.nan) == nil)
        assert(next(.infinity) == nil)
        assert(next(-1) == nil)
        assert(next(1) == nil)
        assert(next(1800) == .gentle, "Returning to an early session clears previous delivery state")
        print("PASS: reminder thresholds, throttling, delayed ticks, snooze, repeats, reset and invalid input")
    }
}
