# Changelog

All notable changes to CleanM are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Release pipeline signs with Developer ID (hardened runtime + secure timestamp), notarizes and staples automatically when a certificate and `notarytool` profile are available.

## [1.0.0] - 2026-11-20

### Added
- **Smart Scan** — one-click scan of System Junk, Trash and Large & Old files with a combined summary and safe clean.
- **System Junk** — user caches, logs, Xcode DerivedData & Archives, Homebrew cache with per-item selection.
- **Large & Old Files** — finds big or forgotten files in Downloads, Documents, Desktop and Movies; filters, Quick Look (Space) and Reveal in Finder.
- **Uninstaller** — removes apps together with their leftovers (Application Support, Preferences, Caches, Containers, …).
- **System Monitor** — live CPU (per core), memory & pressure, disk and network, plus a menu bar monitor.
- **Free Up RAM** — runs `purge` through the standard macOS administrator prompt.
- Safety whitelist that re-checks every path before removal; Move to Trash by default.
- Natural green theme and leaf app icon.
- Update checker that compares the installed version with the latest GitHub release.

[Unreleased]: https://github.com/Iambulldog/cleanM/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Iambulldog/cleanM/releases/tag/v1.0.0
