import Darwin
import Foundation

extension PackageScanner {
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

        // 探测目录：nvm versions/*/bin 以及 ~/.npm-global/bin, ~/.bun/bin, fnm, volta, pnpm, yarn, asdf, mise, homebrew node
        var binDirs: [String] = []
        let nvmNode = (home as NSString).appendingPathComponent(".nvm/versions/node")
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvmNode) {
            for v in versions where !v.hasPrefix(".") {
                let bin = (nvmNode as NSString).appendingPathComponent("\(v)/bin")
                binDirs.append(bin)
            }
        }
        let additionalBins = [
            (home as NSString).appendingPathComponent(".npm-global/bin"),
            (home as NSString).appendingPathComponent(".bun/bin"),
            (home as NSString).appendingPathComponent("Library/pnpm"),
            (home as NSString).appendingPathComponent(".local/share/pnpm"),
            (home as NSString).appendingPathComponent(".yarn/bin"),
            (home as NSString).appendingPathComponent(".config/yarn/global/node_modules/.bin"),
            (home as NSString).appendingPathComponent(".volta/bin"),
            (home as NSString).appendingPathComponent(".fnm/current/bin"),
            (home as NSString).appendingPathComponent(".local/share/fnm/current/bin"),
            (home as NSString).appendingPathComponent(".asdf/shims"),
            (home as NSString).appendingPathComponent(".local/share/mise/shims"),
            "/opt/homebrew/lib/node_modules/.bin",
            "/usr/local/lib/node_modules/.bin"
        ]
        for b in additionalBins where FileManager.default.fileExists(atPath: b) {
            binDirs.append(b)
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

    // MARK: - Homebrew Global CLI & Package Scanner
    private static func scanHomebrewGlobalCliTools(home: String, seenIds: inout Set<String>) -> [LocalPackageItem] {
        var results: [LocalPackageItem] = []
        var prefixes = ["/opt/homebrew", "/usr/local"]
        if let envPrefix = ProcessInfo.processInfo.environment["HOMEBREW_PREFIX"], !prefixes.contains(envPrefix) {
            prefixes.insert(envPrefix, at: 0)
        }
        let testArm = (home as NSString).appendingPathComponent("opt/homebrew")
        let testIntel = (home as NSString).appendingPathComponent("usr/local")
        if FileManager.default.fileExists(atPath: testArm) && !prefixes.contains(testArm) {
            prefixes.append(testArm)
        }
        if FileManager.default.fileExists(atPath: testIntel) && !prefixes.contains(testIntel) {
            prefixes.append(testIntel)
        }

        for prefix in prefixes {
            guard FileManager.default.fileExists(atPath: prefix) else { continue }
            let cellar = (prefix as NSString).appendingPathComponent("Cellar")
            let caskroom = (prefix as NSString).appendingPathComponent("Caskroom")
            let binDir = (prefix as NSString).appendingPathComponent("bin")

            // 1. 扫描 Cellar (Formulae 命令行与库包)
            if let formulae = try? FileManager.default.contentsOfDirectory(atPath: cellar) {
                for formula in formulae where !formula.hasPrefix(".") {
                    let formulaDir = (cellar as NSString).appendingPathComponent(formula)
                    guard let versions = try? FileManager.default.contentsOfDirectory(atPath: formulaDir) else { continue }
                    let validVersions = versions.filter { !$0.hasPrefix(".") }
                    guard let latestVer = validVersions.sorted().last else { continue }
                    let verDir = (formulaDir as NSString).appendingPathComponent(latestVer)

                    let id = "cli:brew:\(formula)"
                    guard !seenIds.contains(id) else { continue }

                    var summary: String? = nil
                    var license: String? = nil
                    var installedOnRequest: Bool = false
                    var installDate = Date()

                    let receiptPath = (verDir as NSString).appendingPathComponent("INSTALL_RECEIPT.json")
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: receiptPath)),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let req = json["installed_on_request"] as? Bool {
                            installedOnRequest = req
                        }
                        if let time = json["time"] as? TimeInterval {
                            installDate = Date(timeIntervalSince1970: time)
                        }
                        if let lic = json["license"] as? String {
                            license = lic
                        }
                        if let desc = json["desc"] as? String {
                            summary = desc
                        }
                    }

                    let candidateBin = (binDir as NSString).appendingPathComponent(formula)
                    let execPath = FileManager.default.fileExists(atPath: candidateBin) ? candidateBin : nil
                    let (formulaSize, _) = directorySize(at: verDir, maxFiles: 1_000)

                    let rule = featuredCliCatalog[formula.lowercased()]
                    let isFeatured = (rule != nil) || installedOnRequest
                    let categoryTag = rule?.tag ?? (installedOnRequest ? "独立软件" : "基础依赖")
                    let finalSummary = rule?.summary ?? summary ?? "Homebrew Formula 软件包"

                    seenIds.insert(id)
                    results.append(LocalPackageItem(
                        id: id,
                        name: formula,
                        installedVersion: latestVer,
                        declaredVersion: nil,
                        ecosystem: .homebrew,
                        scope: .globalCli,
                        healthStatus: .normal,
                        summary: finalSummary,
                        license: license,
                        installPath: verDir,
                        executablePath: execPath,
                        fileSizeBytes: formulaSize,
                        lastModified: installDate,
                        projectName: nil,
                        isDevDependency: false,
                        isFeatured: isFeatured,
                        categoryTag: categoryTag
                    ))
                }
            }

            // 2. 扫描 Caskroom (Cask 独立桌面应用与开发工具)
            if let casks = try? FileManager.default.contentsOfDirectory(atPath: caskroom) {
                for cask in casks where !cask.hasPrefix(".") {
                    let caskDir = (caskroom as NSString).appendingPathComponent(cask)
                    guard let versions = try? FileManager.default.contentsOfDirectory(atPath: caskDir) else { continue }
                    let validVersions = versions.filter { !$0.hasPrefix(".") }
                    guard let latestVer = validVersions.sorted().last else { continue }
                    let verDir = (caskDir as NSString).appendingPathComponent(latestVer)

                    let id = "cli:cask:\(cask)"
                    guard !seenIds.contains(id) else { continue }

                    let (caskSize, _) = directorySize(at: verDir, maxFiles: 500)
                    let rule = featuredCliCatalog[cask.lowercased()]

                    seenIds.insert(id)
                    results.append(LocalPackageItem(
                        id: id,
                        name: cask,
                        installedVersion: latestVer,
                        declaredVersion: nil,
                        ecosystem: .homebrew,
                        scope: .globalCli,
                        healthStatus: .normal,
                        summary: rule?.summary ?? "Homebrew Cask 独立应用",
                        license: nil,
                        installPath: verDir,
                        executablePath: nil,
                        fileSizeBytes: caskSize,
                        lastModified: safeStat(at: verDir)?.mtime ?? Date(),
                        projectName: nil,
                        isDevDependency: false,
                        isFeatured: true,
                        categoryTag: "Homebrew Cask"
                    ))
                }
            }

            // 3. 补充 /bin 下其他非 Cellar 软链接或工具
            if let files = try? FileManager.default.contentsOfDirectory(atPath: binDir) {
                for file in files where !file.hasPrefix(".") {
                    let binPath = (binDir as NSString).appendingPathComponent(file)
                    guard let st = safeStat(at: binPath), !st.isDir else { continue }
                    let id = "cli:brew:\(file)"
                    guard !seenIds.contains(id) else { continue }

                    var version: String? = nil
                    var installPath = binPath

                    if st.isSymlink {
                        let resolved = URL(fileURLWithPath: binPath).resolvingSymlinksInPath().path
                        installPath = resolved
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
                    let finalSummary = rule?.summary ?? "Homebrew 命令行工具"

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

}
