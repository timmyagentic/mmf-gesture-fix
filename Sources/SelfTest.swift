import Foundation

func runPolicyTests() -> Bool {
    var checks: [Bool] = []
    for amplitude in [0.002, 0.2, 2.0] {
        for sign in [-1.0, 1.0] {
            var p = GesturePolicy()
            _ = p.inspect(phase: 1, time: 100, progress: sign * amplitude, velocity: 0)
            _ = p.inspect(phase: 2, time: 200, progress: sign * amplitude * 2, velocity: 0)
            checks.append(p.inspect(phase: 4, time: 300, progress: sign * amplitude * 2, velocity: -sign * 12) == 1)
            checks.append(p.inspect(phase: 4, time: 200_000_300, progress: sign * amplitude * 2, velocity: -sign * 12) == 2)
            checks.append(p.inspect(phase: 4, time: 500_000_300, progress: sign * amplitude * 2, velocity: -sign * 12) == 2)
            checks.append(p.inspect(phase: 4, time: 700_000_300, progress: sign * amplitude * 2, velocity: -sign * 12) == 0)
        }
    }
    var p = GesturePolicy()
    _ = p.inspect(phase: 1, time: 100, progress: 0.1, velocity: 0)
    _ = p.inspect(phase: 2, time: 200, progress: 0.7, velocity: 0)
    _ = p.inspect(phase: 2, time: 250, progress: 0.4, velocity: 0)
    checks.append(p.inspect(phase: 8, time: 300, progress: 0.4, velocity: -2) == 0)
    checks.append(p.inspect(phase: 8, time: 300, progress: 0.4, velocity: -2) == 3)
    _ = p.inspect(phase: 1, time: 400, progress: -0.1, velocity: 0)
    checks.append(p.inspect(phase: 4, time: 300, progress: 0.4, velocity: -2) == 0)
    p.reset()
    checks.append(p.inspect(phase: 4, time: 500, progress: -0.1, velocity: 10) == 0)
    _ = p.inspect(phase: 1, time: 600, progress: 0.1, velocity: 0)
    checks.append(p.inspect(phase: 4, time: 700, progress: .nan, velocity: 10) == 0)
    checks.append(p.inspect(phase: 4, time: 700, progress: 0.1, velocity: .infinity) == 0)
    var eligibility = Eligibility(verifiedPID: 42, helperBuild: 24898, macOSMajor: 27)
    checks.append(eligibility.accepts(pid: 42, motion: 1, flavor: 3, marked: false))
    checks.append(!eligibility.accepts(pid: 43, motion: 1, flavor: 3, marked: false))
    checks.append(!eligibility.accepts(pid: 42, motion: 2, flavor: 3, marked: false))
    checks.append(!eligibility.accepts(pid: 42, motion: 1, flavor: 4, marked: false))
    checks.append(!eligibility.accepts(pid: 42, motion: 1, flavor: 3, marked: true))
    eligibility.helperBuild = 24899
    checks.append(!eligibility.accepts(pid: 42, motion: 1, flavor: 3, marked: false))
    eligibility.helperBuild = 24898; eligibility.macOSMajor = 28
    checks.append(!eligibility.accepts(pid: 42, motion: 1, flavor: 3, marked: false))
    print("Policy checks: \(checks.filter { $0 }.count)/\(checks.count)")
    return checks.allSatisfy { $0 }
}
