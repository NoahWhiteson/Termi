# Termi

A native macOS terminal with vertical tabs, a translucent sidebar, Liquid Glass controls, and an inset black terminal. Built with SwiftUI, AppKit, [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm), and WebKit.

## Install

Download [Termi for Mac](https://github.com/NoahWhiteson/Termi/releases/latest/download/Termi-mac-arm64.dmg), open the DMG, and drag **Termi.app** into **Applications**.

For a local build, double-click **build/Termi.app**, or run:

```sh
open build/Termi.app
```

Requires macOS 14 or later on Apple silicon. The current release is ad hoc signed and not notarized. macOS may block the first launch; use **System Settings → Privacy & Security → Open Anyway** if you trust the download. Developer ID signing and Apple notarization are needed for a standard Gatekeeper installation experience.

On macOS 26 and later, circular controls use Apple's native Liquid Glass API. The selected tab uses a separate `NSGlassEffectView` behind the label and icon, so the content stays sharp. The sidebar uses `NSVisualEffectView` with behind-window blending to blur the desktop. Older macOS versions use system vibrancy. Window controls are the actual native close, minimize, and full-screen buttons.

## What’s inside

- Real local login shells with ANSI colors, scrollback, interactive programs, Unicode, selection, and copy/paste.
- Vertical pill tabs: drag the tab icon to reorder; right-click to rename. Close buttons stay visible with a generous click target.
- Collapse the sidebar to move all tabs into a horizontally scrollable top bar, with the same selection, icons, reordering, and context menus.
- Tab selection uses an immediate focus handoff and a short crossfade, without sliding the terminal content. Opening and closing tabs animate the surrounding spacing. Visited views stay mounted to preserve scroll positions, selection, and split sizes; Reduce Motion is respected.
- Right-click a tab and choose **Change icon…** for Claude, Codex, OpenCode, Docker, GitHub, and other built-in choices. Choose **Choose image…** to import a custom icon. Imported images are saved as compact PNG copies with the tab, survive restart, and are preserved when duplicating or reopening a tab.
- Right-click the plus button for a browser tab or to open a project folder. Right-click a tab for split, search, export, and other actions. Settings remain available through **⌘,**.
- Two resizable terminal panes per tab, each with its own shell.
- Embedded WebKit browser tabs for documentation, web searches, and localhost previews.
- A searchable command palette, terminal text search, and scrollback export.
- Adjustable text size and an optional minimal zsh prompt.
- Tab names, order, pins, browser URLs, and working directories restored at launch. Live processes and terminal output last for the current app session; they are not resumed after quitting. Split layouts are currently session-only.
- Confirmation before closing a terminal with a foreground command still running.

## Keyboard shortcuts

- **⌘T** — new terminal
- **⌘⇧B** — new browser
- **⌘O** — open a project folder
- **⌘W** — close tab
- **⌘⇧T** — reopen closed tab
- **⌘1–9** — select tab
- **⌘⇧[ / ⌘⇧]** — previous / next tab
- **⌘D** — split terminal
- **⌘F** — find in terminal
- **⌘K** — clear terminal
- **⌘⇧P** — command palette
- **⌘⇧R** — rename tab
- **⌘B** — toggle sidebar
- **⌘+ / ⌘− / ⌘0** — increase / decrease / reset text size
- **⌘,** — settings
- **⌘⇧S** — save scrollback

## Build from source

With Xcode and Swift installed:

```sh
./scripts/build.sh
open build/Termi.app
```

Use `./scripts/build.sh debug` for a faster development build. Open `Package.swift` in Xcode to edit the app. The build script uses the native Swift build system so an additional Metal compiler download is not required; the terminal uses CoreText rendering.

```sh
swift test --build-system native
```

## Shell configuration

Termi starts your `$SHELL` as a login shell and inherits the normal user environment. For zsh, bundled integration files load your original `.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`, and `.zlogout`, including an existing custom `ZDOTDIR`. Nothing is written into your shell configuration. Integration reports the current directory to the app. The minimal prompt can be turned off in Settings for new sessions.

Browser tabs use the system WebKit engine with its normal shared website data store. The web inspector is available. This is a focused development browser: downloads and browser extensions are not implemented.

SwiftTerm’s MIT license is included in the app’s resources.

Brand icons are bundled from Simple Icons (CC0) and Lobe Icons (MIT), with notices under `Resources/Icons`. All trademarks belong to their respective owners.

## Download page

The minimal Vite website lives in `website/`.

```sh
npm --prefix website ci
npm --prefix website run dev
```

Import **NoahWhiteson/Termi** into Vercel and keep **Root Directory** set to the repository root (`.`). The root `vercel.json` installs the website dependencies, runs its Vite build, and publishes `website/dist/`. No environment variables or Mac build tools are required on Vercel. The DMG is hosted exclusively on GitHub Releases; the website links directly to it.

## Package and publish a release

On an Apple silicon Mac:

```sh
./scripts/build.sh
./scripts/package-download.sh
npm --prefix website run build
```

The packaging script produces `build/Termi-mac-arm64.dmg` and its SHA-256 checksum. The disk image contains Termi.app and an Applications shortcut. It also refreshes `website/public/release.json` with the version, file size, and checksum. Build artifacts stay out of Git and Vercel.

For a new version, update `CFBundleShortVersionString` and `CFBundleVersion` in `packaging/Info.plist` before building, then commit and push the updated sources and release metadata. Publish the matching tag with GitHub CLI:

```sh
gh release create v1.0.0 \
  build/Termi-mac-arm64.dmg \
  build/Termi-mac-arm64.dmg.sha256 \
  --repo NoahWhiteson/Termi \
  --target main \
  --title "Termi 1.0.0" \
  --notes "Download the DMG, open it, and drag Termi into Applications." \
  --latest
```

Use the new version tag for subsequent releases and keep the asset filename `Termi-mac-arm64.dmg`. The website's `/releases/latest/download/` link will automatically serve the newest release without storing a binary on Vercel.
