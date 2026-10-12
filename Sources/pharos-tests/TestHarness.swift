import Foundation

nonisolated(unsafe) var testFailures = 0
nonisolated(unsafe) var testCount = 0

func expect(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    testCount += 1
    if !condition {
        testFailures += 1
        print("FAIL: \(message)  [\((file as NSString).lastPathComponent):\(line)]")
    }
}

func expectEq<T: Equatable>(_ a: T, _ b: T, _ message: String = "", file: String = #file, line: Int = #line) {
    expect(a == b, "\(message) — expected \(b), got \(a)", file: file, line: line)
}

func finishTests() -> Never {
    if testFailures == 0 {
        print("OK — \(testCount) assertions passed")
        exit(0)
    } else {
        print("\(testFailures)/\(testCount) assertions FAILED")
        exit(1)
    }
}
