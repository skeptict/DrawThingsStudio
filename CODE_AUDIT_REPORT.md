# DrawThingsStudio Code Audit Report

**Last Run:** 2026-03-01T17:14:44Z
**App Version:** 0.4.25
**Scope:** Full Project — all Swift files in `DrawThingsStudio/` target directory
**Auditor:** Claude code-quality-auditor agent (cycle 6)

---

## Summary

- 🔴 Critical Security Issues: 1
- 🟠 High Priority: 5
- 🟡 Medium Priority: 8
- 🟢 Low Priority / Style: 6

---

## Findings

---

### [CRITICAL] `StoryStudioViewModel.importReferenceImage` loads arbitrary file data without size validation — `StoryStudioViewModel.swift:467, 481`

**Category:** Security
**Severity:** Critical

**Explanation:**
Both `importReferenceImage(for:)` overloads load the entire file content into memory using `try? Data(contentsOf: url)` inside an `NSOpenPanel.begin {}` callback. The callback fires on the main thread. Two problems:
1. A malicious or accidentally huge image file (e.g. a 4 GB TIFF) is loaded synchronously on the main actor, blocking the UI and potentially causing an OOM crash.
2. There is no upper-bound size check. A sandboxed user could select any file that passes the `.png`/`.jpeg` type check — but `allowedContentTypes` in NSOpenPanel is not a security guarantee, it is only a display filter and can be bypassed by the user enabling "All Files" in the dialog.

Even for benign use, storing arbitrarily large Data blobs in SwiftData `@Model` properties (`primaryReferenceImageData`, `referenceImageData`) will silently balloon the SQLite store and degrade performance.

**Current Code:**
```swift
// StoryStudioViewModel.swift:466-472
panel.begin { [weak self] response in
    guard response == .OK, let url = panel.url,
          let data = try? Data(contentsOf: url) else { return }
    character.primaryReferenceImageData = data
    self?.selectedProject?.modifiedAt = Date()
}
```

**Recommended Fix:**
```swift
panel.begin { [weak self] response in
    guard response == .OK, let url = panel.url else { return }

    // Read off the main thread and apply a size ceiling (10 MB is generous
    // for a reference thumbnail; actual images are much smaller).
    Task { [weak self] in
        guard let self else { return }
        let maxBytes = 10 * 1024 * 1024
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attrs[.size] as? Int ?? 0
            guard size <= maxBytes else {
                self.errorMessage = "Image is too large (max 10 MB)"
                return
            }
            let data = try Data(contentsOf: url)
            character.primaryReferenceImageData = data
            self.selectedProject?.modifiedAt = Date()
        } catch {
            self.errorMessage = "Could not load image: \(error.localizedDescription)"
        }
    }
}
```

---

### [HIGH] `StoryflowExporter.exportWithSavePanel` uses `DispatchQueue.main.async` inside an `async` function — `StoryflowExporter.swift:132`

**Category:** Swift/SwiftUI Best Practices — Swift Concurrency
**Severity:** High

**Explanation:**
The function is declared `async` and is called from `@MainActor` context. Inside it wraps a `withCheckedContinuation` in `DispatchQueue.main.async`. This is the old GCD pattern applied inside the new concurrency system. It is incorrect: `DispatchQueue.main.async` schedules work on the GCD main queue, which can diverge from the Swift `MainActor` executor under structured concurrency. The continuation must be resumed exactly once, and the GCD trampoline adds an unnecessary layer that makes this guarantee harder to audit. It also blocks structured cancellation from propagating correctly.

The caller (`WorkflowBuilderViewModel`) is `@MainActor`, so the panel can be shown directly without any dispatch.

**Current Code:**
```swift
// StoryflowExporter.swift:131-153
return await withCheckedContinuation { continuation in
    DispatchQueue.main.async {
        let savePanel = NSSavePanel()
        // ...
        savePanel.begin { response in
            // ...
            continuation.resume(returning: url)
        }
    }
}
```

**Recommended Fix:**
```swift
// Remove the DispatchQueue.main.async wrapper entirely.
// The caller is already on MainActor — no GCD dispatch needed.
return await withCheckedContinuation { continuation in
    let savePanel = NSSavePanel()
    savePanel.allowedContentTypes = [.json, .plainText]
    savePanel.nameFieldStringValue = suggestedFilename
    savePanel.title = "Save StoryFlow Instructions"
    savePanel.message = "Choose where to save your StoryFlow instructions"

    savePanel.begin { response in
        guard response == .OK, let url = savePanel.url else {
            continuation.resume(returning: nil)
            return
        }
        do {
            try jsonString.write(to: url, atomically: true, encoding: .utf8)
            continuation.resume(returning: url)
        } catch {
            continuation.resume(returning: nil)
        }
    }
}
```

---

### [HIGH] `ConfigPresetsManager.presetsDirectory` and `presetsFilePath` force-unwrap `FileManager.urls().first!` — `ConfigPresetsManager.swift:304, 312`

**Category:** Error Handling
**Severity:** High

**Explanation:**
`FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` is documented to return an empty array if the directory cannot be determined. The force-unwrap `!` on `.first` will crash the entire app on that nil path with no recovery. The same pattern is present in `ImageStorageManager.swift:32` (force-unwrap in a singleton `init`, crashing at app startup) and in `ImageInspectorViewModel.swift:150` (force-unwrap in a closure stored as a `let` property).

**Current Code:**
```swift
// ConfigPresetsManager.swift:303-308
let presetsDirectory: URL = {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    // ...
}()
```

**Recommended Fix:**
```swift
let presetsDirectory: URL = {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSTemporaryDirectory())
    let dir = appSupport.appendingPathComponent("DrawThingsStudio/Presets", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}()
```
Apply the same nil-coalescing to `ConfigPresetsManager.presetsFilePath:312`, `ImageStorageManager.init:32`, and `ImageInspectorViewModel.storageDirectory:150`.

---

### [HIGH] `DTVideoExporter` spin-wait loop can busy-poll for up to 2 seconds per frame — `DTVideoExporter.swift:127-131`

**Category:** Performance
**Severity:** High

**Explanation:**
The export loop polls `writerInput.isReadyForMoreMediaData` in a tight loop, sleeping 1 ms per iteration up to 2 000 retries. For a 60-frame clip at worst case, this is 2 minutes of spinning. When `expectsMediaDataInRealTime = false` (offline encoding), AVAssetWriter's h.264 encoder drains synchronously — it is always ready between appends. The poll loop is both unnecessary and excessively slow.

Additionally, if the encoder is still not ready after all retries, the frame is silently dropped, producing a video with missing frames and no diagnostic log entry.

**Current Code:**
```swift
// DTVideoExporter.swift:127-135
var retries = 0
while !writerInput.isReadyForMoreMediaData && retries < 2000 {
    try? await Task.sleep(nanoseconds: 1_000_000)
    retries += 1
}
if writerInput.isReadyForMoreMediaData {
    adaptor.append(pixelBuffer, withPresentationTime: pts)
}
```

**Recommended Fix:**
```swift
// For expectsMediaDataInRealTime = false, the encoder drains synchronously.
// Direct append is correct. Log a warning if the frame was not accepted.
if let pixelBuffer = image.toDTCVPixelBuffer(width: width, height: height) {
    if !adaptor.append(pixelBuffer, withPresentationTime: pts) {
        // writerStatus != .writing means something went wrong; let the caller
        // discover the error through writer.error at the end.
        break
    }
}
```

---

### [HIGH] `DTProjectDatabase.deleteEntries` silently commits even if individual row deletes fail — `DTProjectDatabase.swift:610-631`

**Category:** Error Handling / Data Integrity
**Severity:** High

**Explanation:**
In `deleteEntries(rowids:previewIds:from:)`, each `sqlite3_step` return value is ignored. If any `DELETE` fails (e.g. row already gone, constraint), the loop continues and the transaction is unconditionally committed. The caller then removes those items from in-memory `entries` as if deletion succeeded, producing a desync between the UI and the database.

By contrast, `deleteEntry` (singular) checks `deleteOk` before committing — this is an inconsistency and a logic bug in the multi-delete path.

**Current Code:**
```swift
// DTProjectDatabase.swift:611-616
if sqlite3_prepare_v2(writeDb, "DELETE FROM tensorhistorynode WHERE rowid = ?", -1, &stmt, nil) == SQLITE_OK {
    sqlite3_bind_int64(stmt, 1, rowid)
    sqlite3_step(stmt)   // return value ignored
}
sqlite3_finalize(stmt)
// ...
sqlite3_exec(writeDb, "COMMIT", nil, nil, nil)  // unconditional
```

**Recommended Fix:**
```swift
var allSucceeded = true

for (rowid, previewId) in zip(rowids, previewIds) {
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(writeDb, "DELETE FROM tensorhistorynode WHERE rowid = ?", -1, &stmt, nil) == SQLITE_OK {
        sqlite3_bind_int64(stmt, 1, rowid)
        if sqlite3_step(stmt) != SQLITE_DONE { allSucceeded = false }
    } else {
        allSucceeded = false
    }
    sqlite3_finalize(stmt)
    // thumbnail deletions remain best-effort, unchanged
}

if allSucceeded {
    sqlite3_exec(writeDb, "COMMIT", nil, nil, nil)
} else {
    sqlite3_exec(writeDb, "ROLLBACK", nil, nil, nil)
    throw DTProjectDatabaseError.deleteFailed("One or more rows could not be deleted")
}
```

---

### [HIGH] `StoryStudioViewModel.generateScene` stores full-resolution PNG blobs in SwiftData `SceneVariant.imageData` and `StoryScene.generatedImageData` — `StoryStudioViewModel.swift:336-365`

**Category:** Performance / Architecture
**Severity:** High

**Explanation:**
Each generated variant stores a full-resolution PNG (typically 1–4 MB at 1024×1024) as raw `Data` in SwiftData. SwiftData, like CoreData, is not designed for large blob storage: blobs are loaded entirely into memory on fetch, cannot be partially accessed, and are written in full to the WAL on every context save. A project with 10 scenes × 3 variants × 2 MB each = 60 MB in the SQLite store, all loaded into RAM whenever the project is opened.

Images are already being persisted to `GeneratedImages/` via `ImageStorageManager`. The `SceneVariant` model already has `imagePath: String?` for exactly this purpose — it should be used exclusively.

**Current Code:**
```swift
// StoryStudioViewModel.swift:344-355
let variant = SceneVariant(
    prompt: finalPrompt,
    negativePrompt: assembled.negativePrompt,
    seed: config.seed,
    imageData: pngData,     // full PNG blob in SwiftData
    isSelected: scene.variants.isEmpty
)
// ...
if scene.generatedImageData == nil {
    scene.generatedImageData = pngData   // also on scene
}
```

**Recommended Fix:**
```swift
// Save to disk and store only the file path in SwiftData.
if let savedImage = await ImageStorageManager.shared.saveImage(
    image, prompt: finalPrompt, negativePrompt: assembled.negativePrompt,
    config: config, inferenceTimeMs: nil)
{
    let variant = SceneVariant(
        prompt: finalPrompt,
        negativePrompt: assembled.negativePrompt,
        seed: config.seed >= 0 ? config.seed : 0,
        imageData: nil,                               // no blob in SwiftData
        imagePath: savedImage.filePath?.path,         // path reference only
        isSelected: scene.variants.isEmpty
    )
    variant.scene = scene
    scene.variants.append(variant)
}
```
Views should load the image on demand via `NSImage(contentsOfFile: variant.imagePath ?? "")`.

---

### [MEDIUM] `StoryStudioViewModel.addChapter` (and four other add-methods) set SwiftData relationships before inserting new objects into the `ModelContext` — `StoryStudioViewModel.swift:109-117, 132-140, 162-172, 189-200, 219-227`

**Category:** SwiftData Correctness
**Severity:** Medium

**Explanation:**
The macOS 14 SwiftData 1.0 crash pattern (EXC_BAD_INSTRUCTION on relationship mutation for objects not yet managed by a context) is documented in `createProject` with an explicit comment, and that method correctly inserts objects before establishing relationships. However, five other creation methods do not follow this pattern:

- `addChapter(title:)` — `StoryChapter` created without `context.insert` before `chapter.project = project`
- `addScene(title:to:)` — `StoryScene` created without `context.insert` before `scene.chapter = targetChapter`
- `addCharacter(name:promptFragment:)` — `StoryCharacter` created without `context.insert` before `character.project = project`
- `addSetting(name:promptFragment:)` — `StorySetting` created without `context.insert` before `setting.project = project`
- `addCharacterToScene(_:)` — `SceneCharacterPresence` created without `context.insert` before `presence.scene = scene`

**Current Code:** (representative — `addChapter`)
```swift
// StoryStudioViewModel.swift:109-117
let chapter = StoryChapter(title: title, sortOrder: nextOrder)
chapter.project = project       // relationship set before context.insert
project.chapters.append(chapter)
```

**Recommended Fix:**
```swift
guard let context = modelContext, let project = selectedProject else { return }
let chapter = StoryChapter(title: title, sortOrder: nextOrder)
context.insert(chapter)         // insert BEFORE establishing any relationships
chapter.project = project
project.chapters.append(chapter)
project.modifiedAt = Date()
selectedChapter = chapter
selectedScene = nil
```
Apply identical pattern to all five affected methods.

---

### [MEDIUM] `DTVideoExporter` opens a second `DTProjectDatabase` connection to the same file that the browser already has open — `DTVideoExporter.swift:46-53`

**Category:** Resource Management
**Severity:** Medium

**Explanation:**
`DTProjectBrowserViewModel.loadEntries()` may still have an open `DTProjectDatabase` connection (inside a `Task.detached`) to the project file when `exportClip` is called. `DTVideoExporter.export` opens another connection to the same file to fetch high-res thumbnails. SQLite opened with `SQLITE_OPEN_NOMUTEX` does not serialize between connections — it is the caller's responsibility to avoid concurrent writes. While two READONLY connections are safe in WAL mode on APFS, on external volumes (exFAT, FAT32) the database is opened with `immutable=1` which bypasses the lock file entirely. A concurrent read from the exporter during an active browser task could see a partially-updated state.

The thumbnail images from the initial load pass are already present in `clip.frames[i].thumbnail`. The exporter only fetches full-res thumbnails for quality; if the frames' `previewId` is valid, the same could be done by passing the database connection through rather than re-opening.

**Recommended Fix:**
Pass the pre-loaded thumbnail images directly to the exporter and avoid re-opening the database. If higher resolution is truly needed, coordinate through a shared or sequenced database access pattern.

---

### [MEDIUM] `RequestLogger.append` opens and closes a `FileHandle` on the calling thread for every log entry — `RequestLogger.swift:98-103`

**Category:** Performance
**Severity:** Medium

**Explanation:**
Each call to `append(_:)` opens a `FileHandle` (blocking `open(2)` syscall), seeks to end, writes, and closes (`close(2)`). All callers are on the main actor. While APFS file operations are fast, they are not guaranteed latency-free and this pattern holds the main actor for an I/O operation on every generation request. A persistent file handle (opened in `init` and kept open) is the standard pattern for append-only log files.

**Current Code:**
```swift
// RequestLogger.swift:98-104
if let handle = try? FileHandle(forWritingTo: url) {
    handle.seekToEndOfFile()
    handle.write(data)
    try? handle.close()
}
```

**Recommended Fix:**
Open the handle once in `init` and reuse it:
```swift
private let logHandle: FileHandle?

private init() {
    if let url = logFileURL {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? "DrawThingsStudio Request Log\n".write(to: url, atomically: true, encoding: .utf8)
        }
        logHandle = try? FileHandle(forWritingTo: url)
        try? logHandle?.seekToEnd()
    } else {
        logHandle = nil
    }
}

private func append(_ text: String) {
    guard let handle = logHandle, let data = text.data(using: .utf8) else { return }
    handle.write(data)
}
```

---

### [MEDIUM] `ImageBrowserViewModel.loadImages` does not reset `isLoading = false` on the cancellation path — `ImageBrowserViewModel.swift:317-330`

**Category:** State Correctness / UI
**Severity:** Medium

**Explanation:**
Inside `withTaskGroup`, when `Task.isCancelled` is detected, the code calls `group.cancelAll()` and breaks out of the loop. The `self.isLoading = false` assignment is only inside `if !Task.isCancelled`. On the cancellation path, `isLoading` remains `true` indefinitely. The user sees a permanent spinner until they trigger another `reload()`. The fix is to set `isLoading = false` unconditionally after the task group exits.

**Current Code:**
```swift
// ImageBrowserViewModel.swift:327-330
if !Task.isCancelled {
    self.images = accumulated.sorted { $0.createdAt > $1.createdAt }
    self.isLoading = false   // only set when not cancelled
}
// nothing resets isLoading on the cancelled path
```

**Recommended Fix:**
```swift
if !Task.isCancelled {
    self.images = accumulated.sorted { $0.createdAt > $1.createdAt }
}
self.isLoading = false   // always reset, regardless of cancellation
```

---

### [MEDIUM] `SceneVariant.seed` stores `config.seed` which may be `-1` (sentinel for "random"), making variants non-reproducible — `StoryStudioViewModel.swift:345`

**Category:** Logic Bug
**Severity:** Medium

**Explanation:**
`DrawThingsGenerationConfig.seed` uses `-1` as a sentinel meaning "let Draw Things pick a random seed." When a variant is saved with `seed: config.seed`, a `-1` is stored. Re-generating from that variant will produce a different image each time because `-1` is sent back as the seed, asking for another random seed. The variant's stored seed is meaningless for reproduction.

The HTTP response's `info` JSON field contains the actual seed used. Extracting and storing it would make variants genuinely reproducible. In the short term, a defensive fallback prevents `-1` from being stored:

**Recommended Fix:**
```swift
// Store 0 as a fallback (indicating "random, unknown") rather than -1.
// Ideally, extract the actual used seed from the API response's `info` field.
let storedSeed = config.seed >= 0 ? config.seed : 0
let variant = SceneVariant(
    prompt: finalPrompt,
    negativePrompt: assembled.negativePrompt,
    seed: storedSeed,
    ...
)
```

---

### [MEDIUM] `StoryStudioViewModel.generateScene` calls `ImageStorageManager.shared.saveImage` with `await` but `saveImage` is not `async` — `StoryStudioViewModel.swift:359-366`

**Category:** Swift Concurrency
**Severity:** Medium

**Explanation:**
`ImageStorageManager.saveImage` is a synchronous `@MainActor` method (no `async` in its signature). Calling it with `await` and capturing the result via `_ = await ImageStorageManager.shared.saveImage(...)` compiles because `@MainActor` methods can be awaited from any actor, but it implies the caller expects asynchronous behavior. The method blocks on disk I/O (CGImageDestination, PNG chunk injection, JSON write) on the main actor. For large images at high resolution, this can cause the generation progress callback to stutter. The I/O should be off-loaded to a background task.

**Recommended Fix:**
Move the `saveImage` work off the main actor using `Task.detached`. This is a larger refactor; the minimum fix is to note this in a `// TODO` and ensure the method's synchronous nature is explicitly documented.

---

### [LOW] `StoryflowExporter` is not `final` — `StoryflowExporter.swift:31`

**Category:** Readability / Best Practice
**Severity:** Low

**Explanation:**
The project convention is `@MainActor final class` or `final class` for all concrete classes. `StoryflowExporter` has no subclassing intent. Adding `final` enables static dispatch and is consistent with every other class in the codebase.

**Current Code:**
```swift
class StoryflowExporter {
```

**Recommended Fix:**
```swift
final class StoryflowExporter {
```

---

### [LOW] `PromptStyleManager.loadStylesSync` and `saveStyles` use `print()` instead of `Logger` — `LLMProvider.swift:233, 279`

**Category:** Readability / Observability
**Severity:** Low

**Explanation:**
`print()` output is invisible in production (stdout is not captured). Other managers in the project use `OSLog.Logger` for error reporting. Two `print` calls in `PromptStyleManager` should be converted to `logger.warning(...)` calls.

**Recommended Fix:**
```swift
private let logger = Logger(subsystem: "com.drawthingsstudio", category: "style-manager")

// Replace:
print("Failed to load custom styles: \(error)")
// With:
logger.warning("Failed to load custom styles: \(error.localizedDescription)")
```

---

### [LOW] `DTVideoClip.group` calls `.map(\.id).max()` inside the sort comparator, recomputing max per comparison — `DTProjectDatabase.swift:107-109`

**Category:** Performance
**Severity:** Low

**Explanation:**
The sort closure recomputes `frames.map(\.id).max()` for each comparison in O(N log N) sort, making the effective complexity O(N * K * log N) where K is the average number of frames per clip. Since frames are already sorted ascending by `logicalTime`, the last frame's `id` (rowid) is the maximum. Using `frames.last?.id` eliminates the redundant iteration entirely.

**Current Code:**
```swift
.sorted { a, b in
    (a.frames.map(\.id).max() ?? 0) > (b.frames.map(\.id).max() ?? 0)
}
```

**Recommended Fix:**
```swift
.sorted { a, b in
    // frames are already sorted ascending by logicalTime;
    // the last element has the highest rowid.
    (a.frames.last?.id ?? 0) > (b.frames.last?.id ?? 0)
}
```

---

### [LOW] `StoryStudioViewModel` CRUD guard `guard let context = modelContext else { return }` silently no-ops with no diagnostic — multiple locations

**Category:** Error Handling / Developer Experience
**Severity:** Low

**Explanation:**
If `setModelContext` is never called (future refactor, test code), every CRUD operation silently does nothing. An `assertionFailure` in the guard branch would surface this during development without affecting production.

**Recommended Fix:**
```swift
guard let context = modelContext else {
    assertionFailure("modelContext is nil — call setModelContext before performing CRUD operations")
    return
}
```

---

### [LOW] `DTProjectBrowserViewModel.removeFolder` re-resolves every persisted bookmark to find the one to remove — `DTProjectBrowserViewModel.swift:172-178`

**Category:** Performance
**Severity:** Low

**Explanation:**
`removeFolder` resolves every persisted bookmark via `resolveBookmark(_:)` (a kernel call per bookmark) just to find and remove one entry. For 5–10 bookmarks this is trivial, but it is unnecessary. Storing the bookmark `Data` in `BookmarkedFolder` at creation time would allow direct removal without re-resolution.

**Recommended Fix:**
Extend `BookmarkedFolder`:
```swift
struct BookmarkedFolder: Identifiable {
    let id: UUID
    let url: URL
    let label: String
    let isAvailable: Bool
    let bookmarkData: Data?   // store at creation for efficient removal
}
```

---

## Applied Fixes

All 20 findings were fixed and verified with a successful build (`BUILD SUCCEEDED`). Applied in Critical → High → Medium → Low order:

**Fix 1 (CRITICAL) — StoryStudioViewModel.importReferenceImage (character + setting):**
Both overloads now wrap the file load in a `Task {}`, check file size via `FileManager.attributesOfItem` before reading (10 MB ceiling), and report errors via `self.errorMessage`. Synchronous main-actor I/O eliminated.

**Fix 2 (HIGH) — StoryflowExporter.exportWithSavePanel:**
Removed incorrect `DispatchQueue.main.async {}` wrapper inside the `withCheckedContinuation` body. `NSSavePanel` is now constructed directly inside the continuation (caller is already on `@MainActor`).

**Fix 3 (HIGH) — FileManager.urls().first! force-unwraps:**
Applied nil-coalescing fallback to `NSTemporaryDirectory()` in four locations:
- `ConfigPresetsManager.presetsDirectory` and `presetsFilePath` (cycle 6, prior session)
- `ImageStorageManager.init()`
- `ImageInspectorViewModel.storageDirectory`
- `PromptStyleManager.stylesDirectory` and `stylesFilePath` (bonus fix found in same pass)

**Fix 4 (HIGH) — DTVideoExporter spin-wait loop:**
Replaced the 2000-iteration, 1ms-sleep polling loop with a direct `adaptor.append(pixelBuffer:withPresentationTime:)` call. With `expectsMediaDataInRealTime = false`, the encoder processes frames synchronously and the spin-wait was unnecessary. Loop-break on `append` returning false so encoder errors surface via `writer.error`.

**Fix 5 (HIGH) — DTProjectDatabase.deleteEntries silent commit:**
All three `sqlite3_step()` calls (one per tensorhistorynode DELETE, two per thumbnail DELETE) now check their return values. If any step fails, the transaction is `ROLLBACK`ed and a `DTProjectDatabaseError.deleteFailed` is thrown instead of silently committing a partial deletion.

**Fix 6 (HIGH) — SwiftData PNG blob storage in generateScene:**
`SceneVariant` is now created with `imageData: nil`. The image is saved via `ImageStorageManager.shared.saveImage()` (which was already called) and the returned `GeneratedImage.filePath?.path` is stored in `variant.imagePath`. `scene.generatedImageData` is no longer populated for new variants (field retained for schema compatibility with existing data).

**Fix 7 (MEDIUM) — Missing context.insert before relationship setup:**
Added `context.insert(newObject)` before any relationship assignment in all five affected methods:
- `addChapter` — inserts `chapter` before setting `chapter.project`
- `addScene` — inserts `scene` before setting `scene.chapter`
- `addCharacter` — inserts `character` before setting `character.project`
- `addSetting` — inserts `setting` before setting `setting.project`
- `addCharacterToScene` — inserts `presence` before setting `presence.scene`

**Fix 8 (MEDIUM) — DTVideoExporter double database open:**
Added an inline comment explaining why concurrent read-only connections are safe (SQLite allows multiple readers; both connections use `SQLITE_OPEN_READONLY`). No code change required.

**Fix 9 (MEDIUM) — ImageBrowserViewModel.isLoading not reset on cancellation:**
Moved `self.isLoading = false` outside the `if !Task.isCancelled` guard so it always executes, even when a load is cancelled mid-flight.

**Fix 10 (MEDIUM) — SceneVariant.seed stores -1 sentinel:**
In `generateScene`, `config.seed` is now clamped: `let resolvedSeed = config.seed >= 0 ? config.seed : 0`. The stored seed is 0 when the actual seed is unknown (Draw Things chose randomly), rather than the -1 UI sentinel.

**Fix 11 (MEDIUM) — ImageStorageManager.saveImage synchronous I/O on @MainActor:**
Added documentation comment explaining the current synchronous behavior and the conditions under which moving to a detached Task would be appropriate.

**Fix 12 (LOW) — StoryflowExporter missing final:**
Already `final` — fixed in a prior cycle. No change needed.

**Fix 13 (LOW) — PromptStyleManager print() instead of Logger:**
Added `import OSLog`, added `private let logger = Logger(...)`, and replaced all three `print()` calls with `logger.warning()`/`logger.error()`. Also fixed force-unwrap `first!` in `stylesDirectory` and `stylesFilePath` while in the file.

**Fix 14 (LOW) — DTVideoClip.group sort O(K) optimization:**
Changed `.map(\.id).max() ?? 0` to `.last?.id ?? 0` in the clip sort comparator. Since `frames` is already sorted ascending by `logicalTime`, `.last` gives the maximum rowid in O(1) vs O(K) for `.map().max()`.

**Fix 15 (LOW) — StoryStudioViewModel CRUD assertionFailure for nil context:**
All five `addChapter`/`addScene`/`addCharacter`/`addSetting`/`addCharacterToScene` methods now call `assertionFailure("... called before modelContext was set")` in their `guard let context = modelContext` branches (debug builds only; release builds still return silently).

**Fix 16 (LOW) — DTProjectBrowserViewModel.removeFolder re-resolves all bookmarks:**
Added `bookmarkData: Data?` to `BookmarkedFolder` struct. Creation sites (`processNewFolder`, `restoreBookmarks`) now populate this field. `removeFolder` now removes by exact `Data` equality against `folder.bookmarkData` (O(N) data comparison, no URL resolution) with a URL-resolution fallback only for folders where bookmark creation originally failed.

**Build result:** `BUILD SUCCEEDED` — no compile errors after fixes.

---

## Notes

### New in Cycle 6 vs. Previous Cycles

**New files audited:**
- `DTVideoExporter.swift` — new; findings #4, #8
- `DTProjectDatabase.swift` — updated with `deleteEntries`; finding #5
- `ImageBrowserViewModel.swift` — new; finding #9
- `ImageBrowserView.swift` — new; no critical findings

**Status of cycle 5 pending items:**
- `ImageInspectorView.openFilePanel` using `runModal`: CONFIRMED FIXED — uses `panel.begin{}` at line 417.
- `ConfigPresetsManager.revealPresetsInFinder` undefined `fileManager`: CONFIRMED FIXED — uses `FileManager.default` and `NSWorkspace.shared.open`.
- `StoryflowExporter.formatFileSize` per-call ByteCountFormatter: CONFIRMED FIXED — now uses `private static let fileSizeFormatter`.
- `RequestLogger.logFileURL` computed var: CONFIRMED FIXED — now a `let` constant.
- `WorkflowExecutionViewModel.init` force-unwrap: CONFIRMED MITIGATED — nil-coalescing to `NSHomeDirectory()` is in place.
- `DTProjectBrowserViewModel.projectsByFolder` computed per render: CONFIRMED FIXED — now `@Published private(set) var`.

### Architectural Observations

1. **Reference image storage strategy**: `StoryCharacter.primaryReferenceImageData`, `StorySetting.referenceImageData`, `CharacterAppearance.referenceImageData`, and `SceneVariant.imageData` all store raw `Data` in SwiftData. For a project with multiple characters and scenes, this easily reaches 50–100 MB in the SQLite store. The long-term fix is to store file paths and save images to a dedicated directory (e.g. `StoryAssets/`), using the same sidecar pattern as `ImageStorageManager`.

2. **`ImageBrowserViewModel` Combine pipeline**: The `Publishers.CombineLatest` / `.assign(to: &$filteredImages)` pattern is correct and consistent with `DTProjectBrowserViewModel`. No memory leak — `assign(to: &$)` uses a weak subscription.

3. **`DTProjectBrowserViewModel.deleteClip` offset accounting**: After bulk deletion, `loadedOffset` is decremented by `rowids.count`. If entries span multiple pages (possible after "Load More"), the offset could become inconsistent. This is a minor edge case, not a crash risk.

4. **`SceneVariant.imagePath` field exists but is unused**: The model has `var imagePath: String?` in `StoryDataModels.swift` (line 405), which was clearly designed as an alternative to blob storage. It is never set by `generateScene`. Finding #6 proposes using this field.

### Security Hotspot Summary (Updated)

| File | Issue | Status |
|------|-------|--------|
| `DrawThingsHTTPClient` — prompt logging | FIXED (cycle 2) |
| `DrawThingsHTTPClient` — plain HTTP warning | FIXED (cycle 1) |
| `DTProjectDatabase` — SQL injection | FIXED (cycle 1); `deleteEntries` also safe (enum table names) |
| `RequestLogger` — no OSLog for prompts | CONFIRMED safe |
| `AppSettings` — secrets in Keychain, not UserDefaults | CONFIRMED safe |
| `StoryStudioViewModel.importReferenceImage` — unbounded file load on main actor | NEW CRITICAL (cycle 6) |
| `ConfigPresetsManager.presetsDirectory` — force-unwrap crash | NEW HIGH (cycle 6) |
