import Darwin
import Foundation

/// Scans and safely removes local AI model weights and checkpoints.
///
/// Local AI tooling frequently stores massive model weights on disk:
/// - Ollama: `~/.ollama/models/manifests` and `~/.ollama/models/blobs`
/// - Hugging Face: `~/.cache/huggingface/hub/models--*`
/// - LM Studio: `~/.cache/lm-studio/models` and `~/.lmstudio/models`
/// - PyTorch / Torch Hub: `~/.cache/torch/hub/checkpoints`
///
/// AIModelCleaner accurately parses model manifests, computes exact weights sizes,
/// and performs layer-level blob garbage collection when an Ollama model is removed.
public enum AIModelCleaner {

    public enum Framework: String, Sendable, CaseIterable {
        case ollama = "Ollama"
        case huggingFace = "Hugging Face"
        case lmStudio = "LM Studio"
        case pytorch = "PyTorch"

        public var localizedKey: String {
            switch self {
            case .ollama: return "aiModelOllama"
            case .huggingFace: return "aiModelHuggingFace"
            case .lmStudio: return "aiModelLMStudio"
            case .pytorch: return "aiModelPyTorch"
            }
        }
    }

    public struct AIModelItem: Identifiable, Hashable, Sendable {
        public var id: String { path }
        public let name: String
        public let tag: String?
        public let framework: Framework
        public let path: String
        public let size: UInt64
        public let lastModified: Date?

        public init(
            name: String,
            tag: String?,
            framework: Framework,
            path: String,
            size: UInt64,
            lastModified: Date?
        ) {
            self.name = name
            self.tag = tag
            self.framework = framework
            self.path = path
            self.size = size
            self.lastModified = lastModified
        }

        public var fullName: String {
            if let tag = tag, !tag.isEmpty {
                return "\(name):\(tag)"
            }
            return name
        }
    }

    // MARK: - Scanning

    /// Scans all supported local AI model caches and returns detected models sorted by size.
    public static func scanAIModels(home: String = NSHomeDirectory()) -> [AIModelItem] {
        var models: [AIModelItem] = []

        // 1. Ollama models
        models.append(contentsOf: scanOllamaModels(home: home))

        // 2. Hugging Face Hub models
        models.append(contentsOf: scanHuggingFaceModels(home: home))

        // 3. LM Studio models
        models.append(contentsOf: scanLMStudioModels(home: home))

        // 4. PyTorch checkpoints
        models.append(contentsOf: scanPyTorchCheckpoints(home: home))

        return models.sorted { $0.size > $1.size }
    }

    // MARK: - Ollama Scanner

    public static func scanOllamaModels(home: String = NSHomeDirectory()) -> [AIModelItem] {
        let manifestsDir = ((home as NSString).appendingPathComponent(".ollama/models") as NSString)
            .appendingPathComponent("manifests")
        guard FileManager.default.fileExists(atPath: manifestsDir) else { return [] }

        var models: [AIModelItem] = []

        // Manifest directory structure: manifests/<registry>/<namespace>/<model>/<tag>
        // Or directly manifests/<model>/<tag>
        let url = URL(fileURLWithPath: manifestsDir)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  values.isRegularFile == true else { continue }

            let path = fileURL.path
            guard let (modelName, tag, size) = parseOllamaManifest(at: path) else { continue }
            let mtime = values.contentModificationDate

            models.append(AIModelItem(
                name: modelName,
                tag: tag,
                framework: .ollama,
                path: path,
                size: size,
                lastModified: mtime
            ))
        }

        return models
    }

    /// Parses an Ollama JSON manifest to extract model name, tag, and total layer size.
    public static func parseOllamaManifest(at path: String) -> (name: String, tag: String, size: UInt64)? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var totalSize: UInt64 = 0
        if let config = json["config"] as? [String: Any], let cfgSize = config["size"] as? UInt64 {
            totalSize += cfgSize
        } else if let config = json["config"] as? [String: Any], let cfgSize = config["size"] as? Int {
            totalSize += UInt64(max(0, cfgSize))
        }

        if let layers = json["layers"] as? [[String: Any]] {
            for layer in layers {
                if let size = layer["size"] as? UInt64 {
                    totalSize += size
                } else if let size = layer["size"] as? Int {
                    totalSize += UInt64(max(0, size))
                }
            }
        }

        // Infer name and tag from path components relative to manifests:
        // e.g. manifests/registry.ollama.ai/library/deepseek-r1/latest
        // tag = latest, name = deepseek-r1
        let tag = (path as NSString).lastPathComponent
        let parent = (path as NSString).deletingLastPathComponent
        let modelName = (parent as NSString).lastPathComponent

        return (modelName, tag, totalSize)
    }

    // MARK: - Hugging Face Scanner

    public static func scanHuggingFaceModels(home: String = NSHomeDirectory()) -> [AIModelItem] {
        let hubDir = ((home as NSString).appendingPathComponent(".cache/huggingface") as NSString)
            .appendingPathComponent("hub")
        guard FileManager.default.fileExists(atPath: hubDir),
              let entries = try? FileManager.default.contentsOfDirectory(atPath: hubDir) else {
            return []
        }

        var models: [AIModelItem] = []
        for entry in entries {
            guard entry.hasPrefix("models--") else { continue }
            let fullPath = (hubDir as NSString).appendingPathComponent(entry)
            var st = stat()
            guard lstat(fullPath, &st) == 0, (st.st_mode & S_IFMT) == S_IFDIR else { continue }
            let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))

            let (size, _) = PackageScanner.directorySize(at: fullPath, maxFiles: 10_000)
            guard size > 0 else { continue }

            // "models--org--name" -> "org/name"
            let stripped = String(entry.dropFirst("models--".count))
            let parts = stripped.components(separatedBy: "--")
            let displayName = parts.joined(separator: "/")

            models.append(AIModelItem(
                name: displayName,
                tag: nil,
                framework: .huggingFace,
                path: fullPath,
                size: size,
                lastModified: mtime
            ))
        }

        return models
    }

    // MARK: - LM Studio Scanner

    public static func scanLMStudioModels(home: String = NSHomeDirectory()) -> [AIModelItem] {
        let candidateDirs = [
            ((home as NSString).appendingPathComponent(".cache/lm-studio") as NSString).appendingPathComponent("models"),
            ((home as NSString).appendingPathComponent(".lmstudio") as NSString).appendingPathComponent("models")
        ]

        var models: [AIModelItem] = []
        for dir in candidateDirs {
            guard FileManager.default.fileExists(atPath: dir) else { continue }
            let url = URL(fileURLWithPath: dir)
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "gguf" {
                    if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                       let size = values.fileSize {
                        let name = fileURL.deletingPathExtension().lastPathComponent
                        models.append(AIModelItem(
                            name: name,
                            tag: "GGUF",
                            framework: .lmStudio,
                            path: fileURL.path,
                            size: UInt64(size),
                            lastModified: values.contentModificationDate
                        ))
                    }
                }
            }
        }
        return models
    }

    // MARK: - PyTorch Scanner

    public static func scanPyTorchCheckpoints(home: String = NSHomeDirectory()) -> [AIModelItem] {
        let checkpointsDir = ((home as NSString).appendingPathComponent(".cache/torch/hub") as NSString)
            .appendingPathComponent("checkpoints")
        guard FileManager.default.fileExists(atPath: checkpointsDir),
              let entries = try? FileManager.default.contentsOfDirectory(atPath: checkpointsDir) else {
            return []
        }

        var models: [AIModelItem] = []
        for entry in entries {
            let fullPath = (checkpointsDir as NSString).appendingPathComponent(entry)
            var st = stat()
            guard lstat(fullPath, &st) == 0, (st.st_mode & S_IFMT) == S_IFREG else { continue }
            let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec))
            let size = UInt64(st.st_size)

            models.append(AIModelItem(
                name: entry,
                tag: (entry as NSString).pathExtension,
                framework: .pytorch,
                path: fullPath,
                size: size,
                lastModified: mtime
            ))
        }
        return models
    }

    // MARK: - Deletion & Blob Garbage Collection

    /// Safely deletes a model item. For Ollama, automatically cleans unreferenced blobs.
    @discardableResult
    public static func deleteModel(_ item: AIModelItem, home: String = NSHomeDirectory()) throws -> Bool {
        let path = item.path

        switch item.framework {
        case .ollama:
            // 1. Delete the manifest file
            guard FileManager.default.fileExists(atPath: path) else { return false }
            try FileManager.default.removeItem(atPath: path)

            // 2. Prune empty parent model directory if left empty
            let parentDir = (path as NSString).deletingLastPathComponent
            _ = rmdir(parentDir)

            // 3. Garbage collect orphaned blobs
            garbageCollectOllamaBlobs(home: home)
            return true

        case .huggingFace, .lmStudio, .pytorch:
            guard FileManager.default.fileExists(atPath: path) else { return false }
            try FileManager.default.removeItem(atPath: path)
            return true
        }
    }

    /// Sweeps `~/.ollama/models/blobs`, deleting any blob file not referenced by any surviving manifest.
    public static func garbageCollectOllamaBlobs(home: String = NSHomeDirectory()) {
        let ollamaDir = (home as NSString).appendingPathComponent(".ollama/models")
        let manifestsDir = (ollamaDir as NSString).appendingPathComponent("manifests")
        let blobsDir = (ollamaDir as NSString).appendingPathComponent("blobs")

        guard FileManager.default.fileExists(atPath: manifestsDir),
              FileManager.default.fileExists(atPath: blobsDir) else {
            return
        }

        // Collect all referenced digests across all surviving manifests
        var referencedDigests = Set<String>()

        let manifestURL = URL(fileURLWithPath: manifestsDir)
        if let enumerator = FileManager.default.enumerator(
            at: manifestURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                guard let data = try? Data(contentsOf: fileURL),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }

                if let config = json["config"] as? [String: Any],
                   let digest = config["digest"] as? String {
                    referencedDigests.insert(normalizeDigest(digest))
                }
                if let layers = json["layers"] as? [[String: Any]] {
                    for layer in layers {
                        if let digest = layer["digest"] as? String {
                            referencedDigests.insert(normalizeDigest(digest))
                        }
                    }
                }
            }
        }

        // Check blobs in blobsDir
        guard let blobEntries = try? FileManager.default.contentsOfDirectory(atPath: blobsDir) else { return }

        for blob in blobEntries {
            if blob.hasPrefix(".") { continue }
            // Ollama blob filenames look like "sha256-aabd4debf0c8..."
            let normBlob = normalizeBlobFileName(blob)
            if !referencedDigests.contains(normBlob) {
                let blobPath = (blobsDir as NSString).appendingPathComponent(blob)
                try? FileManager.default.removeItem(atPath: blobPath)
            }
        }
    }

    private static func normalizeDigest(_ digest: String) -> String {
        digest.replacingOccurrences(of: ":", with: "-").lowercased()
    }

    private static func normalizeBlobFileName(_ name: String) -> String {
        name.lowercased()
    }
}
