// Menu bar front end for the `clip` CLI. History + OCR live in `clip`;
// this app only shows the menu and the ⌘⇧2 hotkey.
import AppKit
import Carbon
import ServiceManagement

let clipBin = NSHomeDirectory() + "/.local/bin/clip"
let histURL = URL(fileURLWithPath: NSHomeDirectory() + "/.clip_history.json")

class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()

    func applicationDidFinishLaunching(_ n: Notification) {
        let icon = NSImage(named: "menubar")
        icon?.size = NSSize(width: 18, height: 18)
        status.button?.image = icon
        menu.delegate = self
        status.menu = menu
        registerHotKey()
    }

    // Rebuild the menu each time it opens so history is always fresh.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        add("Grab Text from Screen", #selector(grab), key: "2", mods: [.command, .shift])
        menu.addItem(.separator())

        let items = (try? JSONDecoder().decode([String].self, from: Data(contentsOf: histURL))) ?? []
        if items.isEmpty { menu.addItem(withTitle: "No history yet", action: nil, keyEquivalent: "") }
        for s in items.prefix(20) {
            var title = s.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines).first ?? ""
            if title.count > 50 { title = String(title.prefix(47)) + "..." }
            let mi = add(title.isEmpty ? "(blank)" : title, #selector(copyItem(_:)))
            mi.representedObject = s
            mi.toolTip = String(s.prefix(500))
        }

        menu.addItem(.separator())
        add("Open at Login", #selector(toggleLogin)).state =
            SMAppService.mainApp.status == .enabled ? .on : .off
        add("Clear History", #selector(clear))
        add("Quit", #selector(NSApplication.terminate(_:)), key: "q").target = NSApp
    }

    @discardableResult
    func add(_ title: String, _ action: Selector, key: String = "", mods: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
        mi.keyEquivalentModifierMask = mods
        mi.target = self
        menu.addItem(mi)
        return mi
    }

    // Snip plays the moment the box is drawn; text reading happens after.
    // Beep afterwards = no text found.
    @objc func grab() {
        let img = FileManager.default.temporaryDirectory.appendingPathComponent("clip-grab.png")
        try? FileManager.default.removeItem(at: img)
        let cap = Process()
        cap.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        cap.arguments = ["-i", "-x", img.path]
        cap.terminationHandler = { _ in
            guard FileManager.default.fileExists(atPath: img.path) else { return }  // cancelled
            DispatchQueue.main.async { NSSound(named: "snip")?.play() }
            let ocr = Process()
            ocr.executableURL = URL(fileURLWithPath: clipBin)
            ocr.arguments = ["ocr", img.path]
            ocr.standardOutput = FileHandle.nullDevice
            // Screenshot may show sensitive things; delete it once read.
            ocr.terminationHandler = { p in
                try? FileManager.default.removeItem(at: img)
                if p.terminationStatus != 0 { DispatchQueue.main.async { NSSound.beep() } }
            }
            do { try ocr.run() } catch { try? FileManager.default.removeItem(at: img) }
        }
        do { try cap.run() } catch { NSSound.beep() }
    }

    @objc func copyItem(_ mi: NSMenuItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(mi.representedObject as! String, forType: .string)
    }

    @objc func clear() {
        try? Process.run(URL(fileURLWithPath: clipBin), arguments: ["clear"])
    }

    @objc func toggleLogin() {
        let s = SMAppService.mainApp
        do { try s.status == .enabled ? s.unregister() : s.register() } catch { NSSound.beep() }
    }

    // Global ⌘⇧2 via Carbon: works in every app, no Accessibility permission needed.
    func registerHotKey() {
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_ANSI_2), UInt32(cmdKey | shiftKey),
                            EventHotKeyID(signature: 0x434C4950, id: 1),
                            GetApplicationEventTarget(), 0, &ref)
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, ctx in
            Unmanaged<App>.fromOpaque(ctx!).takeUnretainedValue().grab()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // menu bar only, no Dock icon
app.run()
