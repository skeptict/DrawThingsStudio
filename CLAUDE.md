# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DrawThingsStudio is a macOS native application (Swift/SwiftUI) that serves as a visual workflow builder for AI image generation. It generates StoryFlow-compatible JSON instruction files that can be executed in Draw Things.

**Platform:** macOS 14.0+
**Architecture:** SwiftUI + SwiftData + MVVM
**Current State:** Fully functional with HTTP and gRPC connectivity to Draw Things, workflow creation, LLM-assisted prompt enhancement, cloud model catalog, image metadata inspector, direct workflow execution, and Story Studio for visual narrative creation

## Build Commands

```bash
# Build the project (requires Xcode)
xcodebuild -project DrawThingsStudio.xcodeproj -scheme DrawThingsStudio -configuration Debug build

# Build for release
xcodebuild -project DrawThingsStudio.xcodeproj -scheme DrawThingsStudio -configuration Release build
```

Open in Xcode for development: `open DrawThingsStudio.xcodeproj`

## Current Features (Working)

### Draw Things Connectivity
- **Dual Transport:** HTTP (port 7860) and gRPC (port 7859)
- **gRPC Client:** Uses [DT-gRPC-Swift-Client](https://github.com/euphoriacyberware-ai/DT-gRPC-Swift-Client) library
- **Image Generation:** Send prompts directly to Draw Things and receive generated images
- **Full Configuration:** All generation parameters (dimensions, steps, guidance, sampler, seed, model, shift, strength, LoRAs)
- **Image Gallery:** View, manage, and auto-save generated images with metadata

### Workflow Builder
- Visual instruction list with drag-and-drop reordering
- Inline editors for all instruction types (50+ types)
- JSON preview and export
- Copy to clipboard for pasting into Draw Things
- Import/export workflow JSON files
- Save workflows to library (SwiftData)

### Config Presets
- Import model configs from Draw Things JSON exports
- Searchable preset picker with type-to-filter (both Workflow Builder and Generate Image)
- Presets stored in SwiftData

### LLM Integration
- **Providers:** Ollama (port 11434), LM Studio (port 1234), Jan (port 1337)
- **Prompt Enhancement:** "Enhance" button with style picker (Creative, Artistic, Photorealistic, etc.)
- **Editable Styles:** Styles loaded from `~/Library/Application Support/DrawThingsStudio/enhance_styles.json`
- **Provider Selection:** Settings → LLM Provider (persisted in UserDefaults)

### Cloud Model Catalog
- Fetches official model list from [drawthingsai/community-models](https://github.com/drawthingsai/community-models) GitHub repo
- **Sources:** `models.txt` (curated) + `builtin.txt` (built-in) = ~400 models
- Auto-fetch on launch if cache is older than 24 hours; manual refresh available
- Cached in UserDefaults for offline use
- Combined with local Draw Things models (local shown first, no duplicates)

### Image Inspector
- Drag-and-drop PNG/JPG metadata reader
- Supports Draw Things, A1111/Forge, and ComfyUI metadata formats
- **Persistent history:** Saved to disk as PNG + JSON sidecars, restored on launch
- History persistence toggle in Settings > Interface (enabled by default)
- History timeline with hover states (max 50 entries)
- "Send to Generate" transfers metadata to Image Generation view
- Discord image URL support (downloads and inspects)

### UI Testing
- 64 XCUITest cases covering all views
- Settings reset in teardown to prevent test pollution
- Accessibility identifiers on all interactive elements

### Story Studio (Phase 1)
- **Visual Narrative System:** Create stories with consistent characters across scenes
- **Data Model:** StoryProject → StoryChapter → StoryScene, with StoryCharacter and StorySetting
- **Character Consistency:** Moodboard references, LoRA associations, prompt fragments, appearance variants
- **PromptAssembler:** Auto-composes prompts from art style + setting + characters + action + camera/mood
- **3-Column Layout:** Navigator (project tree) | Scene Editor | Preview & Generation
- **Character Editor:** Full identity, reference images, LoRA, moodboard weights, appearance variants
- **Scene Editor:** Setting picker, character presence with expression/pose/position, camera angle, mood, prompt overrides
- **Variant System:** Multiple generation attempts per scene, select best, approve scenes
- **Project Library:** Browse/manage story projects with detail panel

### Key Files
| File | Purpose |
|------|---------|
| `CloudModelCatalog.swift` | Fetches/caches cloud model catalog from GitHub |
| `DrawThingsAssetManager.swift` | Local + cloud model management, LoRA fetching |
| `DrawThingsGRPCClient.swift` | gRPC client implementing DrawThingsProvider |
| `DrawThingsHTTPClient.swift` | HTTP client for Draw Things API |
| `DrawThingsProvider.swift` | Protocol + shared types for Draw Things connectivity |
| `ImageGenerationView.swift` | Neumorphic UI for image generation |
| `ImageGenerationViewModel.swift` | State management for generation, model validation |
| `ImageInspectorView.swift` | PNG metadata inspector with drag-and-drop |
| `ImageInspectorViewModel.swift` | Inspector state, persistent history, clipboard operations |
| `ImageStorageManager.swift` | Auto-save generated images to sandboxed container |
| `AppSettings.swift` | Draw Things settings, createDrawThingsClient() factory |
| `NeumorphicStyle.swift` | Design system (colors, modifiers, hover states, components) |
| `ContentView.swift` | NavigationSplitView with neumorphic sidebar |
| `WorkflowBuilderView.swift` | Instruction list, inline editors, preset picker |
| `StoryDataModels.swift` | SwiftData models for Story Studio (Project, Character, Scene, etc.) |
| `PromptAssembler.swift` | Assembles prompts from characters + scenes + settings |
| `StoryStudioView.swift` | 3-column Story Studio main view |
| `StoryStudioViewModel.swift` | Story Studio state management |
| `CharacterEditorView.swift` | Character creation/editing with appearances |
| `SceneEditorView.swift` | Scene composition with characters, settings, camera |
| `StoryProjectLibraryView.swift` | Project browser for Library section |

## Architecture

### Core Components

| Component | File | Purpose |
|-----------|------|---------|
| App Entry | `DrawThingsStudioApp.swift` | SwiftData container, keyboard shortcuts, menu commands |
| Main Navigation | `ContentView.swift` | NavigationSplitView with sidebar (Create/Library/Settings) |
| Workflow Builder UI | `WorkflowBuilderView.swift` | Instruction list, inline editors, JSON preview |
| Workflow State | `WorkflowBuilderViewModel.swift` | Instructions array, selection, file I/O, validation |
| LLM Integration | `AIGenerationView.swift` | Provider connection UI, prompt generation |
| Settings | `AppSettings.swift` | UserDefaults-backed settings + SettingsView |

### Data Flow

```
User creates instructions in WorkflowBuilderView
    ↓
WorkflowBuilderViewModel manages state
    ↓
StoryflowInstructionGenerator converts to JSON
    ↓
StoryflowExporter outputs final JSON
    ↓
User copies to Draw Things' StoryflowPipeline.js
```

### LLM Provider Abstraction

`LLMProvider` protocol with implementations:
- `OllamaClient` - Ollama HTTP API (port 11434)
- `OpenAICompatibleClient` - LM Studio (port 1234), Jan (port 1337)

**Important:** When enhancing prompts, `WorkflowBuilderViewModel.enhancePrompt()` uses `AppSettings.shared.createLLMClient()` to get the currently selected provider.

### Persistence

- **SwiftData Models:** `SavedWorkflow`, `ModelConfig` (in `DataModels.swift`); Story Studio models in `StoryDataModels.swift`
- **Story Models:** `StoryProject`, `StoryCharacter`, `CharacterAppearance`, `StorySetting`, `StoryChapter`, `StoryScene`, `SceneCharacterPresence`, `SceneVariant`
- **User Settings:** `AppSettings.swift` (UserDefaults-backed)
- **Config Presets:** `ConfigPresetsManager.swift` (JSON file import/export)
- **Enhancement Styles:** `~/Library/Application Support/DrawThingsStudio/enhance_styles.json`
- **Generated Images:** PNG + JSON sidecars in `GeneratedImages/` (via `ImageStorageManager`)
- **Inspector History:** PNG + JSON sidecars in `InspectorHistory/` (via `ImageInspectorViewModel`, toggle in Settings)

### Instruction System

`WorkflowInstruction` wraps `InstructionType` enum with 50+ cases covering:
- Flow control: `note`, `loop`, `loopEnd`, `end`
- Prompts: `prompt`, `negativePrompt`, `config`
- Canvas: `canvasClear`, `canvasLoad`, `canvasSave`, `moveScale`, `crop`
- Moodboard: `moodboardClear`, `moodboardAdd`, `moodboardWeights`
- Advanced: `depthExtract`, `faceZoom`, `removeBackground`, `inpaintTools`

## Key Patterns

- **@MainActor ViewModels** - Thread-safe UI state management
- **@Query macros** - SwiftData queries in views
- **Focused values** - Keyboard shortcut coordination between views
- **Protocol-based LLM** - Swappable providers without UI changes
- **Singleton settings** - `AppSettings.shared` for global access

## File Organization

```
DrawThingsStudio/               # Main app target
├── *App.swift                  # Entry point
├── ContentView.swift           # NavigationSplitView (sidebar + detail views)
├── WorkflowBuilder*.swift      # Core builder (View + ViewModel)
├── ImageGeneration*.swift      # Image generation (View + ViewModel)
├── ImageInspector*.swift       # PNG metadata inspector (View + ViewModel)
├── AIGeneration*.swift         # LLM integration
├── Storyflow*.swift            # JSON export + execution pipeline
├── DrawThingsProvider.swift    # Protocol for Draw Things connectivity
├── DrawThingsHTTPClient.swift  # HTTP transport
├── DrawThingsGRPCClient.swift  # gRPC transport
├── DrawThingsAssetManager.swift # Model/LoRA fetching + cloud integration
├── CloudModelCatalog.swift     # Cloud model catalog from GitHub
├── *Client.swift               # LLM HTTP clients (Ollama, OpenAI-compatible)
├── NeumorphicStyle.swift       # Design system (colors, modifiers, hover states)
├── SearchableDropdown.swift    # Reusable dropdown components
├── ConfigPresetsManager.swift  # Model config management
├── DataModels.swift            # SwiftData models
├── AppSettings.swift           # Preferences + SettingsView
├── LLMProvider.swift           # Protocol + PromptStyleManager
├── StoryDataModels.swift       # Story Studio SwiftData models
├── PromptAssembler.swift       # Prompt assembly engine
├── StoryStudio*.swift          # Story Studio (View + ViewModel)
├── CharacterEditorView.swift   # Character creation/editing sheet
├── SceneEditorView.swift       # Scene composition editor
└── StoryProjectLibraryView.swift # Story project browser

DrawThingsStudioUITests/        # UI test suite (64 tests)
├── NavigationTests.swift
├── SettingsTests.swift
├── WorkflowBuilderTests.swift
├── GenerateImageTests.swift
├── ImageInspectorTests.swift
├── SavedWorkflowsTests.swift
├── TemplatesTests.swift
├── ConfigPresetsTests.swift
└── AIGenerationTests.swift
```

## Adding New Instructions

1. Add case to `InstructionType` enum in `WorkflowInstruction.swift`
2. Add editor component in `WorkflowBuilderView.swift`
3. Add JSON generation in `StoryflowInstructionGenerator.swift`
4. Update validation in `StoryflowValidator.swift` if needed

## Adding New LLM Providers

1. Create new class conforming to `LLMProvider` protocol
2. Implement required methods: `generateText`, `listModels`, `checkConnection`
3. Add case to `LLMProviderType` enum in `LLMProvider.swift`
4. Update provider selection UI in `AppSettings.swift`

---

## Draw Things Connectivity

### Transport Options
| Transport | Port | Library | Features |
|-----------|------|---------|----------|
| HTTP | 7860 | URLSession | Simple, works with shared secret auth |
| gRPC | 7859 | DT-gRPC-Swift-Client | TLS, binary tensors, streaming |

### gRPC Implementation (Working)
Uses [DT-gRPC-Swift-Client](https://github.com/euphoriacyberware-ai/DT-gRPC-Swift-Client) v1.2.2:
- **Dependencies:** grpc-swift 1.27.1, swift-protobuf 1.33.3, flatbuffers 25.9.23
- **TLS:** Enabled by default, handles Draw Things self-signed certs
- **Tensor Decoding:** DTTensor format with Float16 RGB data
- **Samplers:** 19 sampler types mapped from string names

### Key Files
| File | Purpose |
|------|---------|
| `DrawThingsProvider.swift` | Protocol + shared types (DrawThingsGenerationConfig, GenerationProgress) |
| `DrawThingsHTTPClient.swift` | HTTP implementation using URLSession |
| `DrawThingsGRPCClient.swift` | gRPC wrapper around DrawThingsClient |
| `ImageStorageManager.swift` | Saves images to sandboxed container (see note below) |
| `CloudModelCatalog.swift` | Fetches/caches cloud model catalog from GitHub |

### Configuration Mapping
```swift
DrawThingsGenerationConfig → DrawThingsConfiguration (gRPC)
- width/height → Int32
- sampler (string) → SamplerType enum
- loras → [LoRAConfig]
- seedMode → Int32 (0=Legacy, 1=TorchCPU, 2=ScaleAlike, 3=NvidiaTorch)
```

---

## Known Issues & Notes

### Sandboxed Storage Location
The app is sandboxed. All file-based storage is under the container:
```
~/Library/Containers/tanque.org.DrawThingsStudio/Data/Library/Application Support/DrawThingsStudio/
├── GeneratedImages/    # Generated image PNGs + JSON metadata sidecars
├── InspectorHistory/   # Persisted inspector history PNGs + JSON sidecars
└── enhance_styles.json # Custom prompt enhancement styles
```
NOT at `~/Library/Application Support/DrawThingsStudio/`. This is expected macOS sandbox behavior.

### gRPC Model Browsing
When gRPC returns 0 models, the user needs to enable "Enable Model Browsing" in Draw Things settings. The app now shows this hint in the error message.

### Vision Models Return Empty
If using a vision-language model (e.g., `qwen3-vl`) for text-only prompt enhancement, it returns empty. The app now shows: "Model returned empty response. If using a vision model (VL), try a text-only model instead."

### Enhancement Style "Edit Styles"
Opens the JSON file in the default editor (BBEdit, TextEdit, etc.). User can add custom styles following the format in the file.

### Config Preset Model Field
Fixed: Selecting a preset now populates the Model field via `editModel = preset.modelName` in `loadFromPreset()`.

---

## Next Steps (Roadmap)

### Completed
- ~~Image Metadata Reading~~ - Image Inspector reads Draw Things, A1111, ComfyUI metadata
- ~~Cloud Model Catalog~~ - Models fetched from Draw Things GitHub repo
- ~~Direct StoryFlow Execution~~ - Run workflows directly via Draw Things API
- ~~Story Studio Phase 1~~ - Projects, characters, settings, scenes, prompt assembly, generation, variants

### Story Studio Phase 2: Narrative Structure + Batch Generation
- Chapters with reordering, generate entire chapters with one click, progress tracking

### Story Studio Phase 3: Character Appearances + Development
- Multiple appearances per character timeline, appearance-specific reference generation

### Story Studio Phase 4: LLM-Assisted Story Development
- Story outline generation, character sheet generation, dialogue writing, prompt optimization

### Story Studio Phase 5: Export Formats
- Comic page renderer, storyboard renderer, PDF export, image sequence export

### Other Phases
1. **Image Evaluation via LLM** - Connect vision-capable LLMs (LLaVA, Qwen-VL) via Ollama for quality assessment
2. **Conditional Logic** - If/else branching based on image analysis
3. **Batch Processing** - Queue multiple workflows, parameter sweeps
4. **Shortcuts Integration** - Expose workflows to macOS Shortcuts

---

## Direct StoryFlow Execution

### Overview
Direct execution allows running StoryFlow workflows without exporting to Draw Things scripts. The executor translates instructions to Draw Things API calls where possible.

### Supported Instructions

**Fully Supported:**
| Instruction | Behavior |
|-------------|----------|
| `note` | Skipped (no-op) |
| `loop`, `loopEnd` | Client-side iteration |
| `end` | Stops execution |
| `prompt`, `negativePrompt` | Sets generation parameters |
| `config` | Merges with current config |
| `frames` | Sets frame count |
| `canvasLoad` | Loads image from Pictures folder |
| `canvasSave` | Triggers generation and saves result |
| `loopLoad`, `loopSave` | Iterates over folder files |

**Partially Supported:**
| Instruction | Limitation |
|-------------|------------|
| `maskLoad` | Loads mask but requires generation trigger |
| `moodboardAdd` | Tracks image but API doesn't use moodboard |
| `inpaintTools` | Only strength setting applied |

**Not Supported (Skipped):**
- Canvas manipulation: `canvasClear`, `moveScale`, `adaptSize`, `crop`
- Moodboard operations: All moodboard instructions
- Mask operations: `maskClear`, `maskGet`, `maskBackground`, `maskForeground`, `maskBody`, `maskAsk`
- Depth/Pose: All depth and pose instructions
- AI features: `removeBackground`, `faceZoom`, `askZoom`, `xlMagic`

### Key Files
| File | Purpose |
|------|---------|
| `StoryflowExecutor.swift` | Core execution engine with state management |
| `WorkflowExecutionViewModel.swift` | ViewModel for execution UI |
| `WorkflowExecutionView.swift` | Execution progress UI |

### Execution Flow
```
Instructions → StoryflowExecutor
                    ↓
              ExecutionState (canvas, mask, config, prompt)
                    ↓
              canvasSave triggers generation
                    ↓
              DrawThingsProvider (HTTP/gRPC)
                    ↓
              Generated images saved to working directory
```

---

## Session History Summary

### Session 1
- Fixed config preset model field population
- Added searchable config preset dropdown
- Fixed LLM provider selection (was hardcoded to Ollama)
- Added editable enhancement styles with PromptStyleManager
- Added empty response handling for vision models
- Created README.md

### Session 2 (Jan 21, 2026)
- Attempted manual gRPC setup - hit Swift 6 concurrency issues
- Reverted to last working commit

### Session 3 (Jan 24-26, 2026)
- Implemented HTTP connectivity to Draw Things (port 7860)
- Created DrawThingsHTTPClient, ImageStorageManager, ImageGenerationView/ViewModel
- Added Image Generation UI with gallery

### Session 4 (Jan 26, 2026)
- Applied neumorphic design system across entire app
- Created NeumorphicStyle.swift with colors, modifiers, components
- Updated all views with warm beige theme

### Session 5 (Jan 26, 2026)
- **Successfully integrated gRPC** using DT-gRPC-Swift-Client library
- Added package dependency via SPM
- Created DrawThingsGRPCClient.swift wrapper
- Both HTTP and gRPC transports now working
- Updated README.md with comprehensive features and roadmap

### Session 6 (Jan 27, 2026)
- **Implemented Direct StoryFlow Execution**
- Created `StoryflowExecutor.swift` - Core execution engine with state management
- Created `WorkflowExecutionViewModel.swift` - ViewModel for execution tracking
- Created `WorkflowExecutionView.swift` - Execution UI with progress and generated images
- Added "Execute" button to WorkflowBuilderView toolbar
- Analyzed Draw Things API capabilities (HTTP and gRPC)
- Documented supported/unsupported instructions for direct execution

### Session 7 (Feb 7-8, 2026)
- **QA & Testing:** Created 64 XCUITest cases covering all views
- **Bug Fixes:** Model validation, settings reset in test teardown
- **Image Persistence:** Verified working in sandboxed container path
- **UX Polish:** Applied NeumorphicIconButtonStyle to all toolbar icon buttons
- **Cloud Model Catalog:** Fetches ~400 models from Draw Things GitHub repo
- **App Icon:** Added puppy-with-palette icon at all macOS sizes
- **UI Improvements:** Save Canvas path clarity, gRPC "Enable Model Browsing" hint

### Session 8 (Feb 8, 2026)
- **Searchable Config Preset Dropdown:** Replaced standard Picker in Generate Image with searchable neumorphic dropdown matching model/sampler style
- **Persistent Inspector History:** Inspector history now survives app restarts via PNG + JSON sidecar files in `InspectorHistory/` directory
- **Persistence Toggle:** Added "Persist Inspector history" toggle in Settings > Interface (enabled by default)

### Session 9 (Feb 10, 2026)
- **Story Studio Phase 1:** Complete visual narrative system
- Created `StoryDataModels.swift` — 8 SwiftData models: StoryProject, StoryCharacter, CharacterAppearance, StorySetting, StoryChapter, StoryScene, SceneCharacterPresence, SceneVariant
- Created `PromptAssembler.swift` — Assembles prompts from art style + setting + characters + action + camera/mood; collects moodboard refs and LoRAs
- Created `StoryStudioView.swift` — 3-column layout (Navigator | Scene Editor | Preview & Generation) with project picker
- Created `StoryStudioViewModel.swift` — Full state management: project/chapter/scene CRUD, character/setting management, prompt assembly, generation, variant management
- Created `CharacterEditorView.swift` — Character identity, reference images, LoRA/moodboard consistency tools, appearance variants
- Created `SceneEditorView.swift` — Setting picker, character presence with expression/pose/position, camera angles, mood, prompt overrides, config overrides
- Created `StoryProjectLibraryView.swift` — Project browser with detail panel showing stats, chapters, generation defaults
- Integrated into `ContentView.swift` (new sidebar items: Story Studio, Story Projects) and `DrawThingsStudioApp.swift` (registered 8 new SwiftData models)
