import AppKit
import UserNotifications

/// Three sub-modes: stopwatch, countdown, world clock. State lives on
/// the mode (not the view) so timers keep ticking when the user
/// switches mode or hides the window.
final class TimerMode: Mode {
    let id: String
    let displayName: String
    var preferredSize: NSSize? = NSSize(width: 380, height: 260)

    enum SubMode: String, CaseIterable { case stopwatch, countdown, worldClock }

    // Persistent across view lifetime
    var currentSubMode: SubMode
    let worldClocks: [String]

    // Stopwatch state
    private(set) var stopwatchElapsed: TimeInterval = 0
    private(set) var stopwatchRunning: Bool = false
    private var stopwatchResumeAt: Date?
    private(set) var stopwatchLaps: [TimeInterval] = []

    // Countdown state
    private(set) var countdownTotal: TimeInterval = 5 * 60   // last entered duration
    private(set) var countdownEndAt: Date?                   // nil = not running
    private(set) var countdownPausedRemaining: TimeInterval? // non-nil = paused

    private lazy var rootView = TimerView(mode: self)
    private var pendingCountdownNotification: String?

    init(id: String, displayName: String, defaultSubMode: SubMode, worldClocks: [String]) {
        self.id = id
        self.displayName = displayName
        self.currentSubMode = defaultSubMode
        self.worldClocks = worldClocks
    }

    func view() -> NSView { rootView }

    func activate() {
        rootView.refresh()
    }

    func deactivate() {
        // Keep ticking — stopwatch and countdown continue in the background.
    }

    func windowDidShow() {
        rootView.refresh()
    }

    func windowDidHide() {
        // No-op; background work continues.
    }

    // MARK: - Stopwatch

    var stopwatchCurrentElapsed: TimeInterval {
        if let resume = stopwatchResumeAt, stopwatchRunning {
            return stopwatchElapsed + Date().timeIntervalSince(resume)
        }
        return stopwatchElapsed
    }

    func stopwatchStartStop() {
        if stopwatchRunning {
            if let resume = stopwatchResumeAt {
                stopwatchElapsed += Date().timeIntervalSince(resume)
            }
            stopwatchResumeAt = nil
            stopwatchRunning = false
        } else {
            stopwatchResumeAt = Date()
            stopwatchRunning = true
        }
    }

    func stopwatchLap() {
        guard stopwatchRunning else { return }
        stopwatchLaps.append(stopwatchCurrentElapsed)
    }

    func stopwatchReset() {
        stopwatchElapsed = 0
        stopwatchResumeAt = nil
        stopwatchRunning = false
        stopwatchLaps.removeAll()
    }

    // MARK: - Countdown

    var countdownIsRunning: Bool { countdownEndAt != nil }
    var countdownIsPaused: Bool { countdownPausedRemaining != nil }

    var countdownRemaining: TimeInterval {
        if let paused = countdownPausedRemaining { return paused }
        if let end = countdownEndAt { return max(0, end.timeIntervalSinceNow) }
        return countdownTotal
    }

    func countdownStart(total: TimeInterval) {
        countdownTotal = total
        countdownEndAt = Date().addingTimeInterval(total)
        countdownPausedRemaining = nil
        scheduleCountdownNotification(remaining: total)
    }

    func countdownPauseResume() {
        if let end = countdownEndAt {
            countdownPausedRemaining = max(0, end.timeIntervalSinceNow)
            countdownEndAt = nil
            cancelCountdownNotification()
        } else if let paused = countdownPausedRemaining {
            countdownEndAt = Date().addingTimeInterval(paused)
            countdownPausedRemaining = nil
            scheduleCountdownNotification(remaining: paused)
        }
    }

    func countdownReset() {
        countdownEndAt = nil
        countdownPausedRemaining = nil
        cancelCountdownNotification()
    }

    func countdownDidComplete() {
        countdownEndAt = nil
        NSSound.beep()
    }

    private func scheduleCountdownNotification(remaining: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        let content = UNMutableNotificationContent()
        content.title = "SWS timer"
        content.body = "Countdown finished"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(0.1, remaining),
            repeats: false
        )
        let id = "sws.countdown.\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                NSLog("SWS: notification schedule failed: \(error)")
            }
        }
        if let prev = pendingCountdownNotification {
            center.removePendingNotificationRequests(withIdentifiers: [prev])
        }
        pendingCountdownNotification = id
    }

    private func cancelCountdownNotification() {
        if let id = pendingCountdownNotification {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: [id])
            pendingCountdownNotification = nil
        }
    }
}

enum TimerModeFactory: ModeFactory {
    static let typeId = "timer"

    static func make(instance: ModeInstanceConfig, appPrefs: AppPrefs) throws -> Mode {
        let defaultSub = (instance.raw["defaultSubMode"] as? String)
            .flatMap { TimerMode.SubMode(rawValue: $0) } ?? .countdown
        let clocks = (instance.raw["worldClocks"] as? [String]) ?? ["UTC+0"]
        let displayName = (instance.raw["displayName"] as? String) ?? instance.id.capitalized
        return TimerMode(
            id: instance.id,
            displayName: displayName,
            defaultSubMode: defaultSub,
            worldClocks: clocks
        )
    }
}

// MARK: - Duration parsing

enum DurationParser {
    /// Accepts: bare seconds ("90"), suffix form ("1h30m", "45m", "30s"),
    /// or colon form ("1:30" = 1m30s, "1:30:00" = 1h30m).
    /// Returns nil for unparseable or non-positive inputs.
    static func parse(_ raw: String) -> TimeInterval? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return nil }

        if s.contains(":") {
            let parts = s.split(separator: ":")
            var ints: [Int] = []
            for p in parts {
                guard let v = Int(p), v >= 0 else { return nil }
                ints.append(v)
            }
            switch ints.count {
            case 2: return positive(TimeInterval(ints[0] * 60 + ints[1]))
            case 3: return positive(TimeInterval(ints[0] * 3600 + ints[1] * 60 + ints[2]))
            default: return nil
            }
        }

        if let bare = Double(s) { return positive(bare) }

        var total: Double = 0
        var current = ""
        for ch in s {
            if ch.isNumber || ch == "." {
                current.append(ch)
            } else {
                let unit: Double
                switch ch {
                case "h", "H": unit = 3600
                case "m", "M": unit = 60
                case "s", "S": unit = 1
                default: return nil
                }
                guard let v = Double(current) else { return nil }
                total += v * unit
                current = ""
            }
        }
        if !current.isEmpty { return nil }
        return positive(total)
    }

    private static func positive(_ v: TimeInterval) -> TimeInterval? {
        v > 0 ? v : nil
    }

    static func format(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    static func formatPrecise(_ t: TimeInterval) -> String {
        let total = max(0, t)
        let h = Int(total) / 3600
        let m = (Int(total) % 3600) / 60
        let s = Int(total) % 60
        let cs = Int((total - floor(total)) * 100)
        if h > 0 { return String(format: "%d:%02d:%02d.%02d", h, m, s, cs) }
        return String(format: "%02d:%02d.%02d", m, s, cs)
    }
}
