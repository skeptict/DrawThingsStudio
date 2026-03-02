# DrawThingsStudio Code Audit Report

**Last Run:** 2026-03-02T00:00:00Z
**App Version:** 0.4.29 (bumped to 0.4.30 by this audit)
**Scope:** Full Project — all 53 Swift files in `DrawThingsStudio/` target
**Auditor:** Claude code-quality-auditor agent (cycle 8)

---

## Summary
- Critical Security Issues: 0
- High Priority: 3
- Medium Priority: 0
- Low Priority: 0

All prior cycles (1–7) findings are confirmed resolved. No security issues were found. Three logic bugs were identified in this cycle, all fixed.

---

## Findings

### [HIGH] SceneVariant not inserted into ModelContext before relationship assignment — `StoryStudioViewModel.swift:387`

**Category:** Best Practice / SwiftData
**Severity:** High

**Explanation:**
In `generateScene()`, a new `SceneVariant` object is constructed and immediately has its `scene` relationship set and appended to `scene.variants` — but it is never inserted into the `ModelContext` first. On macOS 14 (the minimum deployment target), SwiftData 1.0 requires that every `@Model` object be registered with a `ModelContext` before its inverse relationships are established. Setting a relationship on an unmanaged object crashes with `EXC_BAD_INSTRUCTION`. This is the same class of bug that was fixed in cycle 6 for `addChapter`, `addScene`, `addCharacter`, `addSetting`, and `addCharacterToScene` — those paths all received `context.insert()` calls and have clear comments explaining why. The `generateScene` path was missed.

**Current Code:**
```swift
let variant = SceneVariant(
    prompt: finalPrompt,
    negativePrompt: assembled.negativePrompt,
    seed: resolvedSeed,
    imageData: nil,
    imagePath: savedImage?.filePath?.path,
    isSelected: scene.variants.isEmpty
)
variant.scene = scene           // BUG: variant not in context
scene.variants.append(variant)  // BUG: setting relationship on unmanaged object
```

**Improved Code:**
```swift
let variant = SceneVariant(
    prompt: finalPrompt,
    negativePrompt: assembled.negativePrompt,
    seed: resolvedSeed,
    imageData: nil,
    imagePath: savedImage?.filePath?.path,
    isSelected: scene.variants.isEmpty
)
// Insert into context before establishing any relationships.
// SwiftData 1.0 (macOS 14) crashes with EXC_BAD_INSTRUCTION if you set
// inverse relationships between objects not yet managed by a ModelContext.
modelContext?.insert(variant)
variant.scene = scene
scene.variants.append(variant)
```

---

### [HIGH] Delete functions remove objects from relationship arrays but do not call context.delete() — `StoryStudioViewModel.swift:128,156,192,225,258,449`

**Category:** Best Practice / SwiftData
**Severity:** High

**Explanation:**
Six delete functions remove `@Model` objects from their parent relationship arrays (`project.chapters.removeAll`, `scene.variants.removeAll`, etc.) without calling `modelContext.delete()`. In SwiftData, removing an object from a relationship array only nullifies its inverse reference — it does not delete the object from the persistent SQLite store. The objects become orphans: invisible in the UI (since they are no longer reachable through any relationship) but permanently accumulating in the database.

Over time, repeatedly creating and deleting chapters, scenes, characters, settings, presences, and variants will cause unbounded growth of the SQLite store. More importantly, the `deleteProject` function already uses `context.delete(project)` correctly, relying on cascade rules to clean up child objects. But the cascade only fires when the *parent* is explicitly deleted — not when children are removed from an array. The subsidiary delete functions bypass this entirely.

Functions affected: `deleteChapter`, `deleteScene`, `deleteCharacter`, `deleteSetting`, `removeCharacterFromScene`, `deleteVariant`.

Note on `deleteCharacter`: `SceneCharacterPresence` objects reference their character via a plain `UUID` field (not a SwiftData `@Relationship`), so there is no cascade path from `StoryCharacter` to its presences. The presences must be explicitly deleted before the character is removed.

**Current Code (deleteChapter, representative):**
```swift
func deleteChapter(_ chapter: StoryChapter) {
    guard let project = selectedProject else { return }
    if selectedChapter?.id == chapter.id {
        selectedChapter = nil
        selectedScene = nil
    }
    project.chapters.removeAll { $0.id == chapter.id }
    project.modifiedAt = Date()
    // Missing: context.delete(chapter)
}
```

**Improved Code (deleteChapter):**
```swift
func deleteChapter(_ chapter: StoryChapter) {
    guard let context = modelContext, let project = selectedProject else { return }
    if selectedChapter?.id == chapter.id {
        selectedChapter = nil
        selectedScene = nil
    }
    project.chapters.removeAll { $0.id == chapter.id }
    project.modifiedAt = Date()
    // Cascade delete rule on StoryProject.chapters will also delete all
    // scenes, presences, and variants nested under this chapter.
    context.delete(chapter)
}
```

---

### [HIGH] `loadBatchFolderTemplate()` and `loadVideoFramesTemplate()` are missing the `loop` instruction — `WorkflowBuilderViewModel.swift:481,497`

**Category:** Logic Error
**Severity:** High

**Explanation:**
Both workflow templates include `loopLoad`, `loopSave`, and `loopEnd` instructions without a preceding `loop` instruction. `StoryflowExecutor.loopLoadFile()` and `handleLoopSave()` both begin with `guard let loop = state.loopStack.last else { return .failed(..., error: "loopLoad must be inside a loop") }`. Similarly, `handleLoopEnd` fails if the loop stack is empty. The generated workflows will always fail at the first `loopLoad` instruction when executed.

By contrast, `loadBatchVariationTemplate()` (the only other loop template) correctly inserts `.loop(count: count, start: 0)` before its loop body. The batch folder and video frames templates were written without this instruction, making them non-functional.

**Current Code (loadBatchFolderTemplate):**
```swift
addInstruction(.note("Batch folder processing - processes all images in a folder"))
addInstruction(.config(config))
addInstruction(.loopLoad("Input_Img"))     // loopLoad without a loop — always fails
addInstruction(.prompt("Enhancement prompt applied to each image"))
addInstruction(.loopSave("output_"))
addInstruction(.loopEnd)
```

**Improved Code (loadBatchFolderTemplate):**
```swift
addInstruction(.note("Batch folder processing - processes all images in a folder"))
addInstruction(.config(config))
addInstruction(.loop(count: 10, start: 0)) // loop must precede loopLoad
addInstruction(.loopLoad("Input_Img"))
addInstruction(.prompt("Enhancement prompt applied to each image"))
addInstruction(.loopSave("output_"))
addInstruction(.loopEnd)
```

**Current Code (loadVideoFramesTemplate):**
```swift
addInstruction(.config(config))
addInstruction(.loopLoad("frames"))        // loopLoad without a loop — always fails
addInstruction(.prompt("Stylization prompt for video frames"))
addInstruction(.frames(24))
addInstruction(.loopSave("styled_frame_"))
addInstruction(.loopEnd)
```

**Improved Code (loadVideoFramesTemplate):**
```swift
addInstruction(.config(config))
addInstruction(.loop(count: 24, start: 0)) // loop must precede loopLoad
addInstruction(.loopLoad("frames"))
addInstruction(.prompt("Stylization prompt for video frames"))
addInstruction(.frames(24))
addInstruction(.loopSave("styled_frame_"))
addInstruction(.loopEnd)
```

---

## Applied Fixes

1. **`StoryStudioViewModel.swift`** — Added `modelContext?.insert(variant)` before `variant.scene = scene` in `generateScene()`.
2. **`StoryStudioViewModel.swift`** — Added `context.delete()` calls to `deleteChapter`, `deleteScene`, `deleteSetting`, `deleteVariant`. Added explicit presence deletion loop + `context.delete(character)` to `deleteCharacter`. Added `context.delete(presence)` to `removeCharacterFromScene`. Updated all guards to also require `modelContext`.
3. **`WorkflowBuilderViewModel.swift`** — Added `.loop(count: 10, start: 0)` before `loopLoad` in `loadBatchFolderTemplate()`. Added `.loop(count: 24, start: 0)` before `loopLoad` in `loadVideoFramesTemplate()`.
4. **`DrawThingsStudio.xcodeproj/project.pbxproj`** — Bumped `MARKETING_VERSION` from `0.4.29` to `0.4.30` across all four build configuration targets.

## Notes

- All cycles 1–7 findings remain resolved. The full audit of 53 files found no security issues, no performance regressions, and no new Swift concurrency violations.
- The recurring "insert before relationship" pattern for SwiftData is now complete: all creation paths (`createProject`, `addChapter`, `addScene`, `addCharacter`, `addSetting`, `addCharacterToScene`, `generateScene`) and all deletion paths now handle the `ModelContext` correctly.
- Remaining known architectural deferral: `StoryScene.generatedImageData`, `StoryCharacter.primaryReferenceImageData`, `StorySetting.referenceImageData`, and `CharacterAppearance.referenceImageData` still store image data as SwiftData blobs rather than file paths. This is tracked as future work (Story Studio Phase 2+).
