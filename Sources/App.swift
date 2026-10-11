import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let engine = RepairEngine()
    private var window: NSWindow!
    private var status: NSTextField!
    private var toggleButton: NSButton!
    private var item: NSStatusItem!
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let id = Bundle.main.bundleIdentifier
        if NSWorkspace.shared.runningApplications.contains(where: {
            $0.bundleIdentifier == id && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }) {
            DistributedNotificationCenter.default().post(name: .init("local.timmy.mmf-gesture-fix.show"), object: nil)
            NSApp.terminate(nil); return
        }
        createUI()
        engine.onChange = { [weak self] in self?.refresh() }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.engine.refreshHelper()
            })
        }
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(show),
            name: .init("local.timmy.mmf-gesture-fix.show"), object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(exportDiagnostics),
            name: .init("local.timmy.mmf-gesture-fix.export"), object: nil)
        engine.refreshHelper()
        engine.start(prompt: true)
        show()
    }
    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        DistributedNotificationCenter.default().removeObserver(self)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        show(); return true
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { true }

    private func createUI() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "MMF Gesture Fix")
        item.button?.image?.isTemplate = true
        let menu = NSMenu()
        for (label, action) in [("打开控制窗口", #selector(show)), ("暂停或启用修复", #selector(toggle)),
            ("导出诊断", #selector(exportDiagnostics)), ("退出", #selector(quit))] {
            let entry = menu.addItem(withTitle: label, action: action, keyEquivalent: "")
            entry.target = self
        }
        item.menu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 510, height: 270),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "MMF Gesture Fix · 独立修复器"
        window.isReleasedWhenClosed = false; window.delegate = self; window.center()
        status = NSTextField(wrappingLabelWithString: "")
        status.frame = NSRect(x: 24, y: 126, width: 462, height: 118)
        status.font = .systemFont(ofSize: 14)
        window.contentView?.addSubview(status)
        toggleButton = NSButton(title: "暂停修复", target: self, action: #selector(toggle))
        toggleButton.frame = NSRect(x: 24, y: 80, width: 125, height: 30)
        window.contentView?.addSubview(toggleButton)
        let export = NSButton(title: "导出诊断", target: self, action: #selector(exportDiagnostics))
        export.frame = NSRect(x: 161, y: 80, width: 125, height: 30)
        window.contentView?.addSubview(export)
        let retry = NSButton(title: "重新检查权限", target: self, action: #selector(retryPermission))
        retry.frame = NSRect(x: 298, y: 80, width: 180, height: 30)
        window.contentView?.addSubview(retry)
        let settings = NSButton(title: "打开辅助功能设置", target: self, action: #selector(openSettings))
        settings.frame = NSRect(x: 24, y: 40, width: 180, height: 30)
        window.contentView?.addSubview(settings)
        let note = NSTextField(labelWithString: "保留 MMF 配置与连续手势；关闭窗口后仍可运行。")
        note.font = .systemFont(ofSize: 11); note.textColor = .secondaryLabelColor
        note.frame = NSRect(x: 24, y: 15, width: 462, height: 18)
        window.contentView?.addSubview(note)
    }
    private func refresh() {
        guard status != nil else { return }
        let labels = ["starting": "启动中", "active": "active · 事件修复层已运行",
            "waiting_accessibility": "等待辅助功能授权", "unsupported_system": "当前系统不支持，原样通过",
            "event_tap_unavailable": "事件修复层未能启动", "stopped": "已停止"]
        status.stringValue = "版本 0.1.0\n状态：\(labels[engine.state] ?? engine.state)\n官方 Helper：\(engine.sourceLabel)\n模式：\(engine.isEnabled ? "修复开启" : "仅诊断")"
        toggleButton.title = engine.isEnabled ? "暂停修复" : "启用修复"
    }
    @objc func show() { refresh(); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func toggle() { engine.toggle() }
    @objc func exportDiagnostics() { _ = engine.export() }
    @objc func retryPermission() { engine.start(prompt: true) }
    @objc func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc func quit() { NSApp.terminate(nil) }
}

@main struct MMFGestureFix {
    static func main() {
        switch CommandLine.arguments.dropFirst().first {
        case "--self-test":
            let policyOK = runPolicyTests(), bridgeOK = MGBridgeSelfTest() == 1
            print("HID bridge: \(bridgeOK ? "PASS" : "FAIL")")
            exit(policyOK && bridgeOK ? 0 : 1)
        case "--status":
            let engine = RepairEngine(); engine.refreshHelper(publishStatus: false)
            var report = Support.read("status.json") ?? [:]
            let pid = (report["pid"] as? NSNumber)?.int32Value ?? 0
            let executable = report["executable"] as? String ?? ""
            report["runtime_alive"] = executable.withCString { MGProcessMatches(pid, $0) == 1 }
            report["current_helper"] = engine.sourceLabel
            report["private_api"] = MGLoadHID() == 1 ? "ok" : "unavailable"
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                print(String(decoding: data, as: UTF8.self))
            }
            exit(0)
        case "--export-diagnostics":
            DistributedNotificationCenter.default().post(name: .init("local.timmy.mmf-gesture-fix.export"), object: nil)
            print(Support.directory.appendingPathComponent("gesture-diagnostics.json").path)
            exit(0)
        case .some(let argument):
            fputs("Unknown option: \(argument)\n", stderr); exit(2)
        case nil: break
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
