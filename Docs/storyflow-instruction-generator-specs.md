# Technical Specifications: StoryFlow Instruction Generator
**Target Platform:** macOS native Swift app  
**Output Format:** StoryFlow-compatible JSON instruction files

---

## EXECUTIVE SUMMARY

Your app generates **JSON instruction files** that the **StoryflowPipeline.js** script (already exists) executes in Draw Things. This is a clean two-app architecture:

**App 1: Your Swift App** (what you're building)
- Connects to Ollama to generate/iterate prompts
- Generates StoryFlow JSON instruction files
- Provides UI for workflow design
- Can also send direct gRPC commands (optional)

**App 2: StoryflowPipeline.js** (already exists)
- Loaded into Draw Things (once)
- User pastes your JSON into it
- Parses and executes instructions

**Advantages of this approach:**
- No need to implement all Draw Things features
- Users have full control (can edit JSON)
- Leverages existing, battle-tested pipeline
- Clean separation: your app = instruction generator, Pipeline = executor

---

## 1. STORYFLOW JSON FORMAT

### 1.1 Structure

```json
[
  { "instructionKey": value },
  { "instructionKey": value },
  ...
]
```

Each instruction is an object with **exactly one key-value pair**.

### 1.2 Available Instructions

Based on StoryflowPipeline_251207.js validation rules (lines 60-101):

#### **Flow Control**
```json
{ "note": "Comment text - pipeline ignores this" }
{ "loop": { "loop": 5, "start": 0 } }  // loop count & optional start index
{ "loopEnd": true }
{ "end": true }
```

#### **Prompts & Config**
```json
{ "prompt": "Your prompt text here" }
{ "negPrompt": "blur, low quality" }
{ "config": { 
    "width": 1024, 
    "height": 1024, 
    "steps": 30,
    "guidanceScale": 7.5,
    "seed": 42,
    "model": "flux_1_dev_q8p.ckpt"
  }
}
{ "frames": 24 }  // for video generation
```

#### **Canvas Operations**
```json
{ "canvasClear": true }
{ "canvasLoad": "input.png" }  // from Pictures folder
{ "canvasSave": "output.png" }  // to Pictures folder
{ "moveScale": { "position_X": 0, "position_Y": 0, "canvas_scale": 1.0 } }
{ "adaptSize": { "maxWidth": 2048, "maxHeight": 2048 } }
{ "crop": true }
```

#### **Moodboard Operations**
```json
{ "moodboardClear": true }
{ "moodboardCanvas": true }  // copy visible canvas to moodboard
{ "moodboardAdd": "reference.png" }
{ "moodboardRemove": 0 }  // remove at index
{ "moodboardWeights": { 
    "index_0": 1.0, 
    "index_1": 0.8, 
    "index_2": 0.6 
  }
}
{ "loopAddMB": "folder_name" }  // incrementally add from folder (use in loop)
```

#### **Mask Operations**
```json
{ "maskClear": true }
{ "maskLoad": "mask.png" }
{ "maskGet": true }  // copy mask to canvas
{ "maskBkgd": true }  // detect and mask background
{ "maskFG": true }  // detect and mask foreground
{ "maskBody": { "upper": true, "lower": true, "clothes": true, "neck": 10 } }
{ "maskAsk": "the person's face" }  // AI-detected mask
```

#### **Depth & Pose**
```json
{ "depthExtract": true }
{ "depthCanvas": true }  // copy canvas to depth layer
{ "depthToCanvas": true }  // copy depth to canvas
{ "poseExtract": true }
{ "poseJSON": { /* OpenPose JSON object */ } }
```

#### **Advanced Tools**
```json
{ "removeBkgd": true }
{ "faceZoom": true }  // auto-zoom to detected face
{ "askZoom": "the building" }  // AI-detected zoom
{ "inpaintTools": { 
    "strength": 0.7, 
    "maskBlur": 4, 
    "maskBlurOutset": 0,
    "restoreOriginalAfterInpaint": false 
  }
}
{ "xlMagic": { "original": 1, "target": 1, "negative": 1 } }  // SDXL latent tuning
```

#### **Loop-specific**
```json
{ "loopLoad": "folder_name" }  // incrementally load from folder
{ "loopSave": "output_" }  // saves as output_0.png, output_1.png, etc.
```

### 1.3 File Path Rules

- All file paths are **relative to Pictures folder**
- Supported extensions: `.png`, `.jpg`, `.webp`
- For `canvasLoad`, `moodboardAdd`, `maskLoad`: must include extension
- For `canvasSave`, `loopSave`: must end with `.png`
- For `loopLoad`, `loopAddMB`: folder name (no extension)

**Examples:**
```json
{ "canvasLoad": "inputs/base.png" }
{ "canvasSave": "outputs/result.png" }
{ "loopLoad": "sequence_frames" }
{ "loopSave": "frame_" }  // becomes frame_0.png, frame_1.png, etc.
```

---

## 2. SWIFT IMPLEMENTATION

### 2.1 Instruction Models

```swift
// Base protocol
protocol StoryflowInstruction: Codable {
    var instructionDict: [String: Any] { get }
}

// Concrete instruction types
struct NoteInstruction: StoryflowInstruction {
    let note: String
    
    var instructionDict: [String: Any] {
        ["note": note]
    }
}

struct PromptInstruction: StoryflowInstruction {
    let prompt: String
    
    var instructionDict: [String: Any] {
        ["prompt": prompt]
    }
}

struct ConfigInstruction: StoryflowInstruction {
    let config: DrawThingsConfig
    
    var instructionDict: [String: Any] {
        ["config": config.toDictionary()]
    }
}

struct DrawThingsConfig: Codable {
    var width: Int?
    var height: Int?
    var steps: Int?
    var guidanceScale: Float?
    var seed: Int?
    var model: String?
    var samplerName: String?
    var numFrames: Int?
    // ... add other config parameters as needed
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let width = width { dict["width"] = width }
        if let height = height { dict["height"] = height }
        if let steps = steps { dict["steps"] = steps }
        if let guidanceScale = guidanceScale { dict["guidanceScale"] = guidanceScale }
        if let seed = seed { dict["seed"] = seed }
        if let model = model { dict["model"] = model }
        if let samplerName = samplerName { dict["samplerName"] = samplerName }
        if let numFrames = numFrames { dict["numFrames"] = numFrames }
        return dict
    }
}

struct CanvasSaveInstruction: StoryflowInstruction {
    let canvasSave: String  // filename.png
    
    var instructionDict: [String: Any] {
        ["canvasSave": canvasSave]
    }
}

struct LoopInstruction: StoryflowInstruction {
    let loop: LoopConfig
    
    struct LoopConfig: Codable {
        let loop: Int  // number of iterations
        let start: Int  // starting index
    }
    
    var instructionDict: [String: Any] {
        ["loop": ["loop": loop.loop, "start": loop.start]]
    }
}

struct LoopEndInstruction: StoryflowInstruction {
    var instructionDict: [String: Any] {
        ["loopEnd": true]
    }
}

// ... add more instruction types as needed
```

### 2.2 Instruction Generator

```swift
class StoryflowInstructionGenerator {
    
    // Generate simple sequence
    func generateSimpleSequence(
        prompts: [String],
        config: DrawThingsConfig
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []
        
        // Add initial config
        instructions.append(ConfigInstruction(config: config).instructionDict)
        
        // Add each prompt with save
        for (index, prompt) in prompts.enumerated() {
            instructions.append(PromptInstruction(prompt: prompt).instructionDict)
            instructions.append(CanvasSaveInstruction(canvasSave: "scene_\(index).png").instructionDict)
        }
        
        return instructions
    }
    
    // Generate batch variations with loop
    func generateBatchVariations(
        basePrompt: String,
        variations: [String],
        config: DrawThingsConfig
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []
        
        // Setup
        instructions.append(NoteInstruction(note: "Batch variations: \(variations.count) versions").instructionDict)
        instructions.append(ConfigInstruction(config: config).instructionDict)
        
        // Loop through variations
        instructions.append(LoopInstruction(loop: .init(loop: variations.count, start: 0)).instructionDict)
        
        // In reality, you'd need to handle the variation text differently
        // This is simplified - real implementation would use indexed prompts or wildcards
        for variation in variations {
            instructions.append(PromptInstruction(prompt: "\(basePrompt), \(variation)").instructionDict)
        }
        
        instructions.append(["loopSave": "variation_"])
        instructions.append(LoopEndInstruction().instructionDict)
        
        return instructions
    }
    
    // Generate animation keyframes
    func generateAnimationSequence(
        startPrompt: String,
        endPrompt: String,
        frames: Int,
        config: DrawThingsConfig
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []
        
        instructions.append(NoteInstruction(note: "Animation: \(frames) frames").instructionDict)
        
        var animConfig = config
        animConfig.numFrames = frames
        instructions.append(ConfigInstruction(config: animConfig).instructionDict)
        
        // You would generate interpolated prompts here
        // For now, simplified example
        instructions.append(PromptInstruction(prompt: startPrompt).instructionDict)
        instructions.append(CanvasSaveInstruction(canvasSave: "animation.png").instructionDict)
        
        return instructions
    }
    
    // Story sequence with scene transitions
    func generateStorySequence(
        scenes: [(prompt: String, config: DrawThingsConfig?)],
        outputPrefix: String = "scene_"
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []
        
        instructions.append(NoteInstruction(note: "Story sequence: \(scenes.count) scenes").instructionDict)
        
        for (index, scene) in scenes.enumerated() {
            // Update config if scene has custom config
            if let sceneConfig = scene.config {
                instructions.append(ConfigInstruction(config: sceneConfig).instructionDict)
            }
            
            // Generate scene
            instructions.append(PromptInstruction(prompt: scene.prompt).instructionDict)
            instructions.append(CanvasSaveInstruction(canvasSave: "\(outputPrefix)\(index + 1).png").instructionDict)
        }
        
        return instructions
    }
    
    // Complex workflow with moodboard and img2img
    func generateCharacterConsistencyWorkflow(
        characterDescription: String,
        scenes: [String],
        config: DrawThingsConfig
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []
        
        // Generate reference character image first
        instructions.append(NoteInstruction(note: "Character consistency workflow").instructionDict)
        instructions.append(ConfigInstruction(config: config).instructionDict)
        instructions.append(PromptInstruction(prompt: characterDescription).instructionDict)
        instructions.append(CanvasSaveInstruction(canvasSave: "character_ref.png").instructionDict)
        
        // Add to moodboard
        instructions.append(["moodboardClear": true])
        instructions.append(["moodboardCanvas": true])
        
        // Generate each scene with moodboard reference
        for (index, scenePrompt) in scenes.enumerated() {
            instructions.append(PromptInstruction(prompt: "\(characterDescription), \(scenePrompt)").instructionDict)
            instructions.append(CanvasSaveInstruction(canvasSave: "scene_\(index + 1).png").instructionDict)
        }
        
        return instructions
    }
}
```

### 2.3 JSON Export

```swift
class StoryflowExporter {
    
    func exportToJSON(instructions: [[String: Any]]) throws -> String {
        let jsonData = try JSONSerialization.data(
            withJSONObject: instructions,
            options: [.prettyPrinted, .sortedKeys]
        )
        
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        return jsonString
    }
    
    func exportToFile(instructions: [[String: Any]], filename: String) throws -> URL {
        let jsonString = try exportToJSON(instructions: instructions)
        
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
            .appendingPathExtension("txt")
        
        try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    func copyToClipboard(instructions: [[String: Any]]) throws {
        let jsonString = try exportToJSON(instructions: instructions)
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonString, forType: .string)
    }
}

enum ExportError: Error {
    case encodingFailed
}
```

---

## 3. USER INTERFACE

### 3.1 Main Workflow Builder View

```swift
struct WorkflowBuilderView: View {
    @StateObject private var viewModel = WorkflowBuilderViewModel()
    @State private var showPreview = false
    
    var body: some View {
        HSplitView {
            // Left: Instruction list
            InstructionListView(viewModel: viewModel)
                .frame(minWidth: 300)
            
            // Right: Instruction editor
            InstructionEditorView(viewModel: viewModel)
                .frame(minWidth: 400)
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Add Prompt") {
                    viewModel.addInstruction(.prompt(""))
                }
                
                Button("Add Config") {
                    viewModel.addInstruction(.config(DrawThingsConfig()))
                }
                
                Button("Add Loop") {
                    viewModel.addInstruction(.loop(5, start: 0))
                }
                
                Divider()
                
                Button("Preview JSON") {
                    showPreview = true
                }
                
                Button("Export") {
                    viewModel.exportWorkflow()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: $showPreview) {
            JSONPreviewView(instructions: viewModel.instructions)
        }
    }
}

struct InstructionListView: View {
    @ObservedObject var viewModel: WorkflowBuilderViewModel
    
    var body: some View {
        List(selection: $viewModel.selectedInstruction) {
            ForEach(viewModel.instructions) { instruction in
                InstructionRow(instruction: instruction)
            }
            .onMove { from, to in
                viewModel.moveInstructions(from: from, to: to)
            }
            .onDelete { indexSet in
                viewModel.deleteInstructions(at: indexSet)
            }
        }
    }
}

struct InstructionRow: View {
    let instruction: WorkflowInstruction
    
    var body: some View {
        HStack {
            Image(systemName: instruction.icon)
                .foregroundColor(instruction.color)
            
            VStack(alignment: .leading) {
                Text(instruction.title)
                    .font(.headline)
                Text(instruction.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

### 3.2 JSON Preview View

```swift
struct JSONPreviewView: View {
    let instructions: [WorkflowInstruction]
    @State private var jsonString: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text("StoryFlow Instructions Preview")
                .font(.headline)
            
            Text("Copy this and paste into StoryFlow Pipeline in Draw Things")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView {
                Text(jsonString)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            HStack {
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(jsonString, forType: .string)
                }
                
                Button("Save to File") {
                    // Show save dialog
                }
                
                Button("Done") {
                    // Dismiss
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 600, height: 500)
        .onAppear {
            generateJSON()
        }
    }
    
    private func generateJSON() {
        let generator = StoryflowInstructionGenerator()
        let exporter = StoryflowExporter()
        
        // Convert WorkflowInstructions to instruction dicts
        let instructionDicts = instructions.map { $0.toInstructionDict() }
        
        jsonString = (try? exporter.exportToJSON(instructions: instructionDicts)) ?? "Error generating JSON"
    }
}
```

---

## 4. LLM INTEGRATION FOR PROMPT GENERATION

### 4.1 Generate Scene Prompts with Ollama

```swift
class WorkflowPromptGenerator {
    let ollamaClient: OllamaClient
    
    init(ollamaClient: OllamaClient) {
        self.ollamaClient = ollamaClient
    }
    
    func generateStoryScenes(
        concept: String,
        sceneCount: Int
    ) async throws -> [String] {
        let prompt = """
        Generate \(sceneCount) detailed image generation prompts for a story about: \(concept)
        
        Each prompt should:
        - Be a complete, detailed scene description
        - Work well for AI image generation
        - Progress the story forward
        - Be on a separate line
        
        Output only the prompts, one per line, no numbering or explanations.
        """
        
        let response = try await ollamaClient.generateText(
            model: "llama3.3",
            prompt: prompt
        )
        
        // Parse response into individual prompts
        let scenes = response
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return Array(scenes.prefix(sceneCount))
    }
    
    func generateVariations(
        basePrompt: String,
        variationCount: Int
    ) async throws -> [String] {
        let prompt = """
        Create \(variationCount) variations of this image prompt: \(basePrompt)
        
        Each variation should:
        - Keep the core concept
        - Change style, mood, or specific details
        - Still work as a complete prompt
        
        Output only the prompts, one per line.
        """
        
        let response = try await ollamaClient.generateText(
            model: "llama3.3",
            prompt: prompt
        )
        
        let variations = response
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return Array(variations.prefix(variationCount))
    }
    
    func generateCharacterDescription(
        characterConcept: String
    ) async throws -> String {
        let prompt = """
        Create a detailed, consistent character description for AI image generation: \(characterConcept)
        
        Include:
        - Physical appearance (face, body, clothing)
        - Distinctive features
        - Art style hints
        
        Keep it concise but specific. This will be used as a reference for multiple images.
        """
        
        return try await ollamaClient.generateText(
            model: "llama3.3",
            prompt: prompt
        )
    }
}
```

### 4.2 Workflow Templates with LLM

```swift
class LLMWorkflowGenerator {
    let promptGenerator: WorkflowPromptGenerator
    let instructionGenerator: StoryflowInstructionGenerator
    
    func generateStoryWorkflow(
        concept: String,
        sceneCount: Int,
        config: DrawThingsConfig
    ) async throws -> [[String: Any]] {
        // Generate scene prompts
        let scenes = try await promptGenerator.generateStoryScenes(
            concept: concept,
            sceneCount: sceneCount
        )
        
        // Convert to workflow instructions
        let scenesWithConfig = scenes.map { (prompt: $0, config: nil as DrawThingsConfig?) }
        
        return instructionGenerator.generateStorySequence(
            scenes: scenesWithConfig,
            outputPrefix: "story_scene_"
        )
    }
    
    func generateCharacterConsistencyWorkflow(
        characterConcept: String,
        sceneDescriptions: [String],
        config: DrawThingsConfig
    ) async throws -> [[String: Any]] {
        // Generate detailed character description
        let characterPrompt = try await promptGenerator.generateCharacterDescription(
            characterConcept: characterConcept
        )
        
        // Generate workflow with moodboard reference
        return instructionGenerator.generateCharacterConsistencyWorkflow(
            characterDescription: characterPrompt,
            scenes: sceneDescriptions,
            config: config
        )
    }
}
```

---

## 5. EXAMPLE WORKFLOWS

### 5.1 Simple Story (3 scenes)

```json
[
  { "note": "Three-act story workflow" },
  { "config": { "width": 1024, "height": 1024, "steps": 30, "model": "flux_1_dev_q8p.ckpt" } },
  { "prompt": "A lone astronaut standing on a desolate alien planet, orange sky, twin suns" },
  { "canvasSave": "act1_arrival.png" },
  { "prompt": "The astronaut discovering ancient alien ruins, mysterious symbols, dramatic lighting" },
  { "canvasSave": "act2_discovery.png" },
  { "prompt": "The astronaut activating a portal, bright energy, sense of wonder and adventure" },
  { "canvasSave": "act3_revelation.png" }
]
```

### 5.2 Batch Variations Loop

```json
[
  { "note": "Generate 5 variations" },
  { "config": { "width": 768, "height": 1024, "steps": 25 } },
  { "prompt": "A cyberpunk street scene at night, neon lights, rain" },
  { "loop": { "loop": 5, "start": 0 } },
  { "loopSave": "variation_" },
  { "loopEnd": true }
]
```

### 5.3 Character Consistency with Moodboard

```json
[
  { "note": "Character consistency workflow" },
  { "config": { "width": 768, "height": 1024, "steps": 30 } },
  { "prompt": "Character reference: young woman with red hair, green eyes, leather jacket, detailed portrait" },
  { "canvasSave": "character_ref.png" },
  { "moodboardClear": true },
  { "moodboardCanvas": true },
  { "moodboardWeights": { "index_0": 1.0 } },
  { "prompt": "The red-haired woman walking through a city street, confident pose" },
  { "canvasSave": "scene1.png" },
  { "prompt": "The red-haired woman in a cafe, holding coffee, warm lighting" },
  { "canvasSave": "scene2.png" },
  { "prompt": "The red-haired woman on a rooftop at sunset, wind in hair" },
  { "canvasSave": "scene3.png" }
]
```

### 5.4 Animation Frames with Loop Load/Save

```json
[
  { "note": "Process animation frames" },
  { "config": { "width": 512, "height": 512, "steps": 20 } },
  { "loop": { "loop": 10, "start": 0 } },
  { "loopLoad": "input_frames" },
  { "prompt": "enhance details, sharpen, vibrant colors" },
  { "config": { "strength": 0.3 } },
  { "loopSave": "enhanced_frame_" },
  { "loopEnd": true }
]
```

---

## 6. VALIDATION & ERROR HANDLING

### 6.1 Instruction Validator

```swift
class StoryflowValidator {
    
    func validate(instructions: [[String: Any]]) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        var inLoop = false
        var loopHasEnd = false
        
        for (index, instruction) in instructions.enumerated() {
            guard let key = instruction.keys.first else {
                errors.append(.invalidStructure(index: index))
                continue
            }
            
            // Check if key is valid
            if !allowedKeys.contains(key) {
                errors.append(.unknownInstruction(index: index, key: key))
            }
            
            // Check loop pairing
            if key == "loop" {
                if inLoop {
                    errors.append(.nestedLoop(index: index))
                }
                inLoop = true
                loopHasEnd = false
            }
            
            if key == "loopEnd" {
                if !inLoop {
                    errors.append(.unexpectedLoopEnd(index: index))
                } else {
                    loopHasEnd = true
                    inLoop = false
                }
            }
            
            // Validate file paths
            if ["canvasLoad", "canvasSave", "moodboardAdd", "maskLoad"].contains(key) {
                if let path = instruction[key] as? String {
                    if !isValidFilePath(path, forKey: key) {
                        errors.append(.invalidFilePath(index: index, path: path))
                    }
                }
            }
        }
        
        // Check unclosed loops
        if inLoop && !loopHasEnd {
            warnings.append(.unclosedLoop)
        }
        
        return ValidationResult(errors: errors, warnings: warnings)
    }
    
    private func isValidFilePath(_ path: String, forKey key: String) -> Bool {
        let saveKeys = ["canvasSave", "loopSave"]
        let loadKeys = ["canvasLoad", "moodboardAdd", "maskLoad"]
        
        if saveKeys.contains(key) {
            return path.hasSuffix(".png")
        }
        
        if loadKeys.contains(key) {
            return path.hasSuffix(".png") || path.hasSuffix(".jpg") || path.hasSuffix(".webp")
        }
        
        return true
    }
    
    private let allowedKeys = [
        "note", "prompt", "config", "frames", "faceZoom", "askZoom",
        "removeBkgd", "canvasClear", "canvasSave", "canvasLoad",
        "moveScale", "adaptSize", "crop", "moodboardClear", "moodboardCanvas",
        "moodboardAdd", "loopAddMB", "moodboardRemove", "moodboardWeights",
        "maskClear", "maskLoad", "maskGet", "maskBkgd", "maskFG", "maskBody", "maskAsk",
        "depthExtract", "depthCanvas", "depthToCanvas", "inpaintTools", "xlMagic",
        "negPrompt", "poseExtract", "poseJSON", "loop", "loopLoad", "loopSave",
        "loopEnd", "end"
    ]
}

struct ValidationResult {
    let errors: [ValidationError]
    let warnings: [ValidationWarning]
    
    var isValid: Bool {
        errors.isEmpty
    }
}

enum ValidationError {
    case invalidStructure(index: Int)
    case unknownInstruction(index: Int, key: String)
    case nestedLoop(index: Int)
    case unexpectedLoopEnd(index: Int)
    case invalidFilePath(index: Int, path: String)
}

enum ValidationWarning {
    case unclosedLoop
    case noPrompts
    case noConfig
}
```

---

## 7. INTEGRATION WITH EXISTING SPECS

This replaces the "JavaScript script generation" sections from the earlier addendum. Everything else in the main specs remains valid:

**Keep from main spec:**
- Ollama integration (Section 3)
- LM Studio / MstyStudio integration (Section 4)
- gRPC integration (Section 2) - optional, for direct execution
- File management (Section 6)
- UI structure (Section 7)

**Replace from addendum:**
- Instead of generating `.js` files, generate JSON instruction arrays
- Instead of `DrawThingsScriptGenerator`, use `StoryflowInstructionGenerator`
- Users paste JSON into StoryflowPipeline.js (which they load once)

---

## 8. RECOMMENDED IMPLEMENTATION ORDER

### Phase 1: Core Generator (Week 1)
1. ✅ Implement instruction models (Section 2.1)
2. ✅ Implement basic generator (Section 2.2 - simple methods only)
3. ✅ Implement JSON export (Section 2.3)
4. ✅ Create basic UI for manual instruction building
5. ✅ Test with StoryflowPipeline.js in Draw Things

### Phase 2: LLM Integration (Week 2)
1. ✅ Integrate Ollama client from main spec
2. ✅ Implement WorkflowPromptGenerator (Section 4.1)
3. ✅ Add "Generate from Concept" UI
4. ✅ Test full LLM → JSON → Draw Things pipeline

### Phase 3: Advanced Workflows (Week 3)
1. ✅ Implement workflow templates
2. ✅ Add validation (Section 6)
3. ✅ Implement LLMWorkflowGenerator (Section 4.2)
4. ✅ Add visual workflow builder UI

### Phase 4: Polish (Week 4)
1. ✅ Add gRPC direct execution option (from main spec)
2. ✅ Implement workflow library
3. ✅ Add examples and documentation
4. ✅ Testing and refinement

---

## 9. ADVANTAGES OF THIS ARCHITECTURE

**For Users:**
- Don't need to understand code
- Can edit JSON by hand if needed
- One Pipeline script handles everything
- Workflows are portable text files
- Can share workflows with community

**For Development:**
- Clean separation of concerns
- No need to implement all Draw Things features
- Leverage existing, tested Pipeline
- Easier to add new instruction types
- JSON is simple to generate and validate

**For Future:**
- Could build web version (same JSON format)
- Could build iOS version
- Community can create their own editors
- Pipeline updates don't break your app

---

## APPENDIX: COMPLETE EXAMPLE OUTPUT

Here's what your app would generate for "Create a 3-scene wizard story":

```json
[
  {
    "note": "Wizard's Journey - 3-scene story"
  },
  {
    "config": {
      "width": 1024,
      "height": 1024,
      "steps": 30,
      "guidanceScale": 7.5,
      "model": "flux_1_dev_q8p.ckpt",
      "samplerName": "dpmpp_2m"
    }
  },
  {
    "prompt": "An ancient wizard with a long silver beard stands at the edge of a mystical forest, staff glowing with ethereal light, dawn breaking through the trees, epic fantasy art"
  },
  {
    "canvasSave": "wizard_scene1_forest.png"
  },
  {
    "prompt": "The wizard descending stone steps into a vast underground chamber filled with floating crystals and ancient runes, magical atmosphere, dramatic lighting from below"
  },
  {
    "canvasSave": "wizard_scene2_chamber.png"
  },
  {
    "prompt": "The wizard holding a glowing orb of power in both hands, energy swirling around him, triumphant expression, particles of light, climactic moment"
  },
  {
    "canvasSave": "wizard_scene3_power.png"
  }
]
```

User copies this, pastes into StoryflowPipeline.js in Draw Things, clicks OK, and it executes!

---

**END OF SPECIFICATIONS**
