import Foundation

struct AvailableUpdate: Sendable, Equatable {
    let version: String
    let downloadURL: URL
    let sha256: String
    let pageURL: URL
}

enum UpdateCheckError: LocalizedError {
    case badResponse
    case missingAsset

    var errorDescription: String? {
        switch self {
        case .badResponse: localized("GitHub returned an unexpected response.")
        case .missingAsset: localized("The latest release has no downloadable app.")
        }
    }
}

enum UpdateChecker {
    static let repositoryURL = URL(string: "https://github.com/elythiel/huan-screen")!
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/elythiel/huan-screen/releases/latest")!
    private static let digestPrefix = "sha256:"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    static func latestUpdate() async throws -> AvailableUpdate? {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateCheckError.badResponse }
        let release = try JSONDecoder().decode(Release.self, from: data)

        let version = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
        guard isVersion(version, newerThan: currentVersion) else { return nil }
        guard let asset = release.assets.first(where: { $0.name == "HuanScreen-\(version).zip" }),
              let digest = asset.digest, digest.hasPrefix(digestPrefix)
        else { throw UpdateCheckError.missingAsset }

        return AvailableUpdate(
            version: version,
            downloadURL: asset.browserDownloadURL,
            sha256: String(digest.dropFirst(digestPrefix.count)).lowercased(),
            pageURL: release.htmlURL
        )
    }

    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let lhs = components(of: candidate)
        let rhs = components(of: current)
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    private static func components(of version: String) -> [Int] {
        version.split(separator: ".").map { Int($0) ?? 0 }
    }
}

private struct Release: Decodable {
    let tagName: String
    let htmlURL: URL
    let assets: [Asset]

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL
        let digest: String?

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
            case digest
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}
