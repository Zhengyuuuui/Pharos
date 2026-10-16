import Darwin
import Foundation

/// 本地依赖包与命令行工具扫描解析器 (纯逻辑、无 UI 依赖、可全量单测)
public enum PackageScanner {
    // MARK: - Safe POSIX File Stat Helper

    public static func safeStat(at path: String) -> (size: UInt64, mtime: Date, isSymlink: Bool, isDir: Bool)? {
        var st = stat()
        let ret = path.withCString { lstat($0, &st) }
        guard ret == 0 else { return nil }
        let mode = st.st_mode & S_IFMT
        let isSymlink = (mode == S_IFLNK)
        let isDir = (mode == S_IFDIR)
        return (UInt64(st.st_size), Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec)), isSymlink, isDir)
    }

    /// 快速计算目录体积与文件总数 (安全只读、跳过深层软链接与特殊文件)
    public static func directorySize(at dir: String, maxFiles: Int = 100_000) -> (size: UInt64, count: Int) {
        guard let s = safeStat(at: dir), s.isDir else { return (0, 0) }
        var total: UInt64 = 0
        var count: Int = 0

        let url = URL(fileURLWithPath: dir)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else { return (0, 0) }

        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
               values.isRegularFile == true,
               let size = values.fileSize {
                total += UInt64(size)
                count += 1
                if count >= maxFiles { break }
            }
        }
        return (total, count)
    }

    // MARK: - Featured CLI Tools Catalog & Rule Engine

    public struct FeaturedCliRule: Sendable {
        public let summary: String
        public let tag: String
        public let isFeatured: Bool

        public init(summary: String, tag: String, isFeatured: Bool = true) {
            self.summary = summary
            self.tag = tag
            self.isFeatured = isFeatured
        }
    }

    public static let featuredCliCatalog: [String: FeaturedCliRule] = [
        // AI Agents & Assistants
        "claude": FeaturedCliRule(summary: "Anthropic Claude Code 终端智能 Agent", tag: "AI 助手"),
        "grok": FeaturedCliRule(summary: "xAI 官方 Grok 终端智能助手 CLI", tag: "AI 助手"),
        "rea": FeaturedCliRule(summary: "逆向工程与 Agent 分析套件 (MCP Server)", tag: "AI 助手"),
        "rea-agents": FeaturedCliRule(summary: "逆向工程与 Agent 分析套件 (MCP Server)", tag: "AI 助手"),
        "codebuddy": FeaturedCliRule(summary: "腾讯 AI CodeBuddy 终端智能助手", tag: "AI 助手"),
        "cbc": FeaturedCliRule(summary: "腾讯 AI CodeBuddy 终端智能助手", tag: "AI 助手"),
        "codebuddy-code": FeaturedCliRule(summary: "腾讯 AI CodeBuddy 终端智能助手", tag: "AI 助手"),
        "agent-browser": FeaturedCliRule(summary: "AI Agent 专用无头浏览器自动化驱动", tag: "AI 助手"),
        "aider": FeaturedCliRule(summary: "Aider 终端多模型 AI 结对编程助手", tag: "AI 助手"),
        "openai": FeaturedCliRule(summary: "OpenAI 官方 API 与模型交互命令行工具", tag: "AI 助手"),
        "litellm": FeaturedCliRule(summary: "LiteLLM 跨供应商大模型统一代理与调用工具", tag: "AI 助手"),
        "huggingface-cli": FeaturedCliRule(summary: "Hugging Face 官方模型与数据集客户端", tag: "AI 助手"),

        // Developer Build & Cloud Tools
        "wrangler": FeaturedCliRule(summary: "Cloudflare Workers & 边缘云开发管理 CLI", tag: "开发构建"),
        "cf-wrangler": FeaturedCliRule(summary: "Cloudflare Workers & 边缘云开发管理 CLI", tag: "开发构建"),
        "wrangler2": FeaturedCliRule(summary: "Cloudflare Workers & 边缘云开发管理 CLI", tag: "开发构建"),
        "cargo-tauri": FeaturedCliRule(summary: "Tauri 跨平台桌面与移动应用构建 CLI", tag: "开发构建"),
        "dlv": FeaturedCliRule(summary: "Delve — Go 语言官方全功能调试器", tag: "开发构建"),
        "just": FeaturedCliRule(summary: "just 现代化任务与命令执行器", tag: "开发构建"),
        "docker": FeaturedCliRule(summary: "Docker 容器应用开发与部署引擎", tag: "开发构建"),
        "kubectl": FeaturedCliRule(summary: "Kubernetes 集群容器编排管理客户端", tag: "开发构建"),

        // Package Managers & Runtimes
        "uv": FeaturedCliRule(summary: "Astral 极速 Python 包与虚拟环境管理器", tag: "包管理"),
        "uvx": FeaturedCliRule(summary: "Astral 临时 Python 命令行工具免安装运行器", tag: "包管理"),
        "bun": FeaturedCliRule(summary: "Bun 极速全功能 JavaScript/TypeScript 运行时与包管理器", tag: "包管理"),
        "bunx": FeaturedCliRule(summary: "Bun 临时可执行模块执行器", tag: "包管理"),
        "pnpm": FeaturedCliRule(summary: "pnpm 极速、节省磁盘空间的包管理器 (硬链接驱动)", tag: "包管理"),
        "pnpx": FeaturedCliRule(summary: "pnpm 临时可执行模块运行器", tag: "包管理"),
        "yarn": FeaturedCliRule(summary: "Yarn 快速可靠的依赖包管理工具", tag: "包管理"),
        "yarnpkg": FeaturedCliRule(summary: "Yarn 快速可靠的依赖包管理工具", tag: "包管理"),
        "rustup": FeaturedCliRule(summary: "Rust 官方多工具链与版本安装器", tag: "包管理"),
        "cargo": FeaturedCliRule(summary: "Rust 官方包管理器与构建系统", tag: "包管理"),

        // Terminal Productivity & Utilities
        "gh": FeaturedCliRule(summary: "GitHub 官方命令行客户端", tag: "终端效率"),
        "rg": FeaturedCliRule(summary: "ripgrep 极速递归代码与文本搜索器", tag: "终端效率"),
        "pdfplumber": FeaturedCliRule(summary: "PDF 详细文本与表格提取分析工具", tag: "终端效率"),
        "pytesseract": FeaturedCliRule(summary: "Tesseract OCR 图像光学文字识别工具", tag: "终端效率"),
        "tree": FeaturedCliRule(summary: "递归目录树状可视化查看工具", tag: "终端效率")
    ]

    // MARK: - 1. 全局 CLI 软件扫描 (scanGlobalCliTools)

    public static func scanGlobalCliTools(home: String = NSHomeDirectory()) -> [LocalPackageItem] {
        var items: [LocalPackageItem] = []
        var seenIds = Set<String>()

        // 1.1 Node.js 全局工具 (NVM, npm -g, Bun bin 等)
        items.append(contentsOf: scanNodeGlobalCliTools(home: home, seenIds: &seenIds))

        // 1.2 Cargo Rust 全局工具 (~/.cargo/bin, .crates2.json)
        items.append(contentsOf: scanCargoGlobalCliTools(home: home, seenIds: &seenIds))

        // 1.3 Python 全局 CLI 工具 (~/Library/Python/*/bin, ~/.local/bin/uv)
        items.append(contentsOf: scanPythonGlobalCliTools(home: home, seenIds: &seenIds))

        // 1.4 Homebrew 全局工具 (/opt/homebrew/bin, /usr/local/bin)
        items.append(contentsOf: scanHomebrewGlobalCliTools(home: home, seenIds: &seenIds))

        // 1.5 Go 全局工具 (~/go/bin)
        items.append(contentsOf: scanGoGlobalCliTools(home: home, seenIds: &seenIds))

        return items.sorted { a, b in
            if a.isFeatured != b.isFeatured {
                return a.isFeatured && !b.isFeatured
            }
            return a.name.lowercased() < b.name.lowercased()
        }
    }

    // MARK: - Node.js Global CLI Scanner
    private static func scanNodeGlobalCliTools(home: String, seenIds: inout Set<String>) -> [LocalPackageItem] {
        var results: [LocalPackageItem] = []

        // 探测目录：nvm versions/*/bin 以及 ~/.npm-global/bin, ~/.bun/bin
        var binDirs: [String] = []
        let nvmNode = (home as NSString).appendingPathComponent(".nvm/versions/node")
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmNode) {
            for v in versions where !v.hasPrefix(".") {
                let bin = (nvmNode as NSString).appendingPathComponent("\(v)/bin")
                binDirs.append(bin)
            }
        }
        let npmGlobalBin = (home as NSString).appendingPathComponent(".npm-global/bin")
        if FileManager.default.fileExists(atPath: npmGlobalBin) {
            binDirs.append(npmGlobalBin)
        }
        let bunBin = (home as NSString).appendingPathComponent(".bun/bin")
        if FileManager.default.fileExists(atPath: bunBin) {
            binDirs.append(bunBin)
        }

        for binDir in binDirs {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: binDir) else { continue }
            for file in files where !file.hasPrefix(".") {
                let binPath = (binDir as NSString).appendingPathComponent(file)
                guard let st = safeStat(at: binPath), !st.isDir else { continue }
                let id = "cli:node:\(file)"
                guard !seenIds.contains(id) else { continue }

                // 穿透符号链接解析源 package.json
                var pkgName = file
                var version: String? = nil
                var summary: String? = nil
                var license: String? = nil
                var installPath = binPath

                let resolved = URL(fileURLWithPath: binPath).resolvingSymlinksInPath().path
                installPath = resolved

                // 向上查找 package.json
                var currentDir = (resolved as NSString).deletingLastPathComponent
                for _ in 0..<4 {
                    let manifest = (currentDir as NSString).appendingPathComponent("package.json")
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: manifest)),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let name = json["name"] as? String { pkgName = name }
                        if let ver = json["version"] as? String { version = ver }
                        if let desc = json["description"] as? String { summary = desc }
                        if let lic = json["license"] as? String { license = lic }
                        installPath = currentDir
                        break
                    }
                    let parent = (currentDir as NSString).deletingLastPathComponent
                    if parent == currentDir || parent.isEmpty { break }
                    currentDir = parent
                }

                // 优先从核心目录匹配规则
                let rule = featuredCliCatalog[file.lowercased()] ?? featuredCliCatalog[pkgName.lowercased()]
                let isFeatured = (rule != nil)
                let categoryTag = rule?.tag
                var finalSummary = rule?.summary ?? summary

                // 特殊内置工具补充说明
                if file == "node" {
                    finalSummary = finalSummary ?? "Node.js JavaScript 运行时"
                } else if file == "npm" || file == "npx" {
                    finalSummary = finalSummary ?? "npm 官方包管理器与指令执行器"
                } else if file == "pnpm" || file == "pnpx" {
                    finalSummary = finalSummary ?? "极速、节省磁盘空间的包管理器 (硬链接驱动)"
                } else if file == "yarn" || file == "yarnpkg" {
                    finalSummary = finalSummary ?? "Yarn 快速可靠的依赖管理工具"
                } else if file == "corepack" {
                    finalSummary = finalSummary ?? "Node.js 官方包管理器版本桥接工具"
                }

                seenIds.insert(id)
                results.append(LocalPackageItem(
                    id: id,
                    name: file,
                    installedVersion: version,
                    declaredVersion: nil,
                    ecosystem: .node,
                    scope: .globalCli,
                    healthStatus: .normal,
                    summary: finalSummary ?? "Node.js 全局模块 (\(pkgName))",
                    license: license,
                    installPath: installPath,
                    executablePath: binPath,
                    fileSizeBytes: st.size,
                    lastModified: st.mtime,
                    projectName: nil,
                    isDevDependency: false,
                    isFeatured: isFeatured,
                    categoryTag: categoryTag
                ))
            }
        }
        return results
    }

    // MARK: - Cargo Rust Global CLI Scanner
    private static func scanCargoGlobalCliTools(home: String, seenIds: inout Set<String>) -> [LocalPackageItem] {
        var results: [LocalPackageItem] = []
        let cargoBin = (home as NSString).appendingPathComponent(".cargo/bin")
        guard FileManager.default.fileExists(atPath: cargoBin) else { return [] }

        // 解析 ~/.cargo/.crates2.json 获取精准版本与 crate 映射
        struct CargoCrateInfo {
            let crateName: String
            let version: String
            let bins: [String]
        }
        var binToCrate: [String: CargoCrateInfo] = [:]

        let crates2File = (home as NSString).appendingPathComponent(".cargo/.crates2.json")
        if let data = try? Data(contentsOf: URL(fileURLWithPath: crates2File)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let installs = json["installs"] as? [String: [String: Any]] {
            for (installKey, info) in installs {
                // installKey 例如: "tauri-cli 2.11.4 (registry+https://github.com/rust-lang/crates.io-index)"
                let parts = installKey.split(separator: " ")
                guard parts.count >= 2 else { continue }
                let crateName = String(parts[0])
                let version = String(parts[1])
                let bins = info["bins"] as? [String] ?? []
                let crateInfo = CargoCrateInfo(crateName: crateName, version: version, bins: bins)
                for b in bins {
                    binToCrate[b] = crateInfo
                }
            }
        }

        if let files = try? FileManager.default.contentsOfDirectory(atPath: cargoBin) {
            for file in files where !file.hasPrefix(".") {
                let binPath = (cargoBin as NSString).appendingPathComponent(file)
                guard let st = safeStat(at: binPath), !st.isDir else { continue }
                let id = "cli:cargo:\(file)"
                guard !seenIds.contains(id) else { continue }

                var version: String? = nil
                var summary: String? = nil
                if let info = binToCrate[file] {
                    version = info.version
                    summary = "Rust Cargo Crate: \(info.crateName)"
                } else if file == "rustup" {
                    summary = "The Rust toolchain installer"
                } else if file == "cargo" {
                    summary = "The Rust package manager"
                } else if file == "rustc" {
                    summary = "The Rust compiler"
                } else if file.hasPrefix("cargo-") {
                    summary = "Cargo 扩展插件: \(file)"
                }

                let rule = featuredCliCatalog[file.lowercased()]
                let isFeatured = (rule != nil)
                let categoryTag = rule?.tag
                let finalSummary = rule?.summary ?? summary ?? "Rust 全局可执行二进制"

                seenIds.insert(id)
                results.append(LocalPackageItem(
                    id: id,
                    name: file,
                    installedVersion: version,
                    declaredVersion: nil,
                    ecosystem: .rust,
                    scope: .globalCli,
                    healthStatus: .normal,
                    summary: finalSummary,
                    license: nil,
                    installPath: binPath,
                    executablePath: binPath,
                    fileSizeBytes: st.size,
                    lastModified: st.mtime,
                    projectName: nil,
                    isDevDependency: false,
                    isFeatured: isFeatured,
                    categoryTag: categoryTag
                ))
            }
        }
        return results
    }

    // MARK: - Python Global CLI Scanner
    private static func scanPythonGlobalCliTools(home: String, seenIds: inout Set<String>) -> [LocalPackageItem] {
        var results: [LocalPackageItem] = []

        // 1. ~/.local/bin/ (uv, uvx 等现代 Python 工具)
        let localBin = (home as NSString).appendingPathComponent(".local/bin")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: localBin) {
            for file in files where !file.hasPrefix(".") && file != "env" && file != "env.fish" {
                let binPath = (localBin as NSString).appendingPathComponent(file)
                guard let st = safeStat(at: binPath), !st.isDir else { continue }
                let id = "cli:local:\(file)"
                guard !seenIds.contains(id) else { continue }

                let rule = featuredCliCatalog[file.lowercased()]
                let isFeatured = (rule != nil)
                let categoryTag = rule?.tag
                var summary = rule?.summary ?? "用户本地独立可执行工具"

                if file == "uv" && rule == nil {
                    summary = "Astral 极速 Python 包与虚拟环境管理器"
                } else if file == "uvx" && rule == nil {
                    summary = "Astral 临时 Python 命令行工具免安装运行器"
                }

                seenIds.insert(id)
                results.append(LocalPackageItem(
                    id: id,
                    name: file,
                    installedVersion: nil,
                    declaredVersion: nil,
                    ecosystem: .python,
                    scope: .globalCli,
                    healthStatus: .normal,
                    summary: summary,
                    license: nil,
                    installPath: binPath,
                    executablePath: binPath,
                    fileSizeBytes: st.size,
                    lastModified: st.mtime,
                    projectName: nil,
                    isDevDependency: false,
                    isFeatured: isFeatured,
                    categoryTag: categoryTag
                ))
            }
        }

        // 2. ~/Library/Python/*/bin/
        let libPython = (home as NSString).appendingPathComponent("Library/Python")
        if let pyVersions = try? FileManager.default.contentsOfDirectory(atPath: libPython) {
            for ver in pyVersions where !ver.hasPrefix(".") {
                let binDir = (libPython as NSString).appendingPathComponent("\(ver)/bin")
                guard FileManager.default.fileExists(atPath: binDir) else { continue }

                // 扫描 site-packages 读取 .dist-info/METADATA 与 entry_points.txt
                struct PyDistInfo {
                    let name: String
                    let version: String
                    let summary: String?
                    let license: String?
                }
                var scriptToDist: [String: PyDistInfo] = [:]

                let sitePackages = (libPython as NSString).appendingPathComponent("\(ver)/lib/python/site-packages")
                if let pkgDirs = try? FileManager.default.contentsOfDirectory(atPath: sitePackages) {
                    for pkgDir in pkgDirs where pkgDir.hasSuffix(".dist-info") {
                        let distDir = (sitePackages as NSString).appendingPathComponent(pkgDir)
                        let metaPath = (distDir as NSString).appendingPathComponent("METADATA")
                        var currentDistInfo: PyDistInfo? = nil
                        if let content = try? String(contentsOfFile: metaPath, encoding: .utf8) {
                            var pName: String?
                            var pVer: String?
                            var pSum: String?
                            var pLic: String?
                            for line in content.components(separatedBy: "\n") {
                                if line.hasPrefix("Name: ") { pName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
                                else if line.hasPrefix("Version: ") { pVer = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces) }
                                else if line.hasPrefix("Summary: ") { pSum = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces) }
                                else if line.hasPrefix("License: ") && pLic == nil { pLic = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces) }
                            }
                            if let name = pName, let v = pVer {
                                let info = PyDistInfo(name: name, version: v, summary: pSum, license: pLic)
                                scriptToDist[name.lowercased()] = info
                                currentDistInfo = info
                            }
                        }

                        // 读取 entry_points.txt 映射 CLI 指令
                        let epPath = (distDir as NSString).appendingPathComponent("entry_points.txt")
                        if let epContent = try? String(contentsOfFile: epPath, encoding: .utf8),
                           let info = currentDistInfo {
                            var inConsoleScripts = false
                            for line in epContent.components(separatedBy: "\n") {
                                let trimmed = line.trimmingCharacters(in: .whitespaces)
                                if trimmed.hasPrefix("[") {
                                    inConsoleScripts = (trimmed == "[console_scripts]")
                                    continue
                                }
                                if inConsoleScripts, let eqIdx = trimmed.firstIndex(of: "=") {
                                    let scriptName = String(trimmed[..<eqIdx]).trimmingCharacters(in: .whitespaces)
                                    if !scriptName.isEmpty {
                                        scriptToDist[scriptName.lowercased()] = info
                                    }
                                }
                            }
                        }
                    }
                }

                if let files = try? FileManager.default.contentsOfDirectory(atPath: binDir) {
                    for file in files where !file.hasPrefix(".") && !file.hasSuffix(".pyc") {
                        let binPath = (binDir as NSString).appendingPathComponent(file)
                        guard let st = safeStat(at: binPath), !st.isDir else { continue }
                        let id = "cli:py:\(file)"
                        guard !seenIds.contains(id) else { continue }

                        let cleanName = file.replacingOccurrences(of: ".py", with: "")
                        let dist = scriptToDist[cleanName.lowercased()] ?? scriptToDist[file.lowercased()]

                        let rule = featuredCliCatalog[file.lowercased()] ?? featuredCliCatalog[cleanName.lowercased()] ?? (dist != nil ? featuredCliCatalog[dist!.name.lowercased()] : nil)
                        let isFeatured = (rule != nil)
                        let categoryTag = rule?.tag
                        let finalSummary = rule?.summary ?? dist?.summary ?? "Python \(ver) 全局命令行工具"

                        seenIds.insert(id)
                        results.append(LocalPackageItem(
                            id: id,
                            name: file,
                            installedVersion: dist?.version,
                            declaredVersion: nil,
                            ecosystem: .python,
                            scope: .globalCli,
                            healthStatus: .normal,
                            summary: finalSummary,
                            license: dist?.license,
                            installPath: binPath,
                            executablePath: binPath,
                            fileSizeBytes: st.size,
                            lastModified: st.mtime,
                            projectName: nil,
                            isDevDependency: false,
                            isFeatured: isFeatured,
                            categoryTag: categoryTag
                        ))
                    }
                }
            }
        }

        return results
    }

    // MARK: - Homebrew Global CLI Scanner
    private static func scanHomebrewGlobalCliTools(home: String, seenIds: inout Set<String>) -> [LocalPackageItem] {
        var results: [LocalPackageItem] = []
        let brewBins = ["/opt/homebrew/bin", "/usr/local/bin"]

        for brewBin in brewBins {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: brewBin) else { continue }
            for file in files where !file.hasPrefix(".") {
                let binPath = (brewBin as NSString).appendingPathComponent(file)
                guard let st = safeStat(at: binPath), !st.isDir else { continue }
                let id = "cli:brew:\(file)"
                guard !seenIds.contains(id) else { continue }

                var version: String? = nil
                var installPath = binPath

                if st.isSymlink {
                    let resolved = URL(fileURLWithPath: binPath).resolvingSymlinksInPath().path
                    installPath = resolved
                    // 检查是否指向 ../Cellar/<name>/<version>/...
                    if resolved.contains("/Cellar/") {
                        let parts = resolved.components(separatedBy: "/Cellar/")
                        if parts.count > 1 {
                            let subParts = parts[1].components(separatedBy: "/")
                            if subParts.count >= 2 {
                                version = subParts[1]
                            }
                        }
                    }
                }

                let rule = featuredCliCatalog[file.lowercased()]
                let isFeatured = (rule != nil)
                let categoryTag = rule?.tag
                let finalSummary = rule?.summary ?? "Homebrew 安装的命令行工具"

                seenIds.insert(id)
                results.append(LocalPackageItem(
                    id: id,
                    name: file,
                    installedVersion: version,
                    declaredVersion: nil,
                    ecosystem: .homebrew,
                    scope: .globalCli,
                    healthStatus: .normal,
                    summary: finalSummary,
                    license: nil,
                    installPath: installPath,
                    executablePath: binPath,
                    fileSizeBytes: st.size,
                    lastModified: st.mtime,
                    projectName: nil,
                    isDevDependency: false,
                    isFeatured: isFeatured,
                    categoryTag: categoryTag
                ))
            }
        }
        return results
    }

    // MARK: - Go Global CLI Scanner
    private static func scanGoGlobalCliTools(home: String, seenIds: inout Set<String>) -> [LocalPackageItem] {
        var results: [LocalPackageItem] = []
        let goBin = (home as NSString).appendingPathComponent("go/bin")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: goBin) else { return [] }

        for file in files where !file.hasPrefix(".") {
            let binPath = (goBin as NSString).appendingPathComponent(file)
            guard let st = safeStat(at: binPath), !st.isDir else { continue }
            let id = "cli:go:\(file)"
            guard !seenIds.contains(id) else { continue }

            let rule = featuredCliCatalog[file.lowercased()]
            let isFeatured = (rule != nil)
            let categoryTag = rule?.tag
            var summary = rule?.summary ?? "Go 全局编译可执行工具"

            if file == "dlv" && rule == nil {
                summary = "Delve — Go 语言官方全功能调试器"
            }

            seenIds.insert(id)
            results.append(LocalPackageItem(
                id: id,
                name: file,
                installedVersion: nil,
                declaredVersion: nil,
                ecosystem: .go,
                scope: .globalCli,
                healthStatus: .normal,
                summary: summary,
                license: nil,
                installPath: binPath,
                executablePath: binPath,
                fileSizeBytes: st.size,
                lastModified: st.mtime,
                projectName: nil,
                isDevDependency: false,
                isFeatured: isFeatured,
                categoryTag: categoryTag
            ))
        }
        return results
    }

    // MARK: - 2. 语言本地缓存仓库扫描 (scanCacheRepositories)

    public static func scanCacheRepositories(home: String = NSHomeDirectory()) -> [PackageCacheRepoSummary] {
        var repos: [PackageCacheRepoSummary] = []

        // 2.1 pnpm 全局硬链接存储库 (~/Library/pnpm)
        let pnpmPath = (home as NSString).appendingPathComponent("Library/pnpm")
        if FileManager.default.fileExists(atPath: pnpmPath) {
            let (size, count) = directorySize(at: pnpmPath)
            repos.append(PackageCacheRepoSummary(
                id: "pnpm-store",
                name: "pnpm 全局硬链接依赖仓库",
                ecosystem: .node,
                rootPath: pnpmPath,
                fileSizeBytes: size,
                itemCount: count,
                description: "pnpm 全局内容可寻址存储区 (跨项目共享依赖，节省数 GB 空间)"
            ))
        }

        // 2.2 npm 官方 tarball 下载缓存 (~/.npm)
        let npmCachePath = (home as NSString).appendingPathComponent(".npm")
        if FileManager.default.fileExists(atPath: npmCachePath) {
            let (size, count) = directorySize(at: npmCachePath)
            repos.append(PackageCacheRepoSummary(
                id: "npm-cache",
                name: "npm 官方模块下载缓存",
                ecosystem: .node,
                rootPath: npmCachePath,
                fileSizeBytes: size,
                itemCount: count,
                description: "npm 安装包 tarball 下载、_cacache 内容寻址与元数据缓存"
            ))
        }

        // 2.3 Python uv Wheel 预编译缓存 (~/.cache/uv)
        let uvCachePath = (home as NSString).appendingPathComponent(".cache/uv")
        if FileManager.default.fileExists(atPath: uvCachePath) {
            let (size, count) = directorySize(at: uvCachePath)
            repos.append(PackageCacheRepoSummary(
                id: "uv-cache",
                name: "Python uv 预编译 Wheel 缓存",
                ecosystem: .python,
                rootPath: uvCachePath,
                fileSizeBytes: size,
                itemCount: count,
                description: "Astral uv 快速编译构建的 Python wheels 与 HTTP 元数据缓存"
            ))
        }

        // 2.4 Java Maven 本地仓库 (~/.m2/repository)
        let mavenPath = (home as NSString).appendingPathComponent(".m2/repository")
        if FileManager.default.fileExists(atPath: mavenPath) {
            let (size, count) = directorySize(at: mavenPath)
            repos.append(PackageCacheRepoSummary(
                id: "maven-m2",
                name: "Java Maven 本地构件库",
                ecosystem: .java,
                rootPath: mavenPath,
                fileSizeBytes: size,
                itemCount: count,
                description: "Maven / Gradle 下载的依赖 Jar 包、POM 规范文件与插件库"
            ))
        }

        // 2.5 Rust Cargo 注册源与源码缓存 (~/.cargo/registry)
        let cargoRegistryPath = (home as NSString).appendingPathComponent(".cargo/registry")
        if FileManager.default.fileExists(atPath: cargoRegistryPath) {
            let (size, count) = directorySize(at: cargoRegistryPath)
            repos.append(PackageCacheRepoSummary(
                id: "cargo-registry",
                name: "Rust Cargo 注册源与 Crate 缓存",
                ecosystem: .rust,
                rootPath: cargoRegistryPath,
                fileSizeBytes: size,
                itemCount: count,
                description: "crates.io 索引克隆、crate 解压源码及本地打包构建元数据"
            ))
        }

        // 2.6 Bun 模块缓存 (~/.bun)
        let bunPath = (home as NSString).appendingPathComponent(".bun")
        if FileManager.default.fileExists(atPath: bunPath) {
            let (size, count) = directorySize(at: bunPath)
            repos.append(PackageCacheRepoSummary(
                id: "bun-cache",
                name: "Bun 运行时与安装包缓存",
                ecosystem: .node,
                rootPath: bunPath,
                fileSizeBytes: size,
                itemCount: count,
                description: "Bun 快速安装包二进制缓存与锁文件索引"
            ))
        }

        // 2.7 SwiftPM 构件缓存 (~/Library/Caches/org.swift.swiftpm)
        let swiftpmPath = (home as NSString).appendingPathComponent("Library/Caches/org.swift.swiftpm")
        if FileManager.default.fileExists(atPath: swiftpmPath) {
            let (size, count) = directorySize(at: swiftpmPath)
            repos.append(PackageCacheRepoSummary(
                id: "swiftpm-cache",
                name: "SwiftPM 源码与清单缓存",
                ecosystem: .swift,
                rootPath: swiftpmPath,
                fileSizeBytes: size,
                itemCount: count,
                description: "Swift Package Manager Git 仓库克隆镜像与 Package.swift 清单缓存"
            ))
        }

        // 2.8 OpenJDK 运行时探测 (/opt/homebrew/opt/openjdk*)
        let optHomebrew = "/opt/homebrew/opt"
        if let dirs = try? FileManager.default.contentsOfDirectory(atPath: optHomebrew) {
            for d in dirs where d.hasPrefix("openjdk") {
                let fullPath = (optHomebrew as NSString).appendingPathComponent(d)
                var version = d
                // 读取 release 文件获取精准 JAVA_VERSION
                let releaseFile = "\(fullPath)/libexec/openjdk.jdk/Contents/Home/release"
                if let content = try? String(contentsOfFile: releaseFile, encoding: .utf8) {
                    for line in content.components(separatedBy: "\n") {
                        if line.hasPrefix("JAVA_VERSION=") {
                            version = line.replacingOccurrences(of: "JAVA_VERSION=", with: "")
                                .replacingOccurrences(of: "\"", with: "")
                                .trimmingCharacters(in: .whitespaces)
                            break
                        }
                    }
                }
                let (size, count) = directorySize(at: fullPath)
                repos.append(PackageCacheRepoSummary(
                    id: "jdk-\(d)",
                    name: "OpenJDK 运行时 (\(version))",
                    ecosystem: .java,
                    rootPath: fullPath,
                    fileSizeBytes: size,
                    itemCount: count,
                    description: "本地已安装的 Java 开发套件环境与标准库模块"
                ))
            }
        }

        return repos.sorted { $0.fileSizeBytes > $1.fileSizeBytes }
    }

    // MARK: - 3. 项目级依赖洞察 (scanProjectDependencies)

    /// 统一多技术栈项目依赖与缓存识别 (支持 Node.js、Python、Swift、Rust、Java 等)
    public static func scanProjectDependencies(projectPath: String) -> ProjectDependencySummary? {
        let root = (projectPath as NSString).standardizingPath
        let projectName = (root as NSString).lastPathComponent

        // 1. Node.js (package.json / node_modules)
        let pkgJsonPath = (root as NSString).appendingPathComponent("package.json")
        let nodeModulesPath = (root as NSString).appendingPathComponent("node_modules")
        if FileManager.default.fileExists(atPath: pkgJsonPath) || FileManager.default.fileExists(atPath: nodeModulesPath) {
            if let nodeSummary = scanNodeProject(root: root, projectName: projectName) {
                return nodeSummary
            }
        }

        // 2. Python (requirements.txt / pyproject.toml / Pipfile / .venv / venv)
        let reqTxtPath = (root as NSString).appendingPathComponent("requirements.txt")
        let pyprojectPath = (root as NSString).appendingPathComponent("pyproject.toml")
        let pipfilePath = (root as NSString).appendingPathComponent("Pipfile")
        let dotVenvPath = (root as NSString).appendingPathComponent(".venv")
        let venvPath = (root as NSString).appendingPathComponent("venv")
        if FileManager.default.fileExists(atPath: reqTxtPath) ||
            FileManager.default.fileExists(atPath: pyprojectPath) ||
            FileManager.default.fileExists(atPath: pipfilePath) ||
            FileManager.default.fileExists(atPath: dotVenvPath) ||
            FileManager.default.fileExists(atPath: venvPath) {
            if let pySummary = scanPythonProject(root: root, projectName: projectName) {
                return pySummary
            }
        }

        // 3. SwiftPM (Package.swift / Package.resolved / .build)
        let pkgSwiftPath = (root as NSString).appendingPathComponent("Package.swift")
        let pkgResolvedPath = (root as NSString).appendingPathComponent("Package.resolved")
        let buildPath = (root as NSString).appendingPathComponent(".build")
        if FileManager.default.fileExists(atPath: pkgSwiftPath) ||
            FileManager.default.fileExists(atPath: pkgResolvedPath) ||
            FileManager.default.fileExists(atPath: buildPath) {
            if let swiftSummary = scanSwiftProject(root: root, projectName: projectName) {
                return swiftSummary
            }
        }

        // 4. Rust Cargo (Cargo.toml / Cargo.lock / target)
        let cargoTomlPath = (root as NSString).appendingPathComponent("Cargo.toml")
        let cargoLockPath = (root as NSString).appendingPathComponent("Cargo.lock")
        let targetPath = (root as NSString).appendingPathComponent("target")
        if FileManager.default.fileExists(atPath: cargoTomlPath) ||
            (FileManager.default.fileExists(atPath: targetPath) && FileManager.default.fileExists(atPath: cargoLockPath)) {
            if let rustSummary = scanRustProject(root: root, projectName: projectName) {
                return rustSummary
            }
        }

        // 5. Java (pom.xml / build.gradle)
        let pomPath = (root as NSString).appendingPathComponent("pom.xml")
        let gradlePath = (root as NSString).appendingPathComponent("build.gradle")
        if FileManager.default.fileExists(atPath: pomPath) || FileManager.default.fileExists(atPath: gradlePath) {
            if let javaSummary = scanJavaProject(root: root, projectName: projectName) {
                return javaSummary
            }
        }

        return nil
    }

    // MARK: - Node.js Project Scanner
    private static func scanNodeProject(root: String, projectName: String) -> ProjectDependencySummary? {
        let pkgJsonPath = (root as NSString).appendingPathComponent("package.json")
        let nodeModulesPath = (root as NSString).appendingPathComponent("node_modules")
        let nodeModulesExists = FileManager.default.fileExists(atPath: nodeModulesPath)

        var directDeclaredCount = 0
        var packages: [LocalPackageItem] = []
        var missingCount = 0
        var totalDepsSize: UInt64 = 0
        var displayName = projectName

        if let data = try? Data(contentsOf: URL(fileURLWithPath: pkgJsonPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let name = json["name"] as? String, !name.isEmpty {
                displayName = name
            }
            let prodDeps = (json["dependencies"] as? [String: String]) ?? [:]
            let devDeps = (json["devDependencies"] as? [String: String]) ?? [:]
            directDeclaredCount = prodDeps.count + devDeps.count

            func processDep(name: String, declaredVer: String, isDev: Bool) {
                let depDir = (nodeModulesPath as NSString).appendingPathComponent(name)
                guard let st = safeStat(at: depDir) else {
                    missingCount += 1
                    packages.append(LocalPackageItem(
                        id: "proj:\(projectName):\(name)",
                        name: name,
                        installedVersion: nil,
                        declaredVersion: declaredVer,
                        ecosystem: .node,
                        scope: .projectDependency,
                        healthStatus: .missing,
                        summary: nil,
                        license: nil,
                        installPath: depDir,
                        executablePath: nil,
                        fileSizeBytes: 0,
                        lastModified: Date(),
                        projectName: projectName,
                        isDevDependency: isDev
                    ))
                    return
                }

                var health: DependencyHealthStatus = st.isSymlink ? .symlinkedWorkspace : .normal
                var installedVer: String? = nil
                var summary: String? = nil
                var license: String? = nil
                let depManifest = (depDir as NSString).appendingPathComponent("package.json")
                if let depData = try? Data(contentsOf: URL(fileURLWithPath: depManifest)),
                   let depJson = try? JSONSerialization.jsonObject(with: depData) as? [String: Any] {
                    installedVer = depJson["version"] as? String
                    summary = depJson["description"] as? String
                    license = depJson["license"] as? String
                }

                if health == .normal, let inst = installedVer {
                    if isVersionMismatched(declared: declaredVer, installed: inst) {
                        health = .mismatched
                    }
                }

                let (pkgSize, _) = directorySize(at: depDir, maxFiles: 1_000)
                totalDepsSize += pkgSize

                packages.append(LocalPackageItem(
                    id: "proj:\(projectName):\(name)",
                    name: name,
                    installedVersion: installedVer,
                    declaredVersion: declaredVer,
                    ecosystem: .node,
                    scope: .projectDependency,
                    healthStatus: health,
                    summary: summary,
                    license: license,
                    installPath: depDir,
                    executablePath: nil,
                    fileSizeBytes: pkgSize,
                    lastModified: st.mtime,
                    projectName: projectName,
                    isDevDependency: isDev
                ))
            }

            for (name, ver) in prodDeps {
                processDep(name: name, declaredVer: ver, isDev: false)
            }
            for (name, ver) in devDeps {
                processDep(name: name, declaredVer: ver, isDev: true)
            }
        } else if nodeModulesExists {
            // 没有 package.json，但存在 node_modules
            if let entries = try? FileManager.default.contentsOfDirectory(atPath: nodeModulesPath) {
                for entry in entries where !entry.hasPrefix(".") && entry != ".bin" {
                    let depDir = (nodeModulesPath as NSString).appendingPathComponent(entry)
                    guard let st = safeStat(at: depDir), st.isDir else { continue }
                    var version: String? = nil
                    var summary: String? = nil
                    let depManifest = (depDir as NSString).appendingPathComponent("package.json")
                    if let depData = try? Data(contentsOf: URL(fileURLWithPath: depManifest)),
                       let depJson = try? JSONSerialization.jsonObject(with: depData) as? [String: Any] {
                        version = depJson["version"] as? String
                        summary = depJson["description"] as? String
                    }
                    let (pkgSize, _) = directorySize(at: depDir, maxFiles: 1_000)
                    totalDepsSize += pkgSize
                    packages.append(LocalPackageItem(
                        id: "proj:\(projectName):\(entry)",
                        name: entry,
                        installedVersion: version,
                        declaredVersion: nil,
                        ecosystem: .node,
                        scope: .projectDependency,
                        healthStatus: .normal,
                        summary: summary,
                        license: nil,
                        installPath: depDir,
                        fileSizeBytes: pkgSize,
                        projectName: projectName
                    ))
                }
            }
            directDeclaredCount = packages.count
        } else {
            return nil
        }

        // 计算 node_modules 目录体积
        if nodeModulesExists {
            let (sz, _) = directorySize(at: nodeModulesPath, maxFiles: 20_000)
            if sz > totalDepsSize {
                totalDepsSize = sz
            }
        }

        return ProjectDependencySummary(
            id: root,
            name: displayName,
            rootPath: root,
            ecosystem: .node,
            dependenciesSizeBytes: totalDepsSize,
            directDependenciesCount: directDeclaredCount,
            missingDependenciesCount: missingCount,
            packages: packages.sorted { $0.name.lowercased() < $1.name.lowercased() },
            cacheDirectoryName: nodeModulesExists ? "node_modules" : nil
        )
    }

    // MARK: - Python Project Scanner
    private static func scanPythonProject(root: String, projectName: String) -> ProjectDependencySummary? {
        // 1. 寻找虚拟环境目录
        let venvCandidates = [".venv", "venv", "env", ".env"]
        var activeVenvPath: String? = nil
        var venvDirName: String? = nil

        for c in venvCandidates {
            let p = (root as NSString).appendingPathComponent(c)
            if let st = safeStat(at: p), st.isDir {
                activeVenvPath = p
                venvDirName = c
                break
            }
        }

        var totalCacheSize: UInt64 = 0
        if let venv = activeVenvPath {
            let (sz, _) = directorySize(at: venv, maxFiles: 30_000)
            totalCacheSize = sz
        }

        // 2. 探索 site-packages 下已落地的依赖
        var installedPackages: [String: LocalPackageItem] = [:]
        if let venv = activeVenvPath {
            let libPath = (venv as NSString).appendingPathComponent("lib")
            if let pyVersions = try? FileManager.default.contentsOfDirectory(atPath: libPath) {
                for pyVer in pyVersions where pyVer.hasPrefix("python") {
                    let sitePackages = ((libPath as NSString).appendingPathComponent(pyVer) as NSString).appendingPathComponent("site-packages")
                    guard let entries = try? FileManager.default.contentsOfDirectory(atPath: sitePackages) else { continue }
                    for entry in entries where entry.hasSuffix(".dist-info") {
                        let distInfoPath = (sitePackages as NSString).appendingPathComponent(entry)
                        var pkgName = entry.replacingOccurrences(of: ".dist-info", with: "")
                        var pkgVersion: String? = nil
                        var pkgSummary: String? = nil
                        var pkgLicense: String? = nil

                        // 从 METADATA 文件解析精确元数据
                        let metaFile = (distInfoPath as NSString).appendingPathComponent("METADATA")
                        if let metaContent = try? String(contentsOfFile: metaFile, encoding: .utf8) {
                            for line in metaContent.components(separatedBy: "\n") {
                                if line.hasPrefix("Name: ") {
                                    pkgName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                                } else if line.hasPrefix("Version: ") {
                                    pkgVersion = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                                } else if line.hasPrefix("Summary: ") {
                                    pkgSummary = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                                } else if line.hasPrefix("License: ") {
                                    pkgLicense = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                                }
                            }
                        } else {
                            // 回退根据文件名截取
                            let parts = pkgName.split(separator: "-")
                            if parts.count >= 2 {
                                pkgName = String(parts[0])
                                pkgVersion = String(parts[1])
                            }
                        }

                        // 查找对应的包目录体积
                        let packageDir = (sitePackages as NSString).appendingPathComponent(pkgName)
                        let targetDir = FileManager.default.fileExists(atPath: packageDir) ? packageDir : distInfoPath
                        let (sz, _) = directorySize(at: targetDir, maxFiles: 1_000)

                        let item = LocalPackageItem(
                            id: "proj:\(projectName):\(pkgName)",
                            name: pkgName,
                            installedVersion: pkgVersion,
                            declaredVersion: nil,
                            ecosystem: .python,
                            scope: .projectDependency,
                            healthStatus: .normal,
                            summary: pkgSummary,
                            license: pkgLicense,
                            installPath: targetDir,
                            executablePath: nil,
                            fileSizeBytes: sz,
                            projectName: projectName
                        )
                        installedPackages[pkgName.lowercased()] = item
                    }
                }
            }
        }

        // 3. 解析声明依赖 (requirements.txt / pyproject.toml)
        var declaredReqs: [String: (name: String, ver: String?)] = [:]
        let reqTxt = (root as NSString).appendingPathComponent("requirements.txt")
        if let content = try? String(contentsOfFile: reqTxt, encoding: .utf8) {
            let ops = [">=", "<=", "==", "!=", "~=", ">", "<"]
            for line in content.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("-") { continue }
                var depName = trimmed
                var depVer: String? = nil
                for op in ops {
                    if let range = trimmed.range(of: op) {
                        depName = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                        depVer = String(trimmed[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
                declaredReqs[depName.lowercased()] = (name: depName, ver: depVer)
            }
        }

        let pyproject = (root as NSString).appendingPathComponent("pyproject.toml")
        if declaredReqs.isEmpty, let content = try? String(contentsOfFile: pyproject, encoding: .utf8) {
            var inDeps = false
            for line in content.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("dependencies = [") || trimmed == "[project.dependencies]" {
                    inDeps = true
                    continue
                }
                if inDeps {
                    if trimmed.hasPrefix("]") || (trimmed.hasPrefix("[") && !trimmed.contains("dependencies")) {
                        inDeps = false
                        continue
                    }
                    let clean = trimmed.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "").replacingOccurrences(of: ",", with: "")
                    if clean.isEmpty || clean.hasPrefix("#") { continue }
                    let ops = [">=", "<=", "==", "!=", "~=", ">", "<"]
                    var depName = clean
                    var depVer: String? = nil
                    for op in ops {
                        if let range = clean.range(of: op) {
                            depName = String(clean[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                            depVer = String(clean[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
                            break
                        }
                    }
                    declaredReqs[depName.lowercased()] = (name: depName, ver: depVer)
                }
            }
        }

        var packages: [LocalPackageItem] = []
        var missingCount = 0

        if !declaredReqs.isEmpty {
            for (lowered, req) in declaredReqs {
                if let installed = installedPackages[lowered] {
                    packages.append(LocalPackageItem(
                        id: installed.id,
                        name: req.name,
                        installedVersion: installed.installedVersion,
                        declaredVersion: req.ver,
                        ecosystem: .python,
                        scope: .projectDependency,
                        healthStatus: .normal,
                        summary: installed.summary,
                        license: installed.license,
                        installPath: installed.installPath,
                        fileSizeBytes: installed.fileSizeBytes,
                        projectName: projectName
                    ))
                } else {
                    missingCount += 1
                    packages.append(LocalPackageItem(
                        id: "proj:\(projectName):\(req.name)",
                        name: req.name,
                        installedVersion: nil,
                        declaredVersion: req.ver,
                        ecosystem: .python,
                        scope: .projectDependency,
                        healthStatus: .missing,
                        summary: nil,
                        license: nil,
                        installPath: root,
                        fileSizeBytes: 0,
                        projectName: projectName
                    ))
                }
            }
        } else {
            // 没有声明文件，直接以 .venv 中安装的包作为项目依赖呈现
            packages = Array(installedPackages.values)
        }

        if packages.isEmpty && totalCacheSize == 0 {
            return nil
        }

        return ProjectDependencySummary(
            id: root,
            name: projectName,
            rootPath: root,
            ecosystem: .python,
            dependenciesSizeBytes: totalCacheSize,
            directDependenciesCount: declaredReqs.isEmpty ? packages.count : declaredReqs.count,
            missingDependenciesCount: missingCount,
            packages: packages.sorted { $0.name.lowercased() < $1.name.lowercased() },
            cacheDirectoryName: venvDirName
        )
    }

    // MARK: - SwiftPM Project Scanner
    private static func scanSwiftProject(root: String, projectName: String) -> ProjectDependencySummary? {
        let buildPath = (root as NSString).appendingPathComponent(".build")
        let buildExists = FileManager.default.fileExists(atPath: buildPath)
        var totalCacheSize: UInt64 = 0

        if buildExists {
            let (sz, _) = directorySize(at: buildPath, maxFiles: 30_000)
            totalCacheSize = sz
        }

        var packages: [LocalPackageItem] = []
        var missingCount = 0

        // 尝试解析 Package.resolved (JSON 格式)
        let resolvedPath = (root as NSString).appendingPathComponent("Package.resolved")
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resolvedPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let pins: [[String: Any]] = (json["pins"] as? [[String: Any]]) ??
                ((json["object"] as? [String: Any])?["pins"] as? [[String: Any]]) ?? []

            for pin in pins {
                let name = (pin["identity"] as? String) ?? (pin["package"] as? String) ?? "package"
                let state = pin["state"] as? [String: Any]
                let version = (state?["version"] as? String) ?? (state?["revision"] as? String)
                let checkoutDir = (buildPath as NSString).appendingPathComponent("checkouts/\(name)")
                let isCheckedOut = FileManager.default.fileExists(atPath: checkoutDir)

                let (sz, _) = isCheckedOut ? directorySize(at: checkoutDir, maxFiles: 1_000) : (UInt64(0), 0)
                let health: DependencyHealthStatus = (isCheckedOut || buildExists) ? .normal : .missing
                if health == .missing {
                    missingCount += 1
                }

                packages.append(LocalPackageItem(
                    id: "proj:\(projectName):\(name)",
                    name: name,
                    installedVersion: version,
                    declaredVersion: version,
                    ecosystem: .swift,
                    scope: .projectDependency,
                    healthStatus: health,
                    summary: "Swift Package Manager 依赖库",
                    installPath: isCheckedOut ? checkoutDir : root,
                    fileSizeBytes: sz,
                    projectName: projectName
                ))
            }
        } else {
            // 没有 Package.resolved 时，简易探测 Package.swift 中的依赖声明
            let pkgSwift = (root as NSString).appendingPathComponent("Package.swift")
            if let content = try? String(contentsOfFile: pkgSwift, encoding: .utf8) {
                for line in content.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.contains(".package(") && trimmed.contains("url:") {
                        // 提取 url 或名称
                        if let urlRange = trimmed.range(of: "url:") {
                            let afterUrl = trimmed[urlRange.upperBound...].trimmingCharacters(in: .whitespaces)
                            let parts = afterUrl.components(separatedBy: "\"")
                            if parts.count >= 2 {
                                let url = parts[1]
                                let name = (url as NSString).lastPathComponent.replacingOccurrences(of: ".git", with: "")
                                let health: DependencyHealthStatus = buildExists ? .normal : .missing
                                if health == .missing { missingCount += 1 }
                                packages.append(LocalPackageItem(
                                    id: "proj:\(projectName):\(name)",
                                    name: name,
                                    installedVersion: nil,
                                    declaredVersion: "Package.swift",
                                    ecosystem: .swift,
                                    scope: .projectDependency,
                                    healthStatus: health,
                                    summary: url,
                                    installPath: root,
                                    fileSizeBytes: 0,
                                    projectName: projectName
                                ))
                            }
                        }
                    }
                }
            }
        }

        if packages.isEmpty && totalCacheSize == 0 {
            return nil
        }

        return ProjectDependencySummary(
            id: root,
            name: projectName,
            rootPath: root,
            ecosystem: .swift,
            dependenciesSizeBytes: totalCacheSize,
            directDependenciesCount: packages.count,
            missingDependenciesCount: missingCount,
            packages: packages.sorted { $0.name.lowercased() < $1.name.lowercased() },
            cacheDirectoryName: buildExists ? ".build" : nil
        )
    }

    // MARK: - Rust Cargo Project Scanner
    private static func scanRustProject(root: String, projectName: String) -> ProjectDependencySummary? {
        let targetPath = (root as NSString).appendingPathComponent("target")
        let targetExists = FileManager.default.fileExists(atPath: targetPath)
        var totalCacheSize: UInt64 = 0

        if targetExists {
            let (sz, _) = directorySize(at: targetPath, maxFiles: 30_000)
            totalCacheSize = sz
        }

        var packages: [LocalPackageItem] = []
        var missingCount = 0

        let lockPath = (root as NSString).appendingPathComponent("Cargo.lock")
        if let content = try? String(contentsOfFile: lockPath, encoding: .utf8) {
            let lines = content.components(separatedBy: "\n")
            var currentName: String? = nil
            var currentVer: String? = nil
            var currentSource: String? = nil

            func flush() {
                if let name = currentName, let ver = currentVer, name != projectName {
                    let isReg = currentSource?.contains("registry") ?? true
                    let health: DependencyHealthStatus = targetExists ? .normal : .missing
                    if health == .missing { missingCount += 1 }
                    packages.append(LocalPackageItem(
                        id: "proj:\(projectName):\(name)",
                        name: name,
                        installedVersion: ver,
                        declaredVersion: ver,
                        ecosystem: .rust,
                        scope: .projectDependency,
                        healthStatus: health,
                        summary: isReg ? "crates.io 注册依赖 crate" : nil,
                        installPath: lockPath,
                        fileSizeBytes: 0,
                        projectName: projectName
                    ))
                }
                currentName = nil
                currentVer = nil
                currentSource = nil
            }

            for line in lines {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t == "[[package]]" {
                    flush()
                } else if t.hasPrefix("name = ") {
                    currentName = t.replacingOccurrences(of: "name = ", with: "").replacingOccurrences(of: "\"", with: "")
                } else if t.hasPrefix("version = ") {
                    currentVer = t.replacingOccurrences(of: "version = ", with: "").replacingOccurrences(of: "\"", with: "")
                } else if t.hasPrefix("source = ") {
                    currentSource = t.replacingOccurrences(of: "source = ", with: "").replacingOccurrences(of: "\"", with: "")
                }
            }
            flush()
        }

        if packages.isEmpty && totalCacheSize == 0 {
            return nil
        }

        return ProjectDependencySummary(
            id: root,
            name: projectName,
            rootPath: root,
            ecosystem: .rust,
            dependenciesSizeBytes: totalCacheSize,
            directDependenciesCount: packages.count,
            missingDependenciesCount: missingCount,
            packages: packages.sorted { $0.name.lowercased() < $1.name.lowercased() },
            cacheDirectoryName: targetExists ? "target" : nil
        )
    }

    // MARK: - Java Maven/Gradle Project Scanner
    private static func scanJavaProject(root: String, projectName: String) -> ProjectDependencySummary? {
        let targetPath = (root as NSString).appendingPathComponent("target")
        let buildPath = (root as NSString).appendingPathComponent("build")
        var cacheDirName: String? = nil
        var totalCacheSize: UInt64 = 0

        if FileManager.default.fileExists(atPath: targetPath) {
            cacheDirName = "target"
            let (sz, _) = directorySize(at: targetPath, maxFiles: 30_000)
            totalCacheSize = sz
        } else if FileManager.default.fileExists(atPath: buildPath) {
            cacheDirName = "build"
            let (sz, _) = directorySize(at: buildPath, maxFiles: 30_000)
            totalCacheSize = sz
        }

        var packages: [LocalPackageItem] = []
        let pomPath = (root as NSString).appendingPathComponent("pom.xml")
        if let content = try? String(contentsOfFile: pomPath, encoding: .utf8) {
            let chunks = content.components(separatedBy: "<dependency>")
            for chunk in chunks.dropFirst() {
                guard let endRange = chunk.range(of: "</dependency>") else { continue }
                let depBlock = String(chunk[..<endRange.lowerBound])
                func tagValue(_ tag: String) -> String? {
                    guard let start = depBlock.range(of: "<\(tag)>"),
                          let end = depBlock.range(of: "</\(tag)>") else { return nil }
                    return String(depBlock[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let artifact = tagValue("artifactId") {
                    let group = tagValue("groupId")
                    let version = tagValue("version")
                    let fullName = group != nil ? "\(group!):\(artifact)" : artifact
                    packages.append(LocalPackageItem(
                        id: "proj:\(projectName):\(fullName)",
                        name: fullName,
                        installedVersion: version,
                        declaredVersion: version,
                        ecosystem: .java,
                        scope: .projectDependency,
                        healthStatus: cacheDirName != nil ? .normal : .missing,
                        summary: "Maven 构件",
                        installPath: pomPath,
                        fileSizeBytes: 0,
                        projectName: projectName
                    ))
                }
            }
        }

        if packages.isEmpty && totalCacheSize == 0 {
            return nil
        }

        return ProjectDependencySummary(
            id: root,
            name: projectName,
            rootPath: root,
            ecosystem: .java,
            dependenciesSizeBytes: totalCacheSize,
            directDependenciesCount: packages.count,
            missingDependenciesCount: cacheDirName == nil ? packages.count : 0,
            packages: packages.sorted { $0.name.lowercased() < $1.name.lowercased() },
            cacheDirectoryName: cacheDirName
        )
    }

    /// 快速探索开发者常见项目目录 (支持 Node、Python、Swift、Rust 等)
    public static func discoverProjectPaths(
        searchRoots: [String] = [NSHomeDirectory() + "/Documents"],
        maxDepth: Int = 3
    ) -> [String] {
        var found: [String] = []
        let skipDirs: Set<String> = [
            "node_modules", ".git", ".venv", "venv", "env", ".build", "dist", "build", "target", "Pods", "DerivedData", "Library", "Applications"
        ]

        func search(dir: String, depth: Int) {
            guard depth <= maxDepth else { return }
            guard let children = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }
            let hasManifest = children.contains("package.json") ||
                              children.contains("node_modules") ||
                              children.contains("pyproject.toml") ||
                              children.contains("requirements.txt") ||
                              children.contains("Pipfile") ||
                              children.contains(".venv") ||
                              children.contains("venv") ||
                              children.contains("Package.swift") ||
                              children.contains("Package.resolved") ||
                              children.contains(".build") ||
                              children.contains("Cargo.toml") ||
                              children.contains("Cargo.lock") ||
                              children.contains("pom.xml") ||
                              children.contains("build.gradle")
            if hasManifest {
                found.append(dir)
            }
            for child in children where !child.hasPrefix(".") && !skipDirs.contains(child) {
                let sub = (dir as NSString).appendingPathComponent(child)
                var st = stat()
                if sub.withCString({ lstat($0, &st) }) == 0 && (st.st_mode & S_IFMT) == S_IFDIR {
                    search(dir: sub, depth: depth + 1)
                }
            }
        }

        for root in searchRoots {
            if FileManager.default.fileExists(atPath: root) {
                search(dir: root, depth: 1)
            }
        }
        return found
    }

    // MARK: - Private Helpers

    /// 简单的版本偏离检测 (例如声明 "^18.0.0" 但安装了 "19.0.0")
    private static func isVersionMismatched(declared: String, installed: String) -> Bool {
        let decClean = declared.trimmingCharacters(in: CharacterSet(charactersIn: "^~>=<v "))
        let instClean = installed.trimmingCharacters(in: CharacterSet(charactersIn: "v "))
        let decMajor = decClean.split(separator: ".").first
        let instMajor = instClean.split(separator: ".").first
        if let d = decMajor, let i = instMajor, !d.isEmpty, !i.isEmpty {
            return d != i
        }
        return false
    }
}
