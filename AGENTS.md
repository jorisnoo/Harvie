# Agent instructions

## Project Overview

Harvie is a native macOS app that generates Swiss QR Bills for Harvest invoices. Built with SwiftUI and SwiftData, targeting macOS 15+.

Since this is a macos app, do not use xcodebuild mcp, but build directly instead.

## Code Style

- Use state-of-the-art Swift and SwiftUI patterns
- Always simplify and write elegant, readable code
- Prefer modern Swift concurrency (async/await, actors) over callbacks
- Use SwiftUI's declarative patterns; avoid UIKit unless necessary

## SwiftUI Pitfalls

- **Never use `.focusedSceneValue` with closures.** Closures aren't `Equatable`, so SwiftUI treats them as changed every body evaluation, causing a feedback loop with `@FocusedValue` in the App struct. Use `NotificationCenter` instead for cross-scene communication (e.g. menu commands triggering actions).
- **Minimize modifiers on `NavigationSplitView`.** Modifiers like `.onReceive` and `.overlay` on the split view itself get re-evaluated during sidebar animation. Move them into child views to isolate observation scope.
- **Use `.lineLimit(1)` in sidebar rows.** Variable row heights cause AppKit NSTableView layout feedback during sidebar width animation — text reflows, heights change, scrollbar toggles, widths change again.

## Releases

Before preparing or publishing a release, read [RELEASING.md](RELEASING.md) and `.release.json`. Use an explicit version with no `v` prefix, write curated changelog notes, preserve history, prepare required version files/assets, and commit only intended changes. Use `python3 scripts/release.py X.Y.Z --dry-run`, then the same command without `--dry-run` when a release is requested. Verify the resulting workflow and release before reporting success. Do not use Shipmark, automatic commit-based bumping, `git push --tags`, or a second GitHub release creator. Code changes alone are not a request to publish.
