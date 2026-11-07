import Darwin
import Foundation
import Testing
@testable import Work

func cpuNow() -> UInt64 { clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) }
func instructionsNow() -> UInt64 {
    var info = rusage_info_v4()
    let r = withUnsafeMutablePointer(to: &info) { p in
        p.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0) }
    }
    return r == 0 ? info.ri_instructions : 0
}

/// A fixed CPU workload: integer hashing, no allocation, no system frameworks.
@inline(never) func calibration() -> UInt64 {
    var h: UInt64 = 1469598103934665603
    for i in 0..<3_000_000 { h = (h ^ UInt64(i)) &* 1099511628211 }
    return h
}

struct Sample { var wall: Double; var cpu: Double; var instr: Double }
func run(_ body: () -> Void) -> [Sample] {
    for _ in 0..<3 { body() }
    return (0..<15).map { _ in
        let i0 = instructionsNow(); let c0 = cpuNow(); let t0 = ContinuousClock.now
        body()
        let d = ContinuousClock.now - t0; let c1 = cpuNow(); let i1 = instructionsNow()
        return Sample(wall: Double(d.components.attoseconds) / 1e15 + Double(d.components.seconds) * 1000,
                      cpu: Double(c1 - c0) / 1e6, instr: Double(i1 - i0) / 1e6)
    }
}
func med(_ a: [Double]) -> Double { let s = a.sorted(); return s[s.count / 2] }

@Test func measure() {
    let data = Library.data(count: 10_000)
    let slow = ProcessInfo.processInfo.environment["SLOW"] == "1"
    var sink: UInt64 = 0
    let op = run { _ = Library.load(data, slow: slow) }
    let cal = run { sink &+= calibration() }
    let w = med(op.map(\.wall)), c = med(op.map(\.cpu)), n = med(op.map(\.instr))
    let cw = med(cal.map(\.wall)), cc = med(cal.map(\.cpu)), cn = med(cal.map(\.instr))
    print(String(format: "PERF wall=%.2fms cpu=%.2fms instr=%.2fM | cal wall=%.2fms instr=%.2fM | ratio wall=%.3f cpu=%.3f instr=%.3f %llu",
                 w, c, n, cw, cn, w / cw, c / cc, n / cn, sink % 2))
}
