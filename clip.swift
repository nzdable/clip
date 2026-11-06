// clip: tiny clipboard history for macOS.
//   clip watch    run in background, save every text you copy
//   clip          list recent items
//   clip <word>   list items containing <word>
//   clip <N>      copy item N back to the clipboard
//   clip clear    wipe history
//   clip ocr [img] grab text from a screen area (or image file)
import AppKit
import Vision

let histURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".clip_history.json")
let maxItems = 200
let pb = NSPasteboard.general
// Every file we create (history, its atomic-write temp copy) starts owner-only.
umask(0o077)

// One saved copy. `date` is nil for items saved before timestamps existed.
// Same shape is decoded by ClipApp.swift; keep them in sync.
struct Clip: Codable { var text: String; var date: Date? }

func load() -> [Clip] {
    guard let d = try? Data(contentsOf: histURL) else { return [] }
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    if let items = try? dec.decode([Clip].self, from: d) { return items }
    // Old format: plain list of strings.
    return ((try? dec.decode([String].self, from: d)) ?? []).map { Clip(text: $0, date: nil) }
}

func save(_ items: [Clip]) {
    let enc = JSONEncoder()
    enc.dateEncodingStrategy = .iso8601
    let d = try! enc.encode(items)
    try? d.write(to: histURL, options: .atomic)
    // Clipboard can hold sensitive text: owner-only file.
    try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: histURL.path)
}

func list(_ query: String? = nil) {
    let items = load()
    if items.isEmpty { print("History empty. Is `clip watch` running?"); return }
    for (i, s) in items.map(\.text).enumerated() {
        if let q = query, !s.localizedCaseInsensitiveContains(q) { continue }
        let lines = s.split(separator: "\n", omittingEmptySubsequences: false)
        var line = String(lines.first ?? "").trimmingCharacters(in: .whitespaces)
        if line.count > 80 { line = String(line.prefix(77)) + "..." }
        print(String(format: "%3d  ", i + 1) + line + (lines.count > 1 ? "  [+\(lines.count - 1) lines]" : ""))
    }
}

// Password managers mark secrets with these types; never store them.
let skipTypes: Set<NSPasteboard.PasteboardType> = [
    .init("org.nspasteboard.ConcealedType"),
    .init("org.nspasteboard.TransientType"),
]

let arg = CommandLine.arguments.dropFirst().first
switch arg {
case "watch":
    var last = pb.changeCount
    while true {
        usleep(500_000)
        guard pb.changeCount != last else { continue }
        last = pb.changeCount
        if !skipTypes.isDisjoint(with: pb.types ?? []) { continue }
        guard let s = pb.string(forType: .string), !s.isEmpty else { continue }
        var items = load().filter { $0.text != s }
        items.insert(Clip(text: s, date: Date()), at: 0)
        save(Array(items.prefix(maxItems)))
    }
case "ocr":
    // `clip ocr` = drag a box on screen; `clip ocr pic.png` = read a file.
    var url: URL
    if let path = CommandLine.arguments.dropFirst(2).first {
        url = URL(fileURLWithPath: path)
    } else {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("clip-ocr.png")
        try? FileManager.default.removeItem(at: url)
        let p = Process.launchedProcess(launchPath: "/usr/sbin/screencapture", arguments: ["-i", "-x", url.path])
        p.waitUntilExit()
        guard FileManager.default.fileExists(atPath: url.path) else { print("Cancelled."); exit(0) }
        // Screenshot may show sensitive things; don't leave it in temp.
        atexit { try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appendingPathComponent("clip-ocr.png")) }
    }
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.minimumTextHeight = 0  // default skips text < 1/32 of image height
    do { try VNImageRequestHandler(url: url).perform([req]) }
    catch { fputs("Can't read image: \(error.localizedDescription)\n", stderr); exit(1) }
    let text = (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    guard !text.isEmpty else { print("No text found."); exit(1) }
    pb.clearContents()
    pb.setString(text, forType: .string)  // watcher adds it to history
    print(text)
case "clear":
    save([])
    print("History cleared.")
case let n? where Int(n) != nil:
    let items = load(), i = Int(n)! - 1
    guard items.indices.contains(i) else { fputs("No item \(n).\n", stderr); exit(1) }
    pb.clearContents()
    pb.setString(items[i].text, forType: .string)
    print("Copied item \(n).")
case let q?:
    list(q)
case nil:
    list()
}
