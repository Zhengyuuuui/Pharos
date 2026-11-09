import Foundation
import PharosCore

func testUpdatePolicy() {
    // 1. Semantic version normalization & comparison
    expectEq(UpdatePolicy.normalizeVersion("3.1.0"), [3, 1, 0], "normalizes 3.1.0")
    expectEq(UpdatePolicy.normalizeVersion("v3.1.0"), [3, 1, 0], "normalizes v3.1.0")
    expectEq(UpdatePolicy.normalizeVersion("V3.2"), [3, 2], "normalizes V3.2")
    expectEq(UpdatePolicy.normalizeVersion("3.1.0-beta.1"), [3, 1, 0], "normalizes pre-release")
    expectEq(UpdatePolicy.normalizeVersion("3.1.0+build99"), [3, 1, 0], "normalizes build suffix")

    expectEq(UpdatePolicy.compareVersions("3.1", "3.1.0"), .orderedSame, "3.1 == 3.1.0 (zero-padded)")
    expectEq(UpdatePolicy.compareVersions("v3.1.0", "3.1.0"), .orderedSame, "v3.1.0 == 3.1.0")
    expectEq(UpdatePolicy.compareVersions("3.2.0", "3.1.0"), .orderedDescending, "3.2.0 > 3.1.0")
    expectEq(UpdatePolicy.compareVersions("3.1.1", "3.1.0"), .orderedDescending, "3.1.1 > 3.1.0")
    expectEq(UpdatePolicy.compareVersions("3.10.0", "3.2.0"), .orderedDescending, "3.10.0 > 3.2.0 (numeric not lexical)")
    expectEq(UpdatePolicy.compareVersions("3.0.9", "3.1.0"), .orderedAscending, "3.0.9 < 3.1.0")
    expectEq(UpdatePolicy.compareVersions("4.0.0", "3.99.99"), .orderedDescending, "major bump 4.0.0 > 3.99.99")

    // 2. isUpdateAvailable logic
    expect(UpdatePolicy.isUpdateAvailable(current: "3.1.0", remote: "3.2.0"), "3.2.0 is newer than 3.1.0")
    expect(!UpdatePolicy.isUpdateAvailable(current: "3.1.0", remote: "3.1.0"), "same version is not an update")
    expect(!UpdatePolicy.isUpdateAvailable(current: "3.2.0", remote: "3.1.0"), "older version is not an update")
    expect(!UpdatePolicy.isUpdateAvailable(current: "3.1.0", remote: "3.2.0", skippedVersion: "3.2.0"), "skipped version 3.2.0 ignored")
    expect(UpdatePolicy.isUpdateAvailable(current: "3.1.0", remote: "3.2.0", skippedVersion: "3.1.5"), "non-matching skipped version ignored")

    // 3. extractSHA256
    let sampleMarkdown = """
    ## Verification
    | File | SHA-256 Checksum |
    |---|---|
    | `Pharos-3.1.0.dmg` | `b2a4abb45ae5952bedb41723ab37e1471d69872d3c600964f35a9fe3e1f00be9` |
    """
    let extracted = UpdatePolicy.extractSHA256(from: sampleMarkdown)
    expectEq(extracted, "b2a4abb45ae5952bedb41723ab37e1471d69872d3c600964f35a9fe3e1f00be9", "extracts sha256 from table")

    let upperCaseText = "SHA256: B2A4ABB45AE5952BEDB41723AB37E1471D69872D3C600964F35A9FE3E1F00BE9"
    expectEq(UpdatePolicy.extractSHA256(from: upperCaseText), "b2a4abb45ae5952bedb41723ab37e1471d69872d3c600964f35a9fe3e1f00be9", "extracts lowercase sha256 from uppercase text")
    expect(UpdatePolicy.extractSHA256(from: "short hash 1234567890abcdef") == nil, "rejects non-64-character hash")

    // 4. parseWorkerManifest
    let workerJson = """
    {
      "version": "3.1.0",
      "tagName": "v3.1.0",
      "releaseName": "Pharos v3.1.0",
      "publishedAt": "2026-11-05T03:33:20Z",
      "notes": "Bug fixes and improvements",
      "sha256": "b2a4abb45ae5952bedb41723ab37e1471d69872d3c600964f35a9fe3e1f00be9",
      "dmgName": "Pharos-3.1.0.dmg",
      "dmgSize": 9914061,
      "dmgUrl": "https://pharos-update.example.workers.dev/download/latest/Pharos-3.1.0.dmg",
      "githubDmgUrl": "https://github.com/Zhengyuuuui/Pharos/releases/download/v3.1.0/Pharos-3.1.0.dmg",
      "htmlUrl": "https://github.com/Zhengyuuuui/Pharos/releases/tag/v3.1.0"
    }
    """.data(using: .utf8)!

    do {
        let manifest = try UpdatePolicy.parseWorkerManifest(data: workerJson)
        expectEq(manifest.version, "3.1.0", "worker manifest version")
        expectEq(manifest.tagName, "v3.1.0", "worker manifest tagName")
        expectEq(manifest.sha256, "b2a4abb45ae5952bedb41723ab37e1471d69872d3c600964f35a9fe3e1f00be9", "worker manifest sha256")
        expectEq(manifest.dmgName, "Pharos-3.1.0.dmg", "worker manifest dmgName")
        expectEq(manifest.dmgSize, 9914061, "worker manifest dmgSize")
        expectEq(manifest.dmgUrl.absoluteString, "https://pharos-update.example.workers.dev/download/latest/Pharos-3.1.0.dmg", "worker manifest dmgUrl")
    } catch {
        expect(false, "Failed to parse worker manifest: \(error)")
    }

    // 5. parseGitHubReleaseManifest
    let ghJson = """
    {
      "tag_name": "v3.1.0",
      "name": "Pharos v3.1.0",
      "published_at": "2026-11-05T03:33:20Z",
      "html_url": "https://github.com/Zhengyuuuui/Pharos/releases/tag/v3.1.0",
      "body": "Package SHA256: b2a4abb45ae5952bedb41723ab37e1471d69872d3c600964f35a9fe3e1f00be9",
      "assets": [
        {
          "name": "Pharos-3.1.0.dmg",
          "size": 9914061,
          "browser_download_url": "https://github.com/Zhengyuuuui/Pharos/releases/download/v3.1.0/Pharos-3.1.0.dmg"
        }
      ]
    }
    """.data(using: .utf8)!

    do {
        let ghManifest = try UpdatePolicy.parseGitHubReleaseManifest(data: ghJson)
        expectEq(ghManifest.version, "3.1.0", "gh manifest version stripped 'v'")
        expectEq(ghManifest.tagName, "v3.1.0", "gh manifest tagName")
        expectEq(ghManifest.sha256, "b2a4abb45ae5952bedb41723ab37e1471d69872d3c600964f35a9fe3e1f00be9", "gh manifest sha256 from body")
        expectEq(ghManifest.dmgName, "Pharos-3.1.0.dmg", "gh manifest dmgName")
        expectEq(ghManifest.dmgSize, 9914061, "gh manifest dmgSize")
        expectEq(ghManifest.dmgUrl.absoluteString, "https://github.com/Zhengyuuuui/Pharos/releases/download/v3.1.0/Pharos-3.1.0.dmg", "gh manifest dmgUrl")
    } catch {
        expect(false, "Failed to parse GitHub release manifest: \(error)")
    }

    // 6. parseAtomFeed (rate-limit immune public Atom feed)
    let sampleAtom = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <entry>
        <id>tag:github.com,2008:Repository/1412696005/v3.1.0</id>
        <updated>2026-11-05T03:33:20Z</updated>
        <link rel="alternate" type="text/html" href="https://github.com/Zhengyuuuui/Pharos/releases/tag/v3.1.0"/>
        <title>Pharos v3.1.0</title>
        <content type="html">&lt;h1&gt;Pharos v3.1.0&lt;/h1&gt;&lt;p&gt;SHA256: b2a4abb45ae5952bedb41723ab37e1471d69872d3c600964f35a9fe3e1f00be9&lt;/p&gt;</content>
      </entry>
    </feed>
    """

    do {
        let atomManifest = try UpdatePolicy.parseAtomFeed(xml: sampleAtom)
        expectEq(atomManifest.version, "3.1.0", "atom manifest version")
        expectEq(atomManifest.tagName, "v3.1.0", "atom manifest tagName")
        expectEq(atomManifest.sha256, "b2a4abb45ae5952bedb41723ab37e1471d69872d3c600964f35a9fe3e1f00be9", "atom manifest sha256")
        expectEq(atomManifest.dmgName, "Pharos-3.1.0.dmg", "atom manifest dmgName")
        expectEq(atomManifest.dmgUrl.absoluteString, "https://github.com/Zhengyuuuui/Pharos/releases/download/v3.1.0/Pharos-3.1.0.dmg", "atom manifest dmgUrl")
    } catch {
        expect(false, "Failed to parse Atom feed: \(error)")
    }

    // 7. Censorship-Free Demo Nodes & Direct 0ms Latency
    let directNode = MihomoProxyNode(name: "Direct-Office-Intranet", type: "Direct", delay: 0, alive: true)
    expect(directNode.isHealthy, "direct intranet node is healthy with 0ms delay")
    expectEq(directNode.validDelay, 0, "direct intranet validDelay is 0")
    expectEq(directNode.statusRank, 0, "direct intranet statusRank is 0 (healthy)")

    expectEq(MihomoProxyNode(name: "HK-Direct-Alpha", type: "Dedicated").region, .hongKong, "HK-Direct-Alpha is HK")
    expectEq(MihomoProxyNode(name: "JP-Tokyo-Cluster-02", type: "Dedicated").region, .japan, "JP-Tokyo-Cluster-02 is JP")
    expectEq(MihomoProxyNode(name: "SG-SingTel-Dedicated", type: "Dedicated").region, .singapore, "SG-SingTel-Dedicated is SG")
    expectEq(MihomoProxyNode(name: "US-SiliconValley-Fast", type: "Direct").region, .unitedStates, "US-SiliconValley-Fast is US")
    expectEq(MihomoProxyNode(name: "DE-Frankfurt-Peer", type: "Direct").region, .europe, "DE-Frankfurt-Peer is EU")
    expectEq(MihomoProxyNode(name: "Direct-Office-Intranet", type: "Direct").region, .other, "Direct-Office-Intranet is other (GL)")
}
