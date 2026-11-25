import CryptoKit
import Foundation

enum UpdateInstallError: LocalizedError {
    case notWritable
    case downloadFailed
    case checksumMismatch
    case invalidBundle
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .notWritable: localized("Huan Screen cannot replace itself in this folder.")
        case .downloadFailed: localized("The update could not be downloaded.")
        case .checksumMismatch: localized("The downloaded update is corrupted (checksum mismatch).")
        case .invalidBundle: localized("The downloaded update is not a valid Huan Screen app.")
        case let .commandFailed(command): localized("%@ failed while installing the update.", command)
        }
    }
}

enum UpdateInstaller {
    private static let appName = "Huan Screen.app"

    static func install(_ update: AvailableUpdate, replacing appURL: URL) async throws {
        let fileManager = FileManager.default
        guard fileManager.isWritableFile(atPath: appURL.deletingLastPathComponent().path) else { throw UpdateInstallError.notWritable }

        let archive = try await download(update)
        let workDirectory = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: appURL, create: true)
        defer { try? fileManager.removeItem(at: workDirectory) }

        try run("/usr/bin/ditto", ["-x", "-k", archive.path, workDirectory.path])
        let newAppURL = workDirectory.appendingPathComponent(appName)
        try validate(newAppURL, expectedVersion: update.version)

        _ = try fileManager.replaceItemAt(appURL, withItemAt: newAppURL)
    }

    static func relaunch(_ appURL: URL) throws {
        let script = "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$2\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "relaunch", String(ProcessInfo.processInfo.processIdentifier), appURL.path]
        try process.run()
    }

    private static func download(_ update: AvailableUpdate) async throws -> URL {
        let (location, response) = try await URLSession.shared.download(from: update.downloadURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateInstallError.downloadFailed }

        let digest = SHA256.hash(data: try Data(contentsOf: location)).map { String(format: "%02x", $0) }.joined()
        guard digest == update.sha256 else { throw UpdateInstallError.checksumMismatch }
        return location
    }

    private static func validate(_ appURL: URL, expectedVersion: String) throws {
        guard let bundle = Bundle(url: appURL),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == expectedVersion
        else { throw UpdateInstallError.invalidBundle }
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", appURL.path])
    }

    private static func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateInstallError.commandFailed(executable) }
    }
}
