<p align="center"><img src="logo.png" alt="Clip logo" width="200"></p>

# Clip

Tiny clipboard history + screen text grabber (OCR) for macOS. A `clip` CLI and a menu bar app.

## Build

```sh
./build.sh
```

Installs `~/.local/bin/clip` and `~/Applications/Clip.app`. Needs Xcode command line tools, macOS 13+.

## Use

| Command | What it does |
|---|---|
| `clip watch` | Run in background, save every text you copy |
| `clip` | List recent items |
| `clip <word>` | List items containing `<word>` |
| `clip <N>` | Copy item N back to the clipboard |
| `clip clear` | Wipe history |
| `clip ocr [img]` | Grab text from a screen area (or image file) |

Menu bar app: ⌘⇧2 grabs text from the screen.

## Privacy

- History is stored only on your Mac in `~/.clip_history.json` (owner-only, `0600`). Nothing is sent anywhere.
- Items marked secret by password managers (`ConcealedType` / `TransientType`) are never saved.
- OCR screenshots are deleted right after the text is read.
- Last 200 items are kept. Run `clip clear` to wipe them.
