import Foundation

/// Representation of a released update from the Cloudflare Worker or GitHub Releases API.
public struct ReleaseManifest: Codable, Equatable, Sendable {
    public let version: String
    public let tagName: String
    public let releaseName: String?
    public let publishedAt: String?
    public let notes: String
    public let sha256: String?
    public let dmgName: String
    public let dmgSize: Int64?
    public let dmgUrl: URL
    public let githubDmgUrl: URL?
    public let htmlUrl: URL?

    public init(
        version: String,
        tagName: String,
        releaseName: String?,
        publishedAt: String?,
        notes: String,
        sha256: String?,
        dmgName: String,
        dmgSize: Int64?,
        dmgUrl: URL,
        githubDmgUrl: URL?,
        htmlUrl: URL?
    ) {
        self.version = version
        self.tagName = tagName
        self.releaseName = releaseName
        self.publishedAt = publishedAt
        self.notes = notes
        self.sha256 = sha256
        self.dmgName = dmgName
        self.dmgSize = dmgSize
        self.dmgUrl = dmgUrl
        self.githubDmgUrl = githubDmgUrl
        self.htmlUrl = htmlUrl
    }
}

/// Core update checking, semantic versioning, and parsing logic.
public enum UpdatePolicy {
    /// Strips leading 'v' / 'V' and non-numeric suffixes, splitting by '.' into integer components.
    public static func normalizeVersion(_ raw: String) -> [Int] {
        var clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.lowercased().hasPrefix("v") {
            clean = String(clean.dropFirst())
        }
        // If there's a pre-release or build identifier (e.g. 3.1.0-beta.1 or 3.1.0+build), strip suffix
        if let dashIndex = clean.firstIndex(of: "-") {
            clean = String(clean[..<dashIndex])
        }
        if let plusIndex = clean.firstIndex(of: "+") {
            clean = String(clean[..<plusIndex])
        }

        let parts = clean.split(separator: ".")
        var numbers: [Int] = []
        for part in parts {
            let digits = part.filter { $0.isNumber }
            if let num = Int(digits) {
                numbers.append(num)
            } else {
                break
            }
        }
        return numbers.isEmpty ? [0] : numbers
    }

    /// Compares two version strings using standard SemVer integer segment rules.
    public static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        var left = normalizeVersion(lhs)
        var right = normalizeVersion(rhs)

        let maxCount = max(left.count, right.count)
        while left.count < maxCount { left.append(0) }
        while right.count < maxCount { right.append(0) }

        for i in 0..<maxCount {
            if left[i] < right[i] {
                return .orderedAscending
            } else if left[i] > right[i] {
                return .orderedDescending
            }
        }
        return .orderedSame
    }

    /// Determines if `remote` is strictly newer than `current` and not explicitly skipped.
    public static func isUpdateAvailable(current: String, remote: String, skippedVersion: String? = nil) -> Bool {
        if let skipped = skippedVersion, !skipped.isEmpty {
            if compareVersions(remote, skipped) == .orderedSame {
                return false
            }
        }
        return compareVersions(remote, current) == .orderedDescending
    }

    /// Extracts a 64-character hex SHA-256 hash from Markdown notes or text.
    public static func extractSHA256(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "\\b([a-fA-F0-9]{64})\\b") else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, options: [], range: nsRange),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range]).lowercased()
        }
        return nil
    }

    /// Parses the JSON manifest returned by Cloudflare Worker `/api/v1/latest`.
    public static func parseWorkerManifest(data: Data) throws -> ReleaseManifest {
        let decoder = JSONDecoder()
        return try decoder.decode(ReleaseManifest.self, from: data)
    }

    /// Parses GitHub's official `repos/:owner/:repo/releases/latest` JSON payload.
    public static func parseGitHubReleaseManifest(data: Data) throws -> ReleaseManifest {
        struct GHAsset: Decodable {
            let name: String
            let size: Int64?
            let browser_download_url: URL
        }

        struct GHRelease: Decodable {
            let tag_name: String
            let name: String?
            let published_at: String?
            let body: String?
            let html_url: URL?
            let assets: [GHAsset]?
        }

        let decoder = JSONDecoder()
        let gh = try decoder.decode(GHRelease.self, from: data)

        let tagName = gh.tag_name
        var cleanVer = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanVer.lowercased().hasPrefix("v") {
            cleanVer = String(cleanVer.dropFirst())
        }

        let notes = gh.body ?? ""
        let sha256 = extractSHA256(from: notes)

        guard let dmgAsset = gh.assets?.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) else {
            throw NSError(
                domain: "UpdatePolicy",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No .dmg asset found in GitHub release"]
            )
        }

        return ReleaseManifest(
            version: cleanVer,
            tagName: tagName,
            releaseName: gh.name ?? "Pharos \(tagName)",
            publishedAt: gh.published_at,
            notes: notes,
            sha256: sha256,
            dmgName: dmgAsset.name,
            dmgSize: dmgAsset.size,
            dmgUrl: dmgAsset.browser_download_url,
            githubDmgUrl: dmgAsset.browser_download_url,
            htmlUrl: gh.html_url
        )
    }
}
