# Setup Instructions for ContextKey

## To Open and Build This App

Since you only have the source files (not an Xcode project), you need to create one. Here's how:

### Step 1: Create Xcode Project

1. Open **Xcode**
2. Click **File → New → Project**
3. Select **macOS** tab → **App** → Click **Next**
4. Fill in:
   - **Product Name**: `ContextKey`
   - **Team**: Select your Apple Developer team (or "None" for local testing)
   - **Organization Identifier**: `com.yourname` (e.g., `com.lucci`)
   - **Interface**: **SwiftUI**
   - **Language**: **Swift**
   - **Uncheck** "Use Core Data"
   - **Check** "Create Git repository" (optional)
5. Save the project in a **NEW** folder (e.g., `ContextKey-Xcode`)

### Step 2: Add Source Files

1. In Xcode, **delete** the auto-generated files:
   - `ContentView.swift` (the default one)
   - `ContextKeyApp.swift` (the default one)

2. **Drag and drop** all `.swift` files from your current `ContextKey` folder into the Xcode project navigator:
   - ContextKey_DesktopApp.swift
   - AppDelegate.swift
   - ContentView.swift
   - CompactQueryView.swift
   - SettingsView.swift
   - HotkeyManager.swift
   - SupportedLLMs.swift
   - URLSchemeHandler.swift

3. When prompted, check:
   - ✅ "Copy items if needed"
   - ✅ "Create groups"
   - ✅ Add to target: ContextKey

### Step 3: Add Assets and Entitlements

1. **Delete** the auto-generated `Assets.xcassets` in Xcode
2. **Drag and drop** your `Assets.xcassets` folder into the project
3. **Drag and drop** `ContextKey.entitlements` into the project

### Step 4: Configure Project Settings

1. Click on your project in the navigator (blue icon at top)
2. Select the **ContextKey** target
3. Go to **Signing & Capabilities** tab:
   - Select your Team or use "Sign to Run Locally"
   - Under "App Sandbox", ensure these are enabled:
     - ✅ Outgoing Connections (Client)
     - ✅ Incoming Connections (Server)
     - ✅ User Selected File (Read/Write)

4. Go to **Build Settings** tab:
   - Search for "Entitlements"
   - Set **Code Signing Entitlements** to: `ContextKey.entitlements`

5. Go to **General** tab:
   - Set **Minimum Deployments** to macOS 12.0 or later

### Step 5: Add Dependencies (IMPORTANT!)

Your app uses **CocoaMQTT** (even though we removed MQTT code, it's still imported somewhere). We need to remove this:

1. Open each Swift file and check for `import CocoaMQTT`
2. Remove any remaining MQTT imports

**OR** if you want to add it back for future use:
1. In Xcode: **File → Add Package Dependencies**
2. Enter: `https://github.com/emqx/CocoaMQTT`
3. Click **Add Package**

### Step 6: Build and Run

1. Press **⌘+B** to build
2. Fix any errors (there shouldn't be any!)
3. Press **⌘+R** to run

## To Create a Distributable .app File

### Method 1: Simple Export (for testing)

1. Build the project (⌘+B)
2. In Xcode, go to **Products** folder in the navigator
3. Right-click **ContextKey.app** → **Show in Finder**
4. Copy this `.app` file anywhere to run it

### Method 2: Archive for Distribution (recommended)

1. In Xcode: **Product → Archive**
2. Wait for archive to complete
3. In the Organizer window:
   - Click **Distribute App**
   - Choose **Copy App**
   - Save the exported app

The exported `.app` can be shared and will run on other Macs (with the same macOS version).

### Method 3: Create DMG Installer (professional)

After exporting the .app:

```bash
# Create a DMG installer
hdiutil create -volname "ContextKey" -srcfolder /path/to/ContextKey.app -ov -format UDZO ContextKey.dmg
```

## Common Issues

### Issue: "Developer cannot be verified"
**Solution**: Right-click the app → Open (this works first time only)

### Issue: Build fails with "CocoaMQTT not found"
**Solution**: We removed MQTT. Check if any file still imports it and remove the import.

### Issue: App crashes on launch
**Solution**: Check Console.app for error messages. Usually it's a missing permission.

## For Open Source Distribution

Before pushing to GitHub:

1. ✅ Create a comprehensive README (done!)
2. ✅ Choose a license (MIT, GPL, Apache, etc.)
3. ⚠️ Remove any sensitive data (API keys, personal info)
4. ⚠️ Test building from scratch on a clean machine
5. 📦 Consider using GitHub Actions for automatic builds
6. 🎯 Add screenshots to README
7. 🏷️ Create releases with pre-built .app files

## Next Steps

1. **Remove remaining MQTT references** - Clean up any leftover imports
2. **Test the app thoroughly** - Make sure all features work
3. **Add app icon** - Create a nice icon for Assets.xcassets
4. **Create screenshots** - For the README
5. **Set up GitHub Actions** - Automate builds (optional but nice!)
