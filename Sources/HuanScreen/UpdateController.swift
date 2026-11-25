import AppKit
import UserNotifications

enum UpdateState: Equatable {
    case unknown
    case checking
    case upToDate
    case available(AvailableUpdate)
    case installing(AvailableUpdate)
    case failed(String)
}

@MainActor
final class UpdateController {
    private static let launchCheckDelay: TimeInterval = 10
    private static let checkInterval: TimeInterval = 24 * 60 * 60
    private static let notifiedVersionKey = "lastNotifiedUpdateVersion"

    var onChange: (() -> Void)?
    var onCheck: ((Bool) -> Void)?
    private(set) var state = UpdateState.unknown {
        didSet { onChange?() }
    }

    private var checkTimer: Timer?

    var availableUpdate: AvailableUpdate? {
        if case let .available(update) = state { return update }
        return nil
    }

    func start() {
        Timer.scheduledTimer(withTimeInterval: Self.launchCheckDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.check(notify: true) }
        }
        checkTimer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check(notify: true) }
        }
    }

    func check(notify: Bool = false) {
        onCheck?(notify)
        guard state != .checking, !isInstalling else { return }
        state = .checking
        Task {
            do {
                let update = try await UpdateChecker.latestUpdate()
                state = update.map(UpdateState.available) ?? .upToDate
                if notify, let update { notifyOnce(about: update) }
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func install() {
        guard let update = availableUpdate else { return }
        state = .installing(update)
        let appURL = Bundle.main.bundleURL
        Task {
            do {
                try await UpdateInstaller.install(update, replacing: appURL)
                try UpdateInstaller.relaunch(appURL)
                NSApp.terminate(nil)
            } catch {
                state = .available(update)
                showFailure(error, update: update)
            }
        }
    }

    private var isInstalling: Bool {
        if case .installing = state { return true }
        return false
    }

    private func notifyOnce(about update: AvailableUpdate) {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: Self.notifiedVersionKey) != update.version else { return }
        defaults.set(update.version, forKey: Self.notifiedVersionKey)

        let content = UNMutableNotificationContent()
        content.title = localized("Huan Screen %@ is available", update.version)
        content.body = localized("Open the menu, then About Huan Screen → Update to install it.")
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "update-available", content: content, trigger: nil))
    }

    private func showFailure(_ error: Error, update: AvailableUpdate) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = localized("Couldn't install Huan Screen %@", update.version)
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: localized("Open Release Page"))
        alert.addButton(withTitle: localized("Cancel"))
        if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(update.pageURL) }
    }
}
