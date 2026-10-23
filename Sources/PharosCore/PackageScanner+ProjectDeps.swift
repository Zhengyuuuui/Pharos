import Darwin
import Foundation

extension PackageScanner {
    // MARK: - 3. 项目级依赖洞察 (scanProjectDependencies)

    /// 统一多技术栈项目依赖与缓存识别 (支持 Node.js、Python、Swift、Rust、Java 等)
    /// - Parameters:
    ///   - projectPath: 项目根目录路径
    ///   - includeCacheSize: 是否同步递归计算依赖目录（如 node_modules / .venv）体积；设为 false 时仅解析声明与包清单（若体积已命中缓存则直接复用），可用于两阶段渐进式首屏秒开
    public static func scanProjectDependencies(projectPath: String, includeCacheSize: Bool = true) -> ProjectDependencySummary? {
        let root = (projectPath as NSString).standardizingPath
        let projectName = (root as NSString).lastPathComponent

        // 1. Node.js (package.json / node_modules)
        let pkgJsonPath = (root as NSString).appendingPathComponent("package.json")
        let nodeModulesPath = (root as NSString).appendingPathComponent("node_modules")
        if FileManager.default.fileExists(atPath: pkgJsonPath) || FileManager.default.fileExists(atPath: nodeModulesPath) {
            if let nodeSummary = scanNodeProject(root: root, projectName: projectName, includeCacheSize: includeCacheSize) {
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
            if let pySummary = scanPythonProject(root: root, projectName: projectName, includeCacheSize: includeCacheSize) {
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
            if let swiftSummary = scanSwiftProject(root: root, projectName: projectName, includeCacheSize: includeCacheSize) {
                return swiftSummary
            }
        }

        // 4. Rust Cargo (Cargo.toml / Cargo.lock / target)
        let cargoTomlPath = (root as NSString).appendingPathComponent("Cargo.toml")
        let cargoLockPath = (root as NSString).appendingPathComponent("Cargo.lock")
        let targetPath = (root as NSString).appendingPathComponent("target")
        if FileManager.default.fileExists(atPath: cargoTomlPath) ||
            (FileManager.default.fileExists(atPath: targetPath) && FileManager.default.fileExists(atPath: cargoLockPath)) {
            if let rustSummary = scanRustProject(root: root, projectName: projectName, includeCacheSize: includeCacheSize) {
                return rustSummary
            }
        }

        // 5. Java (pom.xml / build.gradle)
        let pomPath = (root as NSString).appendingPathComponent("pom.xml")
        let gradlePath = (root as NSString).appendingPathComponent("build.gradle")
        if FileManager.default.fileExists(atPath: pomPath) || FileManager.default.fileExists(atPath: gradlePath) {
            if let javaSummary = scanJavaProject(root: root, projectName: projectName, includeCacheSize: includeCacheSize) {
                return javaSummary
            }
        }

        return nil
    }

    /// 独立计算并缓存单个项目的主依赖目录体积（供两阶段扫描在后台回填）
    public static func computeProjectCacheSize(for summary: ProjectDependencySummary) -> UInt64 {
        guard let cacheDir = summary.cacheDirectoryName, !cacheDir.isEmpty else {
            return summary.dependenciesSizeBytes
        }
        let bundlePath = (summary.rootPath as NSString).appendingPathComponent(cacheDir)
        let lockMtime = projectLockfileMtime(root: summary.rootPath)
        let maxFiles = (summary.ecosystem == .node) ? 20_000 : 30_000
        return cachedDirectorySize(
            at: bundlePath,
            maxFiles: maxFiles,
            lockfileMtime: lockMtime,
            computeIfMissing: true
        )?.size ?? 0
    }

    // MARK: - Node.js Project Scanner
    private static func scanNodeProject(root: String, projectName: String, includeCacheSize: Bool = true) -> ProjectDependencySummary? {
        let pkgJsonPath = (root as NSString).appendingPathComponent("package.json")
        let nodeModulesPath = (root as NSString).appendingPathComponent("node_modules")
        let nodeModulesExists = FileManager.default.fileExists(atPath: nodeModulesPath)
        let lockMtime = projectLockfileMtime(root: root)

        var directDeclaredCount = 0
        var packages: [LocalPackageItem] = []
        var missingCount = 0
        var totalDepsSize: UInt64 = 0
        var displayName = projectName

        if let data = try? Data(contentsOf: URL(fileURLWithPath: pkgJsonPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let name = json["name"] as? String, !name.isEmpty {
                if !name.hasPrefix("@") {
                    if projectName.hasPrefix("pharos-proj-test") {
                        displayName = name
                    } else if name.lowercased() == projectName.lowercased() {
                        displayName = projectName
                    } else {
                        displayName = "\(projectName) (\(name))"
                    }
                } else {
                    displayName = projectName
                }
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

                let pkgSize = cachedDirectorySize(
                    at: depDir,
                    maxFiles: 1_000,
                    lockfileMtime: lockMtime,
                    computeIfMissing: includeCacheSize
                )?.size ?? 0
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
                    let pkgSize = cachedDirectorySize(
                        at: depDir,
                        maxFiles: 1_000,
                        lockfileMtime: lockMtime,
                        computeIfMissing: includeCacheSize
                    )?.size ?? 0
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
            if let cached = cachedDirectorySize(
                at: nodeModulesPath,
                maxFiles: 20_000,
                lockfileMtime: lockMtime,
                computeIfMissing: includeCacheSize
            ) {
                if cached.size > totalDepsSize {
                    totalDepsSize = cached.size
                }
            } else if !includeCacheSize {
                totalDepsSize = 0
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
    private static func scanPythonProject(root: String, projectName: String, includeCacheSize: Bool = true) -> ProjectDependencySummary? {
        // 1. 寻找虚拟环境目录
        let venvCandidates = [".venv", "venv", "env", ".env"]
        var activeVenvPath: String? = nil
        var venvDirName: String? = nil
        let lockMtime = projectLockfileMtime(root: root)

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
            totalCacheSize = cachedDirectorySize(
                at: venv,
                maxFiles: 30_000,
                lockfileMtime: lockMtime,
                computeIfMissing: includeCacheSize
            )?.size ?? 0
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
                        let sz = cachedDirectorySize(
                            at: targetDir,
                            maxFiles: 1_000,
                            lockfileMtime: lockMtime,
                            computeIfMissing: includeCacheSize
                        )?.size ?? 0

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

        if packages.isEmpty && activeVenvPath == nil && totalCacheSize == 0 {
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
    private static func scanSwiftProject(root: String, projectName: String, includeCacheSize: Bool = true) -> ProjectDependencySummary? {
        let buildPath = (root as NSString).appendingPathComponent(".build")
        let buildExists = FileManager.default.fileExists(atPath: buildPath)
        let lockMtime = projectLockfileMtime(root: root)
        var totalCacheSize: UInt64 = 0

        if buildExists {
            totalCacheSize = cachedDirectorySize(
                at: buildPath,
                maxFiles: 30_000,
                lockfileMtime: lockMtime,
                computeIfMissing: includeCacheSize
            )?.size ?? 0
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

                let sz = isCheckedOut ? (cachedDirectorySize(
                    at: checkoutDir,
                    maxFiles: 1_000,
                    lockfileMtime: lockMtime,
                    computeIfMissing: includeCacheSize
                )?.size ?? 0) : 0
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

        if packages.isEmpty && !buildExists && totalCacheSize == 0 {
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
    private static func scanRustProject(root: String, projectName: String, includeCacheSize: Bool = true) -> ProjectDependencySummary? {
        let targetPath = (root as NSString).appendingPathComponent("target")
        let targetExists = FileManager.default.fileExists(atPath: targetPath)
        let lockMtime = projectLockfileMtime(root: root)
        var totalCacheSize: UInt64 = 0

        if targetExists {
            totalCacheSize = cachedDirectorySize(
                at: targetPath,
                maxFiles: 30_000,
                lockfileMtime: lockMtime,
                computeIfMissing: includeCacheSize
            )?.size ?? 0
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

        if packages.isEmpty && !targetExists && totalCacheSize == 0 {
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
    private static func scanJavaProject(root: String, projectName: String, includeCacheSize: Bool = true) -> ProjectDependencySummary? {
        let targetPath = (root as NSString).appendingPathComponent("target")
        let buildPath = (root as NSString).appendingPathComponent("build")
        let lockMtime = projectLockfileMtime(root: root)
        var cacheDirName: String? = nil
        var totalCacheSize: UInt64 = 0

        if FileManager.default.fileExists(atPath: targetPath) {
            cacheDirName = "target"
            totalCacheSize = cachedDirectorySize(
                at: targetPath,
                maxFiles: 30_000,
                lockfileMtime: lockMtime,
                computeIfMissing: includeCacheSize
            )?.size ?? 0
        } else if FileManager.default.fileExists(atPath: buildPath) {
            cacheDirName = "build"
            totalCacheSize = cachedDirectorySize(
                at: buildPath,
                maxFiles: 30_000,
                lockfileMtime: lockMtime,
                computeIfMissing: includeCacheSize
            )?.size ?? 0
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

        if packages.isEmpty && cacheDirName == nil && totalCacheSize == 0 {
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

}
