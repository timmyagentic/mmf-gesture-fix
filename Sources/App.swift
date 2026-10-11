import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let engine = RepairEngine()
    private var window: NSWindow!
    private var status: NSTextField!
    private var toggleButton: NSButton!
    private var item: NSStatusItem!
    private var language = AppLanguage.load()
    private var languagePicker: NSPopUpButton!
    private var exportButton: NSButton!
    private var retryButton: NSButton!
    private var settingsButton: NSButton!
    private var note: NSTextField!

    private func text(_ english: String, _ chinese: String) -> String {
        language.text(english, chinese)
    }
    private func refreshMenu() {
        let menu = NSMenu()
        for (label, action) in [(text("Open Control Window", "打开控制窗口"), #selector(show)),
            (text("Pause or Enable Repair", "暂停或启用修复"), #selector(toggle)),
            (text("Export Diagnostics", "导出诊断"), #selector(exportDiagnostics)),
            (text("Quit", "退出"), #selector(quit))] {
            let entry = menu.addItem(withTitle: label, action: action, keyEquivalent: "")
            entry.target = self
        }
        item.menu = menu
    }
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
        refreshMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 310),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "MMF Gesture Fix"
        window.isReleasedWhenClosed = false; window.delegate = self; window.center()
        status = NSTextField(wrappingLabelWithString: "")
        status.frame = NSRect(x: 24, y: 166, width: 592, height: 118)
        status.font = .systemFont(ofSize: 14)
        window.contentView?.addSubview(status)
        toggleButton = NSButton(title: "", target: self, action: #selector(toggle))
        toggleButton.frame = NSRect(x: 24, y: 80, width: 170, height: 30)
        window.contentView?.addSubview(toggleButton)
        exportButton = NSButton(title: "", target: self, action: #selector(exportDiagnostics))
        exportButton.frame = NSRect(x: 204, y: 80, width: 170, height: 30)
        window.contentView?.addSubview(exportButton)
        retryButton = NSButton(title: "", target: self, action: #selector(retryPermission))
        retryButton.frame = NSRect(x: 384, y: 80, width: 230, height: 30)
        window.contentView?.addSubview(retryButton)
        settingsButton = NSButton(title: "", target: self, action: #selector(openSettings))
        settingsButton.frame = NSRect(x: 24, y: 40, width: 230, height: 30)
        window.contentView?.addSubview(settingsButton)
        languagePicker = NSPopUpButton(frame: NSRect(x: 384, y: 120, width: 230, height: 30), pullsDown: false)
        languagePicker.addItems(withTitles: ["English", "简体中文"])
        languagePicker.selectItem(at: language == .english ? 0 : 1)
        languagePicker.target = self; languagePicker.action = #selector(changeLanguage)
        languagePicker.setAccessibilityLabel("Language / 语言")
        window.contentView?.addSubview(languagePicker)
        note = NSTextField(labelWithString: "")
        note.font = .systemFont(ofSize: 11); note.textColor = .secondaryLabelColor
        note.frame = NSRect(x: 24, y: 15, width: 592, height: 18)
        window.contentView?.addSubview(note)
    }
    private func refresh() {
        guard status != nil else { return }
        let labels = ["starting": text("Starting", "启动中"),
            "active": text("active · Event repair is running", "active · 事件修复层已运行"),
            "waiting_accessibility": text("Waiting for Accessibility permission", "等待辅助功能授权"),
            "unsupported_system": text("Unsupported system; events pass through", "当前系统不支持，原样通过"),
            "event_tap_unavailable": text("Event repair could not start", "事件修复层未能启动"),
            "stopped": text("Stopped", "已停止")]
        let source = engine.sourceLabel == "Official Helper not detected"
            ? text("Official Helper not detected", "未识别官方 Helper") : engine.sourceLabel
        let mode = engine.isEnabled ? text("Repair enabled", "修复开启") : text("Diagnostic only", "仅诊断")
        status.stringValue = "\(text("Version", "版本")) \(AppVersion.current)\n\(text("Status", "状态")): \(labels[engine.state] ?? engine.state)\n\(text("Official Helper", "官方 Helper")): \(source)\n\(text("Mode", "模式")): \(mode)"
        toggleButton.title = engine.isEnabled ? text("Pause Repair", "暂停修复") : text("Enable Repair", "启用修复")
        exportButton.title = text("Export Diagnostics", "导出诊断")
        retryButton.title = text("Recheck Permission", "重新检查权限")
        settingsButton.title = text("Open Accessibility Settings", "打开辅助功能设置")
        note.stringValue = text("Keeps MMF settings and continuous gestures. Runs after closing this window.",
            "保留 MMF 配置与连续手势；关闭窗口后仍可运行。")
        refreshMenu()
    }
    @objc func changeLanguage() {
        language = languagePicker.indexOfSelectedItem == 1 ? .chinese : .english
        language.save()
        refresh()
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
