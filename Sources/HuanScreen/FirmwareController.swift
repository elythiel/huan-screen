import AppKit
import UserNotifications

enum FirmwareState: Equatable {
    case unknown
    case checking
    case checked(FirmwareStatus)
    case failed
}

@MainActor
final class FirmwareController {
    private static let notifiedKey = "lastNotifiedFirmware"

    var onChange: (() -> Void)?
    private(set) var state = FirmwareState.unknown {
        didSet { onChange?() }
    }

    private let receiver: Receiver
    private(set) var installed = InstalledFirmware()

    init(receiver: Receiver) {
        self.receiver = receiver
    }

    var status: FirmwareStatus? {
        if case let .checked(status) = state { return status }
        return nil
    }

    func check(notify: Bool = false) {
        guard state != .checking, receiver.isConnected else { return }
        state = .checking
        Task {
            if let installed = await receiver.readFirmware() { remember(installed) }
            do {
                let latest = try await FirmwareChecker.latest(for: installed)
                let status = FirmwareStatus(installed: installed, latest: latest)
                state = .checked(status)
                if notify, status.isUpdateAvailable { notifyOnce(about: status) }
            } catch {
                state = .failed
            }
        }
    }

    func openHub() {
        NSWorkspace.shared.open(FirmwareChecker.hubURL)
    }

    private func remember(_ read: InstalledFirmware) {
        installed.receiver = read.receiver ?? installed.receiver
        installed.receiverPID = read.receiverPID ?? installed.receiverPID
        installed.mouse = read.mouse ?? installed.mouse
        installed.mousePID = read.mousePID ?? installed.mousePID
    }

    private func notifyOnce(about status: FirmwareStatus) {
        let signature = "\(status.latest.mouse ?? "-")/\(status.latest.receiver ?? "-")"
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: Self.notifiedKey) != signature else { return }
        defaults.set(signature, forKey: Self.notifiedKey)

        let content = UNMutableNotificationContent()
        content.title = localized("Firmware update available")
        content.body = localized("Update your HUAN with the WLMOUSE Hub.")
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "firmware-update", content: content, trigger: nil))
    }
}
