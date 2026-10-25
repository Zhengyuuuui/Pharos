import Foundation
import PharosCore

func testOllamaManifestParsingAndBlobGC() {
    let tempHome = NSTemporaryDirectory() + "pharos-ollama-\(UUID().uuidString)"
    let manifestsDir = tempHome + "/.ollama/models/manifests/registry.ollama.ai/library/test-model"
    let blobsDir = tempHome + "/.ollama/models/blobs"
    defer { try? FileManager.default.removeItem(atPath: tempHome) }

    try? FileManager.default.createDirectory(atPath: manifestsDir, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: blobsDir, withIntermediateDirectories: true)

    let manifestJSON = """
    {
      "schemaVersion": 2,
      "config": { "digest": "sha256:cfg111111", "size": 100 },
      "layers": [
        { "digest": "sha256:layer222222", "size": 5000 },
        { "digest": "sha256:layer333333", "size": 15000 }
      ]
    }
    """
    let manifestPath = manifestsDir + "/latest"
    FileManager.default.createFile(atPath: manifestPath, contents: manifestJSON.data(using: .utf8))

    // Parse manifest
    guard let (name, tag, size) = AIModelCleaner.parseOllamaManifest(at: manifestPath) else {
        expect(false, "manifest parsing failed")
        return
    }
    expectEq(name, "test-model", "model name extracted")
    expectEq(tag, "latest", "tag extracted")
    expectEq(size, UInt64(20100), "size summed (100 + 5000 + 15000)")

    // Create blobs: 2 referenced by manifest, 1 orphaned blob
    let blobReferenced = blobsDir + "/sha256-layer222222"
    let blobOrphan = blobsDir + "/sha256-orphan999999"
    FileManager.default.createFile(atPath: blobReferenced, contents: Data(repeating: 1, count: 5000))
    FileManager.default.createFile(atPath: blobOrphan, contents: Data(repeating: 2, count: 8000))

    // Run GC: orphan blob should be deleted, referenced blob kept
    AIModelCleaner.garbageCollectOllamaBlobs(home: tempHome)
    expect(FileManager.default.fileExists(atPath: blobReferenced), "referenced blob kept")
    expect(!FileManager.default.fileExists(atPath: blobOrphan), "orphan blob garbage collected")

    // Delete the model: manifest removed, and remaining blobs GC'd
    let modelItem = AIModelCleaner.AIModelItem(
        name: "test-model",
        tag: "latest",
        framework: .ollama,
        path: manifestPath,
        size: size,
        lastModified: Date()
    )
    let deleted = (try? AIModelCleaner.deleteModel(modelItem, home: tempHome)) ?? false
    expect(deleted, "deleteModel succeeded")
    expect(!FileManager.default.fileExists(atPath: manifestPath), "manifest removed")
    expect(!FileManager.default.fileExists(atPath: blobReferenced), "layer blob now also garbage collected")
}

func testHuggingFaceAndLMStudioScanning() {
    let tempHome = NSTemporaryDirectory() + "pharos-hf-\(UUID().uuidString)"
    let hubDir = tempHome + "/.cache/huggingface/hub/models--Qwen--Qwen2.5-Coder-7B"
    defer { try? FileManager.default.removeItem(atPath: tempHome) }

    try? FileManager.default.createDirectory(atPath: hubDir + "/snapshots", withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: hubDir + "/snapshots/weight.bin", contents: Data(repeating: 1, count: 1024))

    let models = AIModelCleaner.scanHuggingFaceModels(home: tempHome)
    expectEq(models.count, 1, "found 1 Hugging Face model")
    expectEq(models.first?.name, "Qwen/Qwen2.5-Coder-7B", "parsed org/repo model name correctly")
    expectEq(models.first?.framework, .huggingFace, "framework is huggingFace")
}
