<p align="center">
  <img src="docs/icon.png" alt="MacAppLauncher" width="128">
</p>

<h1 align="center">MacAppLauncher</h1>

<p align="center"><a href="README.fr.md">Version française</a></p>

A tiny, fast app launcher for macOS that **does not depend on Spotlight**.

## Why

Raycast, Alfred, Launchpad and Spotlight all ask the Spotlight index which apps are installed. When that index breaks — which happens after some macOS updates, when `mds_stores` keeps crashing on a corrupted store — apps silently disappear from every launcher, and the only fix is a full reindex that can take an hour.

MacAppLauncher simply lists the `.app` bundles in the application folders itself. It finds ~300 apps in about 150 ms, keeps them in memory, and watches the folders for changes. No index, nothing to rebuild.

## Features

- **Global shortcut** — `⌥ Space` by default, customizable from the menu bar.
- **Instant search** — in-memory matching, under 1 ms per keystroke.
- **Smart matching** — prefix, initials (`ws` → WebStorm), word starts, then fuzzy; accents ignored.
- **Learns your habits** — apps you launch often rank higher.
- **Keyboard first** — `↑ ↓` to move, `↩` to open, `⌘1`…`⌘9` to open a result directly, `⎋` to clear then close.
- **Remembers the last query** — reopening shows it pre-selected; type to replace, `↩` to relaunch.
- **Always up to date** — FSEvents watch the folders, the list refreshes when you install or remove an app.
- **Liquid Glass** — native macOS 26 glass panel.
- **Lightweight** — ~55 MB of memory, no dependencies, lives in the menu bar.
- **Launch at login** — one click in the menu.

### Scanned folders

| Folder | Contents |
|---|---|
| `/Applications` (and subfolders) | Your apps |
| `/System/Applications` | Apple apps, Utilities |
| `/System/Cryptexes/App/System/Applications` | Safari |
| `/System/Library/CoreServices/Applications` | System utilities |
| `~/Applications` | Per-user apps, Chrome/Safari web apps |

## Installation

Download the disk image from the [latest release](https://github.com/dimer47/MacAppLauncher/releases/latest) and drag MacAppLauncher into Applications. It is signed and notarized.

**Requirements**: macOS 26 or later.

## Usage

| Action | How |
|---|---|
| Open the search | Global shortcut, or launch the app again |
| Change the shortcut | Menu bar icon → *Modifier le raccourci…* → type the new combination |
| Launch at login | Menu bar icon → *Lancer à l'ouverture de session* |
| Force a rescan | Menu bar icon → *Rescanner les apps* |

If the shortcut is already taken by another app (ChatGPT uses `⌥ Space` too), an alert asks you to pick another one.

## Building from source

```sh
git clone https://github.com/dimer47/MacAppLauncher.git
cd MacAppLauncher
./build.sh                # build, sign, install to /Applications and launch
./build.sh --no-install   # build and sign only, into build/
./build.sh --notarize     # also notarize (needs a "notary" keychain profile)
```

Signing uses a Developer ID certificate; override it with `SIGN_IDENTITY=<sha1 or name> ./build.sh`, or `SIGN_IDENTITY=-` for ad-hoc signing.

Measure keystroke performance:

```sh
BENCH=1 .build/release/MacAppLauncher
```

The icon is drawn by code: `swift tools/make-icon.swift <out.iconset>` then `iconutil -c icns`.

## Project layout

| File | Role |
|---|---|
| `Sources/MacAppLauncher/AppScanner.swift` | Folder scan, FSEvents watch, matching |
| `Sources/MacAppLauncher/SearchPanel.swift` | Glass panel, results list, keyboard handling |
| `Sources/MacAppLauncher/HotKey.swift` | Global shortcut (Carbon, no Accessibility permission) |
| `Sources/MacAppLauncher/main.swift` | App delegate, menu bar, shortcut recorder |
| `build.sh` | Build, bundle, sign, notarize, install |
| `.github/workflows/` | CI build on every push, signed release on tags |

## Releasing

Push a tag: `git tag v1.1.0 && git push origin v1.1.0`. The *Publication* workflow builds, signs, notarizes and publishes a `.dmg` to GitHub Releases.

Required repository secrets: `MAC_CERT_P12`, `MAC_CERT_PASSWORD`, `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`.

## License

GPL-3.0 — see [LICENSE](LICENSE).
