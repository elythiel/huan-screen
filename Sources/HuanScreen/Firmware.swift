import Foundation

struct InstalledFirmware: Sendable, Equatable {
    var mouse: String?
    var mousePID: String?
    var receiver: String?
    var receiverPID: String?
}

struct LatestFirmware: Sendable, Equatable {
    let mouse: String?
    let receiver: String?
}

struct FirmwareStatus: Sendable, Equatable {
    let installed: InstalledFirmware
    let latest: LatestFirmware

    var isMouseOutdated: Bool { isOutdated(installed.mouse, latest.mouse) }
    var isReceiverOutdated: Bool { isOutdated(installed.receiver, latest.receiver) }
    var isUpdateAvailable: Bool { isMouseOutdated || isReceiverOutdated }

    private func isOutdated(_ installed: String?, _ latest: String?) -> Bool {
        guard let installed, let latest else { return false }
        return UpdateChecker.isVersion(latest, newerThan: installed)
    }
}

extension InstalledFirmware {
    private static let delay: useconds_t = 60_000

    static func read(from channel: HIDChannel) -> InstalledFirmware {
        let receiver = version(of: 0x00, from: channel)
        let mouse = version(of: MouseInfo.mouse, from: channel)
        return InstalledFirmware(mouse: mouse?.version, mousePID: mouse?.pid, receiver: receiver?.version, receiverPID: receiver?.pid)
    }

    private static func version(of target: UInt8, from channel: HIDChannel) -> (version: String, pid: String)? {
        guard let payload = channel.send(HIDRequest(target: target, length: 0x10, group: 0, command: 0x81), delay: delay) else { return nil }
        let version = payload[0..<4].map(String.init).joined(separator: ".")
        let pid = String(format: "%02X%02X", payload[4], payload[5])
        return (version, pid)
    }
}

enum FirmwareChecker {
    static let hubURL = URL(string: "https://gm.wlmouse.gg")!
    private static let modelsURL = URL(string: "https://gm.wlmouse.gg/Config/env-models.json")!

    static func latest(for installed: InstalledFirmware) async throws -> LatestFirmware {
        var request = URLRequest(url: modelsURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let models = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { throw UpdateCheckError.badResponse }

        let model = models.first { matches($0["PIDWired"], installed.mousePID) }
            ?? models.first { matches($0["PIDWireless4K8K"], installed.receiverPID) }
        guard let model else { throw UpdateCheckError.badResponse }

        return LatestFirmware(
            mouse: version(in: model["DeviceFWFile_00"]),
            receiver: version(in: model["Receiver4K8KFWFile_00"])
        )
    }

    private static func matches(_ value: Any?, _ pid: String?) -> Bool {
        guard let value = value as? String, let pid else { return false }
        return value.uppercased() == pid
    }

    private static func version(in fileName: Any?) -> String? {
        guard let fileName = fileName as? String, let match = fileName.firstMatch(of: /_v(\d+(?:\.\d+){3})_/) else { return nil }
        return String(match.1)
    }
}
