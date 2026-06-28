# smART Sketcher Tools

Unofficial tools for the **smART Sketcher Projector 2.0** — transfer any image to the projector over Bluetooth, for free.

If you bought your kid this device and discovered the outrageous subscription prices just to access a small set of clip-art images, this is for you. Use it directly or build your own app on top of the [protocol specification](docs/protocol.md).

---

## Apps

| Platform     | Location                  | Min OS       |
|--------------|---------------------------|--------------|
| iOS / iPadOS | `apps/apple/`             | iOS 16.0     |
| macOS        | `apps/apple/`             | macOS 13.0   |

Both apps are built from a single shared Swift + SwiftUI codebase using Xcode with two separate targets.

---

## Prerequisites

| Tool        | Install                        | Purpose                        |
|-------------|--------------------------------|--------------------------------|
| Xcode 15+   | Mac App Store                  | Build iOS & macOS targets      |
| xcodegen    | `brew install xcodegen`        | Generate `.xcodeproj` from YAML|
| cairo       | `brew install cairo`           | Icon generation (SVG → PNG)    |
| Python 3    | system / `brew install python` | Icon generation script         |
| Pillow + cairosvg | `pip3 install pillow cairosvg` | Icon generation dependencies |

---

## Getting Started

```bash
# 1. Generate the Xcode project
make gen

# 2. Open in Xcode
make open
```

Select your target (SmartSketcher-iOS or SmartSketcher-macOS) and hit Run.

### First run on a real device

- **iOS / iPadOS** — connect via USB, trust the Mac on the device, select it from Xcode's run destination, and hit Run. Apps signed with a free Apple ID expire after 7 days; a paid developer account removes that limit.
- **macOS** — build and run directly from Xcode, or copy the built `.app` from `~/Library/Developer/Xcode/DerivedData/` to `/Applications`.

---

## Makefile Reference

```
make gen            Generate SmartSketcher.xcodeproj from apps/apple/project.yml
make open           Open the project in Xcode
make build-ios      Headless iOS build (no signing)
make build-macos    Headless macOS build (no signing)
make icon           Regenerate all icon assets from assets/smart-sketcher-icon-512.svg
make dist           Archive, notarize, and staple for direct distribution (macOS)
make archive        Archive + export for App Store Connect upload
make validate       Validate an App Store archive (requires API_KEY and API_ISSUER)
make upload         Upload an App Store archive  (requires API_KEY and API_ISSUER)
make clean          Remove build artifacts and generated project files
```

---

## Direct Distribution (macOS)

The `make dist` target produces a notarized, Gatekeeper-compatible `.app` for sharing outside the App Store.

**Prerequisites:**
- A **Developer ID Application** certificate installed in your keychain
  - Create in Xcode → Settings → Accounts → Manage Certificates → `+` → Developer ID Application
- An **App Store Connect API key** (`.p8` file)
  - Generate at appstoreconnect.apple.com → Users & Access → Integrations → API Keys
  - Place the file at `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`

```bash
make dist API_KEY=<KEY_ID> API_ISSUER=<ISSUER_UUID>
```

The finished app lands in `build/dist/smART Sketcher.app`. Copy it to `/Applications` or wrap it in a DMG to distribute.

---

## App Store Distribution (macOS)

```bash
# Archive and export
make archive

# Validate, then upload
make validate API_KEY=<KEY_ID> API_ISSUER=<ISSUER_UUID>
make upload   API_KEY=<KEY_ID> API_ISSUER=<ISSUER_UUID>
```

After uploading, complete submission in App Store Connect.

---

## Icon

The icon source is `assets/smart-sketcher-icon-512.svg`. To regenerate all sizes:

```bash
make icon
```

This writes:
- `assets/Icon.icns` — macOS icon bundle
- `assets/icon_preview.png` — 512px preview
- `apps/apple/SmartSketcher/Assets.xcassets/AppIcon.appiconset/icon_*.png` — Xcode asset catalog

---

## Project Structure

```
.
├── apps/
│   └── apple/
│       ├── project.yml                  # xcodegen project definition
│       └── SmartSketcher/
│           ├── SmartSketcherApp.swift
│           ├── ContentView.swift
│           ├── BLEManager.swift         # CoreBluetooth + async/await
│           ├── ImageProcessor.swift     # RGB565 conversion
│           ├── Platform.swift           # UIImage / NSImage shim
│           ├── Assets.xcassets/
│           └── SmartSketcher-macOS.entitlements
├── assets/
│   └── smart-sketcher-icon-512.svg      # Icon source
├── docs/
│   └── protocol.md                      # BLE protocol specification
├── scripts/
│   └── make_icon.py                     # Icon generation script
└── Makefile
```

---

## Protocol

See [docs/protocol.md](docs/protocol.md) for the full BLE command reference and image transfer specification.
