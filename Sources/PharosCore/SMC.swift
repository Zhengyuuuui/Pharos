import Foundation
import IOKit

/// Minimal client for Apple's System Management Controller (fans, temperatures).
///
/// Not public Apple API: the struct layout and key names come from the open
/// research in agoodkind/macos-smc-fan (MIT) and ThermalForge (MIT). Reads work
/// for any user; writes are refused unless the process runs as root, which is
/// why only the `pharos-fand` helper calls `write`.
public final class SMCClient {
    private let connection: io_connect_t

    public init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var conn: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == KERN_SUCCESS else { return nil }
        connection = conn
    }

    deinit { IOServiceClose(connection) }

    public struct Value: Equatable, Sendable {
        public let type: String
        public let bytes: [UInt8]
    }

    public func read(_ key: String) -> Value? {
        guard let info = keyInfo(key) else { return nil }
        var input = SMCParam()
        input.key = SMCCodec.fourCC(key)
        input.keyInfo.dataSize = info.size
        input.data8 = SMCParam.Command.readBytes
        guard let out = call(input), out.result == 0 else { return nil }
        return Value(type: SMCCodec.string(info.type), bytes: Array(out.byteArray.prefix(Int(info.size))))
    }

    /// Returns false when the firmware rejects the write (not root, key locked, wrong size).
    @discardableResult
    public func write(_ key: String, _ bytes: [UInt8]) -> Bool {
        guard let info = keyInfo(key) else { return false }
        var input = SMCParam()
        input.key = SMCCodec.fourCC(key)
        input.keyInfo.dataSize = info.size
        input.data8 = SMCParam.Command.writeBytes
        input.setBytes(bytes)
        guard let out = call(input) else { return false }
        return out.result == 0
    }

    public func exists(_ key: String) -> Bool { keyInfo(key) != nil }

    public func keyCount() -> Int {
        guard let v = read("#KEY"), v.bytes.count >= 4 else { return 0 }
        return Int(v.bytes.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) })
    }

    public func key(at index: Int) -> String? {
        var input = SMCParam()
        input.data8 = SMCParam.Command.keyAtIndex
        input.data32 = UInt32(index)
        guard let out = call(input), out.result == 0 else { return nil }
        return SMCCodec.string(out.key)
    }

    public func readFloat(_ key: String) -> Float? { read(key).flatMap(SMCCodec.float) }
    public func readUInt8(_ key: String) -> UInt8? { read(key)?.bytes.first }

    // MARK: - Private

    private func keyInfo(_ key: String) -> (size: UInt32, type: UInt32)? {
        guard key.utf8.count == 4 else { return nil }
        var input = SMCParam()
        input.key = SMCCodec.fourCC(key)
        input.data8 = SMCParam.Command.keyInfo
        guard let out = call(input), out.result == 0, out.keyInfo.dataSize > 0 else { return nil }
        return (out.keyInfo.dataSize, out.keyInfo.dataType)
    }

    private func call(_ input: SMCParam) -> SMCParam? {
        var input = input
        var output = SMCParam()
        var size = MemoryLayout<SMCParam>.stride
        let r = IOConnectCallStructMethod(connection, 2, &input, MemoryLayout<SMCParam>.stride, &output, &size)
        return r == KERN_SUCCESS ? output : nil
    }
}

/// Value encodings used by SMC keys. Pure, unit-tested.
public enum SMCCodec {
    public static func fourCC(_ s: String) -> UInt32 { s.utf8.reduce(0) { ($0 << 8) | UInt32($1) } }

    public static func string(_ code: UInt32) -> String {
        String(decoding: [24, 16, 8, 0].map { UInt8((code >> $0) & 0xFF) }, as: UTF8.self)
    }

    /// Apple Silicon `flt `: 4-byte little-endian IEEE 754.
    public static func float(_ bytes: [UInt8]) -> Float? {
        guard bytes.count == 4 else { return nil }
        let raw = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
        return Float(bitPattern: raw)
    }

    public static func float(_ v: SMCClient.Value) -> Float? {
        switch v.type {
        case "flt ": return float(v.bytes)
        case "ioft": return ioft(v.bytes)
        default: return nil
        }
    }

    /// `ioft`: little-endian 16.16 fixed point in the first 4 of 8 bytes (M5 GPU sensors).
    public static func ioft(_ bytes: [UInt8]) -> Float? {
        guard bytes.count >= 4 else { return nil }
        let raw = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
        return Float(raw >> 16) + Float(raw & 0xFFFF) / 65536
    }

    public static func bytes(_ value: Float) -> [UInt8] {
        let raw = value.bitPattern
        return [0, 8, 16, 24].map { UInt8((raw >> $0) & 0xFF) }
    }
}

/// The 80-byte struct the AppleSMC user client expects (selector 2).
struct SMCParam {
    enum Command {
        static let readBytes: UInt8 = 5
        static let writeBytes: UInt8 = 6
        static let keyAtIndex: UInt8 = 8
        static let keyInfo: UInt8 = 9
    }

    struct Version { var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0; var release: UInt16 = 0 }
    struct PLimit { var version: UInt16 = 0, length: UInt16 = 0; var cpu: UInt32 = 0, gpu: UInt32 = 0, mem: UInt32 = 0 }
    struct KeyInfo { var dataSize: UInt32 = 0, dataType: UInt32 = 0; var dataAttributes: UInt8 = 0 }
    typealias Bytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                       UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                       UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                       UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    var key: UInt32 = 0
    var version = Version()
    var pLimit = PLimit()
    var keyInfo = KeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: Bytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

    /// Borrowed view of the tuple; no manual allocation.
    var byteArray: [UInt8] { withUnsafeBytes(of: bytes) { Array($0) } }

    mutating func setBytes(_ values: [UInt8]) {
        withUnsafeMutableBytes(of: &bytes) { buf in
            for (i, b) in values.prefix(buf.count).enumerated() { buf[i] = b }
        }
    }
}
