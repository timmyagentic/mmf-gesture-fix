import Foundation

struct GesturePolicy {
    private var active = false
    private var started: UInt64 = 0
    private var previous = 0.0
    private var movement = 0.0
    private var terminal: (time: UInt64, phase: Int, progress: Double, velocity: Double, flip: Bool)?

    mutating func reset() { self = GesturePolicy() }

    // Pure policy. It never posts input or changes the system's gesture progress.
    mutating func inspect(phase: Int, time: UInt64, progress: Double, velocity: Double) -> Int {
        guard progress.isFinite, velocity.isFinite else { return 0 }
        if phase == 1 {
            active = true; started = time; previous = progress; movement = progress
            terminal = nil
            return 0
        }
        if active && time < started { return 0 }
        if phase == 2 {
            guard active else { terminal = nil; return 0 }
            let delta = progress - previous
            if abs(delta) > 0.000001 { movement = delta }
            previous = progress
            return 0
        }
        guard phase == 4 || phase == 8 else { return 0 }
        if !active {
            // The official helper reposts the same terminal payload after
            // 200/500 ms. Accept either preserved or restamped CG timestamps.
            if let end = terminal, time >= end.time, time - end.time <= 600_000_000,
               end.phase == phase, end.progress == progress, end.velocity == velocity {
                return end.flip ? 2 : 3
            }
            return 0
        }
        let delta = progress - previous
        if abs(delta) > 0.000001 { movement = delta }
        let flip = abs(movement) > 0.000001 && abs(velocity) > 0.000001
            && (movement > 0) != (velocity > 0)
        active = false
        terminal = (time, phase, progress, velocity, flip)
        return flip ? 1 : 0
    }
}

struct Eligibility {
    var verifiedPID: Int32
    var helperBuild: Int32
    var macOSMajor: Int
    func accepts(pid: Int32, motion: Int, flavor: Int, marked: Bool) -> Bool {
        verifiedPID > 0 && pid == verifiedPID && helperBuild == 24898 && macOSMajor == 27
            && motion == 1 && flavor == 3 && !marked
    }
}
