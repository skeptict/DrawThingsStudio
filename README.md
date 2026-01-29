# Draw Things Studio

A native macOS companion app for [Draw Things](https://drawthings.ai), providing a visual workflow builder for StoryFlow scripts, direct image generation, and AI-assisted prompt enhancement.

## Features

### StoryFlow Workflow Builder

Build complex Draw Things automation workflows with a visual drag-and-drop interface:

- **Flow Control**: Loops, loop endings, notes, and end markers for structured workflows
- **Prompt Management**: Prompt and negative prompt instructions with AI enhancement
- **Configuration**: Full Draw Things config support (dimensions, steps, guidance, sampler, model, shift, strength)
- **Canvas Operations**: Clear, load, save, move/scale, adapt size, and crop
- **Moodboard**: Add/remove images, clear, transfer canvas, set weights per slot
- **Mask Operations**: Load, clear, extract, background/foreground isolation, body segmentation, AI-driven mask generation
- **Depth & Pose**: Extract depth maps, pose estimation, and transfer operations
- **Advanced Tools**: Background removal, face zoom, AI zoom, inpaint tools, XL magic

#### Workflow Management

- **Validation**: Real-time syntax validation with error and warning detection
- **Export**: Save workflows as JSON files compatible with StoryFlow scripts
- **Library**: Save and organize workflows with favorites and categories
- **Templates**: Built-in workflow templates for common use cases
- **Copy/Paste**: Copy workflow JSON directly to clipboard

#### Direct Workflow Execution

Execute workflows directly from the app without exporting to Draw Things:

- **Execute Button**: Run workflows directly via Draw Things API
- **Progress Tracking**: Real-time execution log showing each instruction
- **Support Analysis**: Shows which instructions are fully supported, partially supported, or will be skipped
- **Generated Images**: View all images generated during execution
- **Working Directory**: Configure output folder for saved images
- **Cancel Support**: Stop execution at any time

### Image Generation

Generate images directly from Draw Things Studio via HTTP or gRPC:

- **Dual Transport**: Connect via HTTP (port 7860) or gRPC (port 7859)
- **gRPC Benefits**: Native binary protocol with TLS, streaming progress, efficient tensor transfer
- **Full Configuration**: All generation parameters (dimensions, steps, guidance, sampler, seed, model, shift, strength, LoRAs)
- **Preset System**: Load configuration presets from saved ModelConfigs
- **Progress Tracking**: Real-time progress indicator during generation
- **Image Gallery**: View generated images with thumbnails and detail view
- **Image Management**: Copy to clipboard, reveal in Finder, delete
- **Auto-Save**: Generated images saved to `~/Library/Application Support/DrawThingsStudio/GeneratedImages/` with JSON metadata sidecars

### AI-Assisted Features

Connect to local LLM providers for intelligent assistance:

- **Supported Providers**: Ollama, LM Studio, Jan
- **Prompt Enhancement**: AI-powered prompt improvement with customizable styles
- **Workflow Generation**: Generate StoryFlow instructions from natural language descriptions
- **Model Selection**: Browse and select from available models on connected providers

### Configuration Presets

Pre-configured settings for popular models:

- **SDXL**: Standard, Portrait, Landscape orientations
- **SD 1.5**: Standard, Portrait, Landscape orientations
- **Flux**: Dev (28 steps) and Schnell (4 steps) configurations
- **Pony/Anime**: Optimized settings with CLIP skip
- **Img2Img**: Light, Medium, Strong strength presets
- **Custom**: Create and save your own presets

### User Interface

- **Neumorphic Design**: Modern soft-UI with warm beige tones, raised cards, and subtle shadows
- **Split View Layout**: Instruction list on left, editor on right
- **Sidebar Navigation**: Quick access to Workflow Builder, Image Generation, Library, Templates, and Settings
- **Keyboard Shortcuts**: Cmd+Return to generate, standard editing shortcuts

## Requirements

- macOS 14.0 or later
- [Draw Things](https://apps.apple.com/app/draw-things-ai-generation/id6444050820) with API Server enabled (Settings → API Server → Enable)
- Optional: [Ollama](https://ollama.ai), [LM Studio](https://lmstudio.ai), or [Jan](https://jan.ai) for AI features

## Getting Started

1. **Install Draw Things** from the Mac App Store
2. **Enable the API Server** in Draw Things: Settings → API Server → Enable (default port 7860)
3. **Launch Draw Things Studio**
4. **Configure Connection** in Settings → Draw Things Connection
5. **Test Connection** to verify connectivity

### For AI Features (Optional)

1. Install Ollama, LM Studio, or Jan
2. Configure the provider settings in Draw Things Studio
3. Test the connection
4. Use AI Generation in the Workflow Builder or enhance prompts

## Architecture

```
DrawThingsStudio/
├── App & Navigation
│   ├── DrawThingsStudioApp.swift    # App entry point
│   ├── ContentView.swift            # Main navigation structure
│   └── AppSettings.swift            # Settings persistence
│
├── Workflow Builder
│   ├── WorkflowBuilderView.swift    # Main workflow UI
│   ├── WorkflowBuilderViewModel.swift
│   ├── WorkflowInstruction.swift    # Instruction model
│   └── JSONPreviewView.swift        # JSON preview sheet
│
├── StoryFlow Export & Execution
│   ├── StoryflowInstructions.swift  # Instruction type definitions
│   ├── StoryflowExporter.swift      # JSON export
│   ├── StoryflowValidator.swift     # Validation logic
│   ├── StoryflowInstructionGenerator.swift
│   ├── StoryflowExecutor.swift      # Direct execution engine
│   ├── WorkflowExecutionView.swift  # Execution UI
│   └── WorkflowExecutionViewModel.swift
│
├── Image Generation
│   ├── ImageGenerationView.swift    # Generation UI
│   ├── ImageGenerationViewModel.swift
│   ├── DrawThingsProvider.swift     # Provider protocol
│   ├── DrawThingsHTTPClient.swift   # HTTP API client
│   ├── DrawThingsGRPCClient.swift   # gRPC client (via DT-gRPC-Swift-Client)
│   └── ImageStorageManager.swift    # Image persistence
│
├── AI Integration
│   ├── AIGenerationView.swift       # AI generation UI
│   ├── LLMProvider.swift            # Provider protocol
│   ├── OllamaClient.swift           # Ollama implementation
│   ├── OpenAICompatibleClient.swift # LM Studio/Jan
│   └── WorkflowPromptGenerator.swift
│
├── Data & Persistence
│   ├── DataModels.swift             # SwiftData models
│   └── ConfigPresetsManager.swift   # Preset management
│
└── UI Components
    └── NeumorphicStyle.swift        # Design system
```

## Roadmap

### Phase 1: Enhanced Draw Things Connectivity

- [x] **gRPC Client Implementation** ✓
  - Native gRPC connection to Draw Things (port 7859)
  - TLS certificate handling for secure connection
  - Binary tensor decoding for image responses
  - Full configuration support (19 samplers, LoRAs, seed modes)
  - Uses [DT-gRPC-Swift-Client](https://github.com/euphoriacyberware-ai/DT-gRPC-Swift-Client) library

- [x] **Direct StoryFlow Execution** ✓
  - Execute workflows directly from the app via Draw Things API
  - Real-time execution progress with step-by-step logging
  - Cancel running workflows
  - Generated images displayed in execution panel
  - **Note:** Some instructions (canvas manipulation, moodboard, AI features) require Draw Things internal state and are skipped during direct execution

### Phase 2: Intelligent Image Analysis

- [ ] **Image Evaluation via LLM**
  - Connect vision-capable LLMs (LLaVA, Qwen-VL, etc.) via Ollama
  - Automatic quality assessment of generated images
  - Prompt adherence scoring
  - Suggestions for prompt improvements based on results
  - Batch evaluation for comparing multiple generations

- [ ] **Image Metadata Reading**
  - Extract and display embedded generation metadata from images
  - Support for Draw Things, Automatic1111, ComfyUI metadata formats
  - Import settings from existing images
  - Metadata search and filtering in gallery

### Phase 3: Advanced Workflow Features

- [ ] **Conditional Logic**
  - If/else branching based on image analysis results
  - Dynamic prompt modification based on intermediate outputs
  - Automatic retry with adjusted parameters on failure

- [ ] **Batch Processing**
  - Queue multiple workflows for sequential execution
  - Parameter sweeps (vary seeds, guidance, etc.)
  - Organized output folders per batch

- [ ] **Workflow Sharing**
  - Export workflows as shareable packages
  - Import community workflows
  - Version control for workflow iterations

### Phase 4: Integration & Automation

- [ ] **Shortcuts Integration**
  - Expose workflows to macOS Shortcuts
  - Trigger generation from external apps
  - Automation recipes

- [ ] **Watch Folders**
  - Monitor folders for new input images
  - Automatic processing with configured workflows
  - Output organization

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

[MIT License](LICENSE)

## Acknowledgments

- [Draw Things](https://drawthings.ai) by Liu Liu for the excellent image generation app
- [StoryFlow Editor](https://cutsceneartist.com/DrawThings/StoryflowEditor_online.html) - the original web-based StoryFlow workflow editor that inspired this project
