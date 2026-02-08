# DrawThingsStudio Functional Test Report

**Date:** 2026-02-07
**Tester:** Claude (automated via AppleScript)
**Draw Things:** Running with gRPC on port 7859

## Issues Summary

| Issue | Severity | Status |
|-------|----------|--------|
| #1: UI Tests Modify Real App Settings | High | ✅ FIXED |
| #2: Empty Model Field Causes Silent Failure | Medium | ✅ FIXED |
| #3: Generated Images Folder Not Found | Medium | ✅ NOT A BUG (sandboxed path) |
| #4: gRPC Model/LoRA Fetching Returns Empty | Low | Known Issue (has workaround) |
| #5: Keyboard Input Sometimes Fails | Low | AppleScript issue, not app bug |

---

## Issue Details

### Issue #1: UI Tests Modify Real App Settings ✅ FIXED
**Severity:** High
**Location:** UI Tests / UserDefaults persistence

**Description:**
The UI test `testSettingsRetainedAfterNavigation` in `SettingsTests.swift` enters test values like `test-host-4556` into the Host field. These values persist in UserDefaults after the test completes, breaking the app's connection to Draw Things for subsequent use.

**Fix Applied:**
- Added `resetSettingsToDefaults()` method to `SettingsTests.swift`
- Called in `tearDownWithError()` to restore default values after each test
- Uses plausible test values (like `192.168.1.100`) instead of random strings
- Default values: Host=127.0.0.1, HTTP Port=7860, gRPC Port=7859

---

### Issue #2: Empty Model Field Causes Silent Generation Failure ✅ FIXED
**Severity:** Medium
**Location:** `ImageGenerationView.swift` / `ImageGenerationViewModel.swift`

**Description:**
When the Model field is empty and the user clicks Generate, the app starts generation but produces a static/noise image because no model is specified.

**Fix Applied:**
- Added model validation in `ImageGenerationViewModel.generate()`:
  ```swift
  guard !config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      errorMessage = "Please specify a model (enter manually or refresh from Draw Things)"
      return
  }
  ```
- Disabled Generate button in `ImageGenerationView.swift` when model is empty

---

### Issue #3: Generated Images Folder Not Found ✅ NOT A BUG
**Severity:** Medium (originally)
**Location:** `ImageStorageManager.swift`

**Description:**
The folder `~/Library/Application Support/DrawThingsStudio/GeneratedImages/` was not found during testing.

**Investigation Result:**
This is **expected behavior for a sandboxed macOS app**. The actual storage location is:
```
~/Library/Containers/tanque.org.DrawThingsStudio/Data/Library/Application Support/DrawThingsStudio/GeneratedImages/
```

**Evidence:**
- 14 PNG images with JSON metadata sidecars found in the sandboxed location
- Images date from January 24 to February 7, 2026
- Both image files and metadata JSON files are correctly persisted
- The `openStorageDirectory()` function correctly opens the sandboxed location

**Conclusion:** Image persistence is working correctly.

---

### Issue #4: gRPC Model/LoRA Fetching Returns Empty (Known Issue)
**Severity:** Low (has workaround)
**Location:** `DrawThingsGRPCClient.swift`

**Description:**
The connection shows "Connected via gRPC - 0 models, 0 LoRAs" even when Draw Things has models loaded. The manual entry field works as a workaround.

**Status:** Known issue from previous sessions. The `EchoReply` from Draw Things doesn't expose model names in a parseable format.

---

### Issue #5: Keyboard Input Sometimes Fails in Text Fields
**Severity:** Low
**Location:** SwiftUI text fields

**Description:**
During AppleScript testing, `keystroke` commands sometimes failed to enter text in text fields. Using `set value of` worked reliably instead.

**Analysis:**
This is an AppleScript/accessibility interaction issue, not a bug in the app. The app's text fields work correctly when used normally.

---

## Successful Functionality

✅ **gRPC Connection** - Successfully connects to Draw Things at 127.0.0.1:7859
✅ **Image Generation** - Successfully generates images when model is specified manually
✅ **Gallery Display** - Generated images appear in the gallery with thumbnails
✅ **Image Persistence** - Images correctly saved to sandboxed container (14 images verified)
✅ **Navigation** - All sidebar navigation works correctly
✅ **Settings Persistence** - Settings save to UserDefaults correctly

## Test Environment

- macOS 26.2 (arm64)
- Draw Things running with gRPC enabled on port 7859
- Model: flux1-schnell-q8p.ckpt
- Transport: gRPC

## Recommendations (Remaining)

1. ~~Add model validation before generation~~ ✅ Done
2. ~~Fix image persistence~~ ✅ Not needed (was working correctly)
3. ~~Reset test settings~~ ✅ Done
4. **Consider connection test on launch** - Auto-check connection when app starts
5. **Document sandboxed storage location** - Update README or in-app help to clarify where images are stored
