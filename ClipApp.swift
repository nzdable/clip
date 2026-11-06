// Menu bar front end for the `clip` CLI. History + OCR live in `clip`;
// this app shows the menu, the history window (⌘⇧1) and grab (⌘⇧2).
import AppKit
import Carbon
import ServiceManagement
import SwiftUI

let clipBin = NSHomeDirectory() + "/.local/bin/clip"
let histURL = URL(fileURLWithPath: NSHomeDirectory() + "/.clip_history.json")

// Same shape as `Clip` in clip.swift; keep them in sync.
// `date` is nil for items saved before timestamps existed.
struct Clip: Codable { var text: String; var date: Date? }

func loadHistory() -> [Clip] {
    guard let d = try? Data(contentsOf: histURL) else { return [] }
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    if let items = try? dec.decode([Clip].self, from: d) { return items }
    return ((try? dec.decode([String].self, from: d)) ?? []).map { Clip(text: $0, date: nil) }
}

// "Today, 2:41 PM" / "Yesterday, 9:03 AM" / "Nov 3, 4:12 PM"
func when(_ d: Date) -> String {
    let time = d.formatted(date: .omitted, time: .shortened)
    if Calendar.current.isDateInToday(d) { return "Today, \(time)" }
    if Calendar.current.isDateInYesterday(d) { return "Yesterday, \(time)" }
    return d.formatted(.dateTime.month(.abbreviated).day()) + ", \(time)"
}

// Colors from the tortoiseshell cat logo.
extension Color {
    static let cream = Color(red: 0.99, green: 0.95, blue: 0.90)
    static let card = Color(red: 1.00, green: 0.98, blue: 0.95)
    static let peach = Color(red: 0.97, green: 0.83, blue: 0.69)
    static let tabby = Color(red: 0.88, green: 0.48, blue: 0.21)
    static let cocoa = Color(red: 0.29, green: 0.13, blue: 0.07)
    static let sparkle = Color(red: 0.96, green: 0.65, blue: 0.14)
}

// Searchable list of every saved clip. Click or Enter copies (window stays
// open); Esc closes.
struct HistoryView: View {
    @State var items: [Clip]
    let copy: (String) -> Void
    let clear: () -> Void
    let close: () -> Void
    @State private var query = ""
    @State private var hovered: String?
    @State private var copied: String?
    @State private var confirmClear = false

    var shown: [Clip] {
        query.isEmpty ? items : items.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    // First tap arms the button, second tap (within 3s) clears.
    func tapClear() {
        if confirmClear {
            clear()
            withAnimation { items = []; confirmClear = false }
        } else {
            withAnimation { confirmClear = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { confirmClear = false } }
        }
    }

    func pick(_ s: String) {
        copy(s)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { copied = s }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { if copied == s { copied = nil } }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            search
            if shown.isEmpty { empty } else { list }
            Text("click or ↩ to copy  ·  esc to close")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.cocoa.opacity(0.45))
        }
        .padding(.horizontal, 16)
        .padding(.top, 30)  // room for the window buttons
        .padding(.bottom, 10)
        .frame(minWidth: 400, minHeight: 500)
        .background(Color.cream)
        .preferredColorScheme(.light)
        .onExitCommand(perform: close)
    }

    var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text("clip").font(.system(size: 24, weight: .heavy, design: .rounded))
                    Image(systemName: "sparkle").foregroundStyle(Color.sparkle)
                }
                Text("\(items.count) clips saved")
                    .font(.system(size: 12, design: .rounded))
                    .opacity(0.6)
            }
            Spacer()
            if !items.isEmpty {
                Button(action: tapClear) {
                    Label(confirmClear ? "Tap again to clear" : "Clear all",
                          systemImage: confirmClear ? "exclamationmark.triangle.fill" : "trash")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(confirmClear ? Color.white : Color.cocoa.opacity(0.75))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(confirmClear ? Color.tabby : Color.card))
                        .overlay(Capsule().stroke(Color.cocoa.opacity(confirmClear ? 0 : 0.2)))
                }
                .buttonStyle(.plain)
                .help("Delete every saved clip")
            }
        }
        .foregroundStyle(Color.cocoa)
    }

    var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.tabby)
            TextField("", text: $query, prompt: Text("Search your clips…")
                .foregroundColor(Color.cocoa.opacity(0.4)))
                .textFieldStyle(.plain)
                .onSubmit { if let c = shown.first { pick(c.text) } }
        }
        .font(.system(size: 14, design: .rounded))
        .foregroundStyle(Color.cocoa)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Capsule().fill(Color.card))
        .overlay(Capsule().stroke(Color.cocoa.opacity(0.8), lineWidth: 2))
    }

    var empty: some View {
        VStack(spacing: 6) {
            Text("🐾").font(.system(size: 34))
            Text(items.isEmpty ? "Nothing here yet. Copy something!" : "No clips match that.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.cocoa.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var list: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(shown, id: \.text) { row($0) }  // history has no duplicate texts
            }
            .padding(2)
        }
    }

    func row(_ c: Clip) -> some View {
        let s = c.text
        let isHover = hovered == s, isCopied = copied == s
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(s.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color.cocoa)
                    .lineLimit(3)
                if let d = c.date {
                    Label(when(d), systemImage: "clock")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.tabby.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isCopied {
                Text("Copied! 🐾")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.tabby))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(isHover || isCopied ? Color.peach.opacity(0.55) : Color.card))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(isHover || isCopied ? Color.tabby : Color.cocoa.opacity(0.12), lineWidth: isHover || isCopied ? 2 : 1))
        .scaleEffect(isHover ? 1.01 : 1)
        .animation(.easeOut(duration: 0.12), value: isHover)
        .contentShape(Rectangle())
        .onHover { hovered = $0 ? s : (hovered == s ? nil : hovered) }
        .onTapGesture { pick(s) }
        .help(String(s.prefix(500)))
    }
}

class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    var panel: NSPanel?

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
        add("Show History…", #selector(showHistory), key: "1", mods: [.command, .shift])
        add("Grab Text from Screen", #selector(grab), key: "2", mods: [.command, .shift])
        menu.addItem(.separator())

        let items = loadHistory()
        if items.isEmpty { menu.addItem(withTitle: "No history yet", action: nil, keyEquivalent: "") }
        for s in items.prefix(20).map(\.text) {
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

    @objc func copyItem(_ mi: NSMenuItem) { copy(mi.representedObject as! String) }

    func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    // Rebuilt on every open so the list is always current.
    @objc func showHistory() {
        let p = panel ?? NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 540),
                                 styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                                 backing: .buffered, defer: false)
        panel = p
        p.title = "Clip History"
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.backgroundColor = NSColor(Color.cream)
        p.appearance = NSAppearance(named: .aqua)
        p.isReleasedWhenClosed = false
        p.level = .floating
        p.contentView = NSHostingView(rootView: HistoryView(
            items: loadHistory(),
            copy: { [weak self] s in self?.copy(s) },
            clear: { [weak self] in self?.clear() },
            close: { [weak p] in p?.close() }))
        p.center()
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }

    @objc func clear() {
        try? Process.run(URL(fileURLWithPath: clipBin), arguments: ["clear"])
    }

    @objc func toggleLogin() {
        let s = SMAppService.mainApp
        do { try s.status == .enabled ? s.unregister() : s.register() } catch { NSSound.beep() }
    }

    // Global ⌘⇧1 (history) and ⌘⇧2 (grab) via Carbon: work in every app,
    // no Accessibility permission needed. Hotkey id 1 = grab, 2 = history.
    func registerHotKey() {
        for (key, id) in [(kVK_ANSI_2, 1), (kVK_ANSI_1, 2)] {
            var ref: EventHotKeyRef?
            RegisterEventHotKey(UInt32(key), UInt32(cmdKey | shiftKey),
                                EventHotKeyID(signature: 0x434C4950, id: UInt32(id)),
                                GetApplicationEventTarget(), 0, &ref)
        }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, ev, ctx in
            var hk = EventHotKeyID()
            GetEventParameter(ev, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let app = Unmanaged<App>.fromOpaque(ctx!).takeUnretainedValue()
            if hk.id == 1 { app.grab() } else { app.showHistory() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // menu bar only, no Dock icon
app.run()
