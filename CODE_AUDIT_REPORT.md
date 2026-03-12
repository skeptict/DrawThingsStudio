# DrawThingsStudio Code Audit Report

**Last Run:** 2026-03-12T00:00:00Z
**App Version:** 0.6.1
**Scope:** Targeted audit — ImageLightboxView, SwiftDataBackupManager, ImageGenerationView, ContentView (BackupCoordinator), plus broad scan of all 58 Swift files for crash risks, memory leaks, SwiftData misuse, concurrency issues, silent failures, and UI gaps
**Auditor:** Claude code-quality-auditor agent

---

## Summary
- 🔴 Critical Security Issues: 0
- 🟠 High Priority: 4
- 🟡 Medium Priority: 5
- 🟢 Low Priority / Style: 3

---

## Findings

### [HIGH-1] NSEvent monitor in struct — may leak if view is removed during animation — `ImageLightboxView.swift:21`

**Category:** Memory / Best Practice
**Severity:** High

**Explanation:**
`LightboxOverlay` is a `struct` (SwiftUI `View`). `@State private var eventMonitor: Any?` stores the monitor handle. SwiftUI can deallocate the struct without calling `onDisappear` if a parent view removes the branch before the disappear lifecycle fires (e.g., the binding is set to `nil` while a dismiss animation is mid-flight, or the app is backgrounded during dismissal). When that happens `NSEvent.removeMonitor(_:)` is never called and the monitor remains active indefinitely, receiving every key-down event in the app.

Under normal usage the `.transition(.opacity)` + `.animation` at the `ZStack` level ensures `onDisappear` fires before the view is released, so the risk is low in practice. But the pattern is fragile: it relies on SwiftUI's animation lifecycle rather than a guaranteed ownership model.

**Current Code (`ImageLightboxView.swift:66-81`):**
```swift
.onAppear {
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in ... }
}
.onDisappear {
    if let monitor = eventMonitor {
        NSEvent.removeMonitor(monitor)
        eventMonitor = nil
    }
}
```

**Improved Code:**
```swift
// Tie the monitor lifetime to a class whose deinit always runs
private final class KeyEventMonitor {
    var monitor: Any?
    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }
}
@StateObject private var keyEventMonitor = KeyEventMonitor()

.onAppear {
    keyEventMonitor.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        // ...same switch...
    }
}
// No onDisappear needed — deinit handles cleanup
```

---

### [HIGH-2] `sheet(isPresented:)` with separate nullable state — blank sheet possible if state is cleared before render — `ImageGenerationView.swift:1204`

**Category:** Best Practice / Bug
**Severity:** High

**Explanation:**
`showDescribeSheet` (Bool) and `imageToDescribe` (NSImage?) are set together at line 1356-1357. The sheet body re-reads `imageToDescribe` lazily on the next render pass. If SwiftUI batches the state writes and `imageToDescribe` is nil at sheet presentation time (e.g., cleared by a concurrent `generatedImages` array mutation, or in a future refactor), the guard `if let image = imageToDescribe` fails silently and the sheet appears blank.

This is the same anti-pattern fixed for `imageForStoryStudio` on line 60, which correctly uses `sheet(item:)`.

**Current Code:**
```swift
// Line 1356:
imageToDescribe = generatedImage.image
showDescribeSheet = true

// Line 1204:
.sheet(isPresented: $showDescribeSheet) {
    if let image = imageToDescribe {  // re-reads imageToDescribe at present time
        ImageDescriptionView(image: image, ...)
    }
    // Blank if imageToDescribe is nil at this point
}
```

**Improved Code:**
```swift
// Define a lightweight Identifiable wrapper (or just use sheet(item:) with Optional<NSImage> via a protocol)
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: NSImage
}

@State private var imageToDescribe: IdentifiableImage?

// Button tap:
imageToDescribe = IdentifiableImage(image: generatedImage.image)

// Sheet:
.sheet(item: $imageToDescribe) { item in
    ImageDescriptionView(image: item.image, ...)
}
```

---

### [HIGH-3] Backup only triggers on collection `.count` changes — edits to existing records are never backed up — `ContentView.swift:1632`

**Category:** Best Practice / Data Integrity
**Severity:** High

**Explanation:**
`BackupCoordinator` observes only the *count* of each `@Query` array. Any mutation to an existing record — renaming a workflow, updating a story scene's prompt, changing a character's description — does not change the count and therefore does not trigger a backup. After a schema wipe the user would lose all edits made since the last add/delete operation.

Since the backup exists specifically to guard against schema wipe data loss, this is a significant gap in its protection.

**Current Code:**
```swift
.onChange(of: presets.count) { _, _ in Task { await runBackup() } }
.onChange(of: workflows.count) { _, _ in Task { await runBackup() } }
.onChange(of: pipelines.count) { _, _ in Task { await runBackup() } }
.onChange(of: storyProjects.count) { _, _ in Task { await runBackup() } }
```

**Improved Code:**
```swift
// Observe a property that changes on every write, e.g. the latest modifiedAt timestamp.
// Add this computed property to BackupCoordinator:
private var latestWorkflowModification: Date {
    workflows.compactMap(\.modifiedAt).max() ?? .distantPast
}
private var latestProjectModification: Date {
    storyProjects.map(\.modifiedAt).max() ?? .distantPast
}

// Replace count-only onChange with:
.onChange(of: workflows.count) { _, _ in Task { await runBackup() } }
.onChange(of: latestWorkflowModification) { _, _ in Task { await runBackup() } }
.onChange(of: storyProjects.count) { _, _ in Task { await runBackup() } }
.onChange(of: latestProjectModification) { _, _ in Task { await runBackup() } }
// etc.
```

---

### [HIGH-4] `WorkflowPromptGenerator` mutates `@Published` properties off `@MainActor` — potential data race — `WorkflowPromptGenerator.swift:13`

**Category:** Concurrency
**Severity:** High

**Explanation:**
`WorkflowPromptGenerator` is a plain `class` (no `@MainActor` annotation). Its `@Published` properties (`isGenerating`, `currentProgress`, `lastError`) must be mutated on the main actor for SwiftUI observation to be safe. The class routes mutations through `@MainActor` helper methods (`setGenerating`, `updateProgress`), but:

1. Swift 6 strict concurrency will warn: accessing `@Published` on a non-isolated class from an async context is a potential data race.
2. `defer { Task { await setGenerating(false) } }` spawns an unstructured `Task` inside `defer`. The new Task inherits the current task's cancellation status. If the parent task is cancelled, the defer-spawned Task may also be immediately cancelled before `setGenerating(false)` executes, leaving `isGenerating = true` stuck permanently.
3. The class is not `final`, allowing subclasses to inherit a broken concurrency model.

Adding `@MainActor final` to the class declaration resolves all three issues and allows `defer` to call `setGenerating(false)` directly.

**Current Code:**
```swift
class WorkflowPromptGenerator: ObservableObject {
    @Published var isGenerating: Bool = false
    ...
    defer { Task { await setGenerating(false) } }  // can be skipped if Task is cancelled
```

**Improved Code:**
```swift
@MainActor
final class WorkflowPromptGenerator: ObservableObject {
    @Published var isGenerating: Bool = false
    ...
    defer { setGenerating(false) }  // direct call, always runs
```

---

### [MEDIUM-1] Backup encode/write errors are silently swallowed — no log on disk write failure — `SwiftDataBackupManager.swift:102`

**Category:** Silent Failure
**Severity:** Medium

**Explanation:**
The backup write path uses nested `try?` without any error logging. The success log message at line 121 fires regardless of whether any writes succeeded. A disk-full condition, revoked sandbox entitlement, or unexpected path failure would leave the backup files stale with no indication in logs.

**Current Code:**
```swift
if let data = try? encoder.encode(backupWorkflows) {
    try? data.write(to: workflowsURL)   // failure is silent
}
logger.info("Backup written: ...")      // fires even if write failed
```

**Improved Code:**
```swift
do {
    let data = try encoder.encode(backupWorkflows)
    try data.write(to: workflowsURL)
    logger.info("Workflows backup written: \(backupWorkflows.count) items")
} catch {
    logger.error("Failed to write workflows backup: \(error.localizedDescription)")
}
```

---

### [MEDIUM-2] Backup serializes all image blobs as base64 JSON — backup file will be very large for Story Studio users — `SwiftDataBackupManager.swift:253,345,384,474,538`

**Category:** Performance / Data Integrity
**Severity:** Medium

**Explanation:**
The Story Studio backup embeds raw image `Data` (base64-encoded in JSON) for:
- `StoryProjectBackup.coverImageData`
- `StoryCharacterBackup.primaryReferenceImageData`
- `CharacterAppearanceBackup.referenceImageData`
- `StorySettingBackup.referenceImageData`
- `StorySceneBackup.generatedImageData`
- `SceneVariantBackup.imageData`

A moderate project (20 scenes, 5 characters, 3 settings) with 0.5–1 MB reference images could produce a 20–50 MB JSON file. This is encoded and decoded synchronously on the `@MainActor`, blocking the main thread during restore. It also means the cycle-6 fix (setting `SceneVariant.imageData = nil` at generation time) is partially undone on restore if the old blob was present in SwiftData when the backup was written.

Since the backup's purpose is metadata recovery after a schema wipe, image blobs should be excluded. Character/setting reference images are imported from disk and can be re-imported. Generated scene images are stored at `imagePath` and will be found again on next load.

---

### [MEDIUM-3] Same `sheet(isPresented:) { if let ... }` anti-pattern in DTProjectBrowserView — `DTProjectBrowserView.swift:1170,1436`

**Category:** Best Practice
**Severity:** Medium

**Explanation:**
The DTDetailPanel and DTClipDetailPanel describe sheets both read `entry.thumbnail` / `clip.frames[...]` lazily inside `sheet(isPresented:)`. For the clip variant, `selectedFrameIndex` is read at sheet-present time, not at button-tap time. If the user taps a different frame thumbnail in the strip while the sheet is animating in (edge case), the sheet could open on a different frame than intended. Same fix applies: capture the target image at button-tap time and use `sheet(item:)`.

---

### [MEDIUM-4] Four concurrent backup Tasks may race on schema-wipe restore — `ContentView.swift:1632`

**Category:** Performance / Correctness
**Severity:** Medium

**Explanation:**
If all four `@Query` arrays change count simultaneously during restore, all four `onChange` closures fire in the same render cycle, each spawning `Task { await runBackup() }`. Four concurrent tasks each calling `SwiftDataBackupManager.backup(...)` will race to write the same JSON files. The last write wins, which is probably correct, but it wastes work and could cause interleaved writes on a slow disk. A coalescing mechanism (debounce or a serial queue on the backup manager) would prevent this.

---

### [MEDIUM-5] `try? modelContext.save()` in restore path — failed restore is silent — `ContentView.swift:1652`

**Category:** Silent Failure
**Severity:** Medium

**Explanation:**
After restoring backed-up records on schema-wipe, `try? modelContext.save()` is called silently. If the save fails, the restored objects will be lost when the context is discarded. Given this is the one moment the user's data is being recovered, this should use a `do/try/catch` with a logger call or an alert.

**Current Code:**
```swift
if counts.presets + counts.workflows + counts.pipelines + restoredStory > 0 {
    try? modelContext.save()
}
```

**Improved Code:**
```swift
if counts.presets + counts.workflows + counts.pipelines + restoredStory > 0 {
    do {
        try modelContext.save()
    } catch {
        logger.error("Failed to save restored records: \(error.localizedDescription)")
        // Consider showing an alert to the user
    }
}
```

---

### [LOW-1] `clip.frames[0]` direct subscript in tap gestures — prefer `.first` — `DTProjectBrowserView.swift:384,417`

**Category:** Crash Risk (theoretical)
**Severity:** Low

**Explanation:**
`DTVideoClip.group(from:)` always produces clips with at least one frame, so `frames[0]` cannot crash in practice. However the subscript is unsafe by code inspection alone, and `.first` communicates intent more clearly.

**Current Code:**
```swift
if let img = clip.frames[0].thumbnail { lightboxImage = img }
viewModel.exportImage(clip.frames[0])
```

**Improved Code:**
```swift
if let img = clip.frames.first?.thumbnail { lightboxImage = img }
if let frame = clip.frames.first { viewModel.exportImage(frame) }
```

---

### [LOW-2] `WorkflowPromptGenerator` is not `final` — `WorkflowPromptGenerator.swift:13`

**Category:** Best Practice
**Severity:** Low (subsumed by HIGH-4 — fix both together)

Every other ViewModel in the project is `final`. Adding `final` prevents subclassing a class with a broken concurrency model and enables vtable devirtualisation.

---

### [LOW-3] `BackupCoordinator.runBackup()` is `async` but does no async work — `ContentView.swift:1661`

**Category:** Readability
**Severity:** Low

**Explanation:**
`runBackup()` is marked `async` but calls `SwiftDataBackupManager.backup(...)` which is synchronous. The `async` annotation is unnecessary and slightly misleading. It should be `@MainActor func runBackup()` (no `async`) since all the work is synchronous SwiftData access on the main actor.

---

## Applied Fixes
None applied this cycle — findings presented for review.

## Notes

**ImageLightboxView NSEvent monitor (HIGH-1):** Works correctly under normal conditions. The risk is animation-race edge cases. Converting `LightboxOverlay` to own a `@StateObject KeyEventMonitor` is the cleanest fix.

**Backup system (HIGH-3, MEDIUM-1, -2, -4, -5):** The backup system is well-structured overall. The main gaps are: (a) only reacts to count changes, missing content edits; (b) silently drops write errors; (c) embeds large image blobs; (d) silent `try?` on the restore save. These are independent fixes that can be addressed incrementally.

**`frames[0]` (LOW-1):** Safe in practice due to invariant in `DTVideoClip.group(from:)`. Two-line fix.

**No security issues found** in the audited files or in the broad scan of all 58 Swift files.
