# Quick Start Guide

## You Cannot Open This App Yet! Here's Why:

You currently have **source code files only** - no Xcode project. Think of it like having all the ingredients but no recipe card.

## To Actually Use This App (2 Options):

### Option A: Build It Yourself (Recommended for Development)

**Follow these steps:**

1. **Open Xcode** (download from Mac App Store if needed)

2. **Create New Project:**
   - File → New → Project
   - macOS → App
   - Product Name: `ContextKey`
   - Interface: SwiftUI
   - Language: Swift
   - Save somewhere (like `~/Desktop/ContextKey-Project`)

3. **Add Your Files:**
   - Delete the auto-generated `ContentView.swift` and `ContextKeyApp.swift`
   - Drag ALL `.swift` files from `Sources/ContextKey/` into Xcode
   - Drag `Resources/Assets.xcassets` into Xcode
   - Drag `Resources/ContextKey.entitlements` into Xcode
   - When prompted, check "Copy items if needed"

4. **Configure Entitlements:**
   - Click project name in Xcode sidebar
   - Select target → Signing & Capabilities
   - Make sure App Sandbox is enabled with:
     - Outgoing Connections
     - User Selected File (Read/Write)

5. **Build:** Press ⌘+B

6. **Run:** Press ⌘+R

### Option B: I'll Help You Create an Xcode Project

Run this in Terminal from your ContextKey folder:

```bash
# This will open Xcode with instructions
open -a Xcode
```

Then follow the on-screen instructions from SETUP.md

## What You Have Now:

```
ContextKey/
├── Sources/ContextKey/          ← Your Swift code
│   ├── ContextKey_DesktopApp.swift
│   ├── ContentView.swift
│   ├── CompactQueryView.swift
│   ├── SettingsView.swift
│   ├── AppDelegate.swift
│   ├── DataManager.swift
│   ├── HotkeyManager.swift
│   ├── SupportedLLMs.swift
│   └── URLSchemeHandler.swift
├── Resources/                   ← Assets & permissions
│   ├── Assets.xcassets/
│   └── ContextKey.entitlements
├── README.md                    ← Full documentation
├── SETUP.md                     ← Detailed setup guide
└── QUICK_START.md              ← This file!
```

## What You Need:

❌ Xcode Project (.xcodeproj)
❌ Built Application (.app file)

## After Building:

The `.app` file will be in:
`~/Library/Developer/Xcode/DerivedData/ContextKey-[random]/Build/Products/Debug/ContextKey.app`

Or find it in Xcode:
- Product menu → Show Build Folder in Finder

## For Open Source Distribution:

See `README.md` for full instructions on:
- Creating distributable builds
- Setting up GitHub releases
- Adding app icons
- Code signing and notarization

## Need Help?

1. Read `SETUP.md` for detailed step-by-step instructions
2. Read `README.md` for feature documentation
3. Check Console.app if the app crashes
4. Open an issue on GitHub

## What Changed from HeyCodee:

✅ Renamed HeyCodee → ContextKey
✅ Removed all MQTT/device connection features
✅ Cleaned up code structure
✅ Added comprehensive documentation
✅ Ready for open source

Now you just need to create the Xcode project!
