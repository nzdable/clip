<p align="center"><img src="logo.png" alt="Clip logo" width="200"></p>

# Clip

Tiny clipboard history + screen text grabber (OCR) for macOS. A `clip` CLI and a menu bar app.

## Install

Needs macOS 13+ (Apple silicon or Intel).

### Download (easiest)

1. Download **Clip.zip** from the [latest release](https://github.com/nzdable/clip/releases/latest) and unzip it.
2. Drag **Clip.app** into your **Applications** folder.
3. Right-click Clip.app → **Open** → **Open**.
   On newer macOS: open it once, then go to System Settings → Privacy & Security → **Open Anyway**.
   (macOS asks this because the app isn't notarized by Apple. You only do it once.)

A cat icon appears in your menu bar. Clip starts saving your copies and opens at login. You can turn that off in the menu.

Want the `clip` terminal command too?

```sh
mkdir -p ~/.local/bin && ln -sf /Applications/Clip.app/Contents/MacOS/clip-cli ~/.local/bin/clip
```

### Build from source

Needs Apple's command line tools (`xcode-select --install`).

```sh
git clone https://github.com/nzdable/clip.git
cd clip
./build.sh
```

This installs `~/Applications/Clip.app` and the `~/.local/bin/clip` command, then starts the app. To update, run `git pull && ./build.sh`. Running it again is safe.

### After installing

1. If `clip` says "command not found", add this to `~/.zshrc`: `export PATH="$HOME/.local/bin:$PATH"`
2. The first time you press ⌘⇧2, macOS asks for **Screen Recording** permission. Allow it in System Settings → Privacy & Security.

Clips are only saved while Clip is running (it lives in the menu bar).

## Uninstall

Quit Clip from its menu, then:

```sh
rm -rf /Applications/Clip.app ~/Applications/Clip.app ~/.local/bin/clip ~/.clip_history.json
```

## Use

| Command | What it does |
|---|---|
| `clip watch` | Run in background, save every text you copy |
| `clip` | List recent items |
| `clip <word>` | List items containing `<word>` |
| `clip <N>` | Copy item N back to the clipboard |
| `clip clear` | Wipe history |
| `clip scrub` | Remove saved items that look like keys or passwords |
| `clip ocr [img]` | Grab text from a screen area (or image file) |

Menu bar app:
- **⌘⇧1** opens the history window. Each clip shows when you copied it. Type to search, click or press Enter to copy, Esc to close. **Clear all** (tap twice) wipes the history.
- **⌘⇧2** grabs text from the screen.

## Privacy

- History is stored only on your Mac in `~/.clip_history.json` (owner-only, `0600`). Nothing is sent anywhere.
- Items marked secret by password managers (`ConcealedType` / `TransientType`) are never saved.
- Text that looks like a key is never saved either: AWS, GitHub, Slack, Stripe, Google, Anthropic/OpenAI keys, private keys, JWTs, `user:password@` URLs, and `.env` lines like `PASSWORD=...`. It stays on your clipboard, so pasting still works.
- `clip scrub` removes anything key-like that was saved before.
- OCR screenshots are deleted right after the text is read.
- Last 200 items are kept. Run `clip clear` to wipe them.

## License

[MIT](LICENSE)
