import Foundation
import UserNotifications

@MainActor
final class LowBatteryNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let thresholds = [20, 10]
    static let resetLevel = 25

    private let center = UNUserNotificationCenter.current()
    private var lastNotifiedThreshold: Int?

    override init() {
        super.init()
        center.delegate = self
        Task { _ = try? await center.requestAuthorization(options: [.alert, .sound]) }
    }

    func update(with info: MouseInfo) {
        if info.isCharging || info.batteryLevel > Self.resetLevel {
            lastNotifiedThreshold = nil
            return
        }
        guard let threshold = Self.threshold(toNotify: info.batteryLevel, lastNotified: lastNotifiedThreshold) else { return }
        lastNotifiedThreshold = threshold
        notify(level: info.batteryLevel)
    }

    static func threshold(toNotify level: Int, lastNotified: Int?) -> Int? {
        guard let reached = thresholds.filter({ level <= $0 }).min() else { return nil }
        guard let lastNotified else { return reached }
        return reached < lastNotified ? reached : nil
    }

    private func notify(level: Int) {
        let content = UNMutableNotificationContent()
        content.title = localized("Mouse battery low")
        content.body = localized("%ld%% left. Time to charge your HUAN.", level)
        content.sound = .default
        center.add(UNNotificationRequest(identifier: "low-battery", content: content, trigger: nil))
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
