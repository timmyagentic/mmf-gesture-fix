import AppKit
import ApplicationServices

enum Support {
    static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/MMF Gesture Fix")
    static func write(_ object: [String: Any], name: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        } catch { NSLog("MMF Gesture Fix export error: %@", error.localizedDescription) }
    }
    static func read(_ name: String) -> [String: Any]? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

final class RepairEngine {
    private let lock = NSLock()
    private var policy = GesturePolicy()
    private var eligibility = Eligibility(verifiedPID: 0, helperBuild: 0,
        macOSMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
    private var enabled = UserDefaults.standard.object(forKey: "RepairEnabled") as? Bool ?? true
    private var records: [[String: Any]] = []
    private var nextRecord = 0
    private var observed = 0, corrected = 0
    private var tap: CFMachPort?
    private var loop: CFRunLoop?
    private var thread: Thread?
    private var stopping = false
    private(set) var state = "starting"
    var onChange: (() -> Void)?

    var isEnabled: Bool {
        lock.lock(); defer { lock.unlock() }; return enabled
    }
    var sourceLabel: String {
        lock.lock(); defer { lock.unlock() }
        return eligibility.verifiedPID > 0
            ? "PID \(eligibility.verifiedPID) · build \(eligibility.helperBuild)"
            : "Official Helper not detected"
    }
    func refreshHelper(publishStatus: Bool = true) {
        var pid: Int32 = 0, build: Int32 = 0
        for app in NSWorkspace.shared.runningApplications
            where app.bundleIdentifier == "com.nuebling.mac-mouse-fix.helper" {
            let verifiedBuild = MGVerifiedHelperBuild(app.processIdentifier)
            if verifiedBuild > 0 { pid = app.processIdentifier; build = verifiedBuild; break }
        }
        lock.lock()
        if pid != eligibility.verifiedPID || build != eligibility.helperBuild { policy.reset() }
        eligibility.verifiedPID = pid; eligibility.helperBuild = build
        lock.unlock()
        if publishStatus { publish() }
    }
    func toggle() {
        lock.lock(); enabled.toggle(); policy.reset(); let value = enabled; lock.unlock()
        UserDefaults.standard.set(value, forKey: "RepairEnabled")
        publish()
    }
    private func setState(_ value: String) {
        state = value; publish()
    }
    func publish() {
        lock.lock()
        let data: [String: Any] = ["version": AppVersion.current, "pid": ProcessInfo.processInfo.processIdentifier,
            "executable": Bundle.main.executablePath ?? "", "state": state, "enabled": enabled,
            "helper_pid": eligibility.verifiedPID, "helper_build": eligibility.helperBuild,
            "source_supported": eligibility.helperBuild == 24898 && eligibility.macOSMajor == 27,
            "observed": observed, "corrected": corrected]
        lock.unlock()
        Support.write(data, name: "status.json")
        onChange?()
    }
    func export() -> URL {
        lock.lock()
        let ordered = records.count < 256 ? records
            : Array(records[nextRecord...] + records[..<nextRecord])
        let data: [String: Any] = ["schema": 1, "version": AppVersion.current,
            "generated_at": ISO8601DateFormatter().string(from: Date()), "capacity": 256,
            "enabled": enabled, "helper_pid": eligibility.verifiedPID,
            "helper_build": eligibility.helperBuild, "observed": observed, "corrected": corrected,
            "records": ordered]
        lock.unlock()
        Support.write(data, name: "gesture-diagnostics.json")
        publish()
        return Support.directory.appendingPathComponent("gesture-diagnostics.json")
    }
    func start(prompt: Bool) {
        guard thread == nil else { return }
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27, MGLoadHID() == 1 else {
            setState("unsupported_system"); return
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            setState("waiting_accessibility"); return
        }
        stopping = false
        let worker = Thread { [weak self] in self?.runTap() }
        worker.name = "MMF Gesture Fix event tap"; worker.qualityOfService = .userInteractive
        thread = worker; worker.start()
    }
    private func runTap() {
        let callback: CGEventTapCallBack = { _, type, event, context in
            autoreleasepool {
                guard let context else { return Unmanaged.passUnretained(event) }
                let engine = Unmanaged<RepairEngine>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if AXIsProcessTrusted(), let tap = engine.tap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    } else {
                        DispatchQueue.main.async { [weak engine] in
                            engine?.stop(); engine?.setState("waiting_accessibility")
                        }
                    }
                    return Unmanaged.passUnretained(event)
                }
                if let replacement = engine.process(event) { return Unmanaged.passRetained(replacement) }
                return Unmanaged.passUnretained(event)
            }
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: CGEventMask(1) << 30, callback: callback, userInfo: context),
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0) else {
            DispatchQueue.main.async { [weak self] in self?.thread = nil; self?.setState("event_tap_unavailable") }
            return
        }
        lock.lock(); tap = created; loop = CFRunLoopGetCurrent(); let shouldStop = stopping; lock.unlock()
        if !shouldStop {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: created, enable: true)
            DispatchQueue.main.async { [weak self] in self?.setState("active") }
            CFRunLoopRun()
            CGEvent.tapEnable(tap: created, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        lock.lock(); tap = nil; loop = nil; lock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.thread = nil
            self?.setState(AXIsProcessTrusted() ? "stopped" : "waiting_accessibility")
        }
    }
    func stop() {
        lock.lock(); stopping = true; let current = loop; policy.reset(); lock.unlock()
        if let current { CFRunLoopStop(current) }
        _ = export()
    }
    private func process(_ event: CGEvent) -> CGEvent? {
        var frame = MGFrame()
        guard MGReadFrame(event, &frame) == 1 else { return nil }
        lock.lock(); defer { lock.unlock() }
        guard eligibility.accepts(pid: frame.pid, motion: Int(frame.motion),
            flavor: Int(frame.flavor), marked: frame.marked != 0) else { return nil }
        observed += 1
        let decision = enabled ? policy.inspect(phase: Int(frame.phase), time: frame.timestamp,
            progress: frame.progress, velocity: frame.vx) : 0
        let requested = decision == 1 || decision == 2
        let replacement = requested ? MGCopyWithVelocity(event, -frame.vx, -frame.vy) : nil
        let applied = replacement != nil
        if applied { corrected += 1 }
        let record: [String: Any] = ["timestamp_ns": frame.timestamp, "pid": frame.pid,
            "phase": frame.phase, "progress": frame.progress, "velocity_before": frame.vx,
            "velocity_after": applied ? -frame.vx : frame.vx, "decision": decision, "applied": applied]
        if records.count < 256 { records.append(record) }
        else { records[nextRecord] = record; nextRecord = (nextRecord + 1) % 256 }
        return replacement
    }
}
