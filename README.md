# SimpleShot

A tiny macOS app that wraps your screenshots in beautiful gradient backgrounds and lets you annotate them. Take a window screenshot, open SimpleShot, pick a gradient, add arrows and labels, copy or save.

![SimpleShot](screenshots/result.png)

## Why?

macOS screenshots look raw. Tools like CleanShot add nice backgrounds but come with features you'll never use. SimpleShot does two things — gradient backgrounds and quick annotations — and does them fast.

## How It Works

1. Take a screenshot with **⌘⇧4 + Space** (copies window to clipboard)
2. Open SimpleShot — it auto-loads the clipboard image
3. Pick a gradient preset, adjust padding and corner radius
4. Add annotations — arrows, circles, numbered markers, text
5. **Copy to Clipboard** or **Save as PNG**

## Features

- **Auto-paste** — opens with clipboard image ready
- **10 gradient presets** — Twilight, Sunset, Forest, Slate, Amber, Ocean, Lavender, Noir, Candy, Emerald
- **Adjustable padding** — slider + quick presets (32, 48, 64, 96, 128px)
- **Corner radius** control
- **Drop shadow** toggle
- **Annotations** — arrows, circles, rectangles, numbered markers, text labels
- **7 annotation colors** and adjustable stroke width
- **Undo** (⌘Z) and **Clear All** for annotations
- **Copy to clipboard** (⌘⇧C) or **Save as PNG** (⌘S)
- **Native macOS** — SwiftUI, zero dependencies

## Install

### Homebrew

```bash
brew install --cask alexrett/tap/simpleshot
```

### Download

Grab the latest `SimpleShot.dmg` from [Releases](https://github.com/alexrett/simpleshot/releases).

### Build from Source

```bash
git clone https://github.com/alexrett/simpleshot.git
cd simpleshot
swift build -c release --arch arm64 --arch x86_64
```

## Requirements

- macOS 13.0 (Ventura) or later
- Works on both Apple Silicon and Intel Macs

## License

MIT
