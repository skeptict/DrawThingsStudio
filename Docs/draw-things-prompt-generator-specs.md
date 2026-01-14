# Technical Specifications: Draw Things AI Prompt Generator
**Target Platform:** macOS native Swift app  
**Development Strategy:** Direct Swift implementation (Python prototyping optional but not required)

---

## 1. PROJECT OVERVIEW

### 1.1 Core Functionality
A macOS native application that:
1. Connects to **Ollama** (or compatible LLM services) to generate/iterate image generation prompts
2. Sends prompts to **Draw Things** via gRPC to render images
3. Receives completed images and saves them to user-specified locations
4. Manages multi-step workflows similar to the StoryFlow pattern (command queueing, configs, batching)

### 1.2 Secondary Features
- Connect to additional desktop LLM apps (LM Studio, MstyStudio)
- Support for animation workflows
- Workflow management system for queuing operations

---

## 2. DRAW THINGS gRPC INTEGRATION

### 2.1 Draw Things gRPC API Details

**Official Resources:**
- Main repository: https://github.com/drawthingsai/draw-things-community
- Community implementation (Python/TypeScript reference): https://github.com/Jokimbe/ComfyUI-DrawThings-gRPC
- Docker image: `drawthingsai/draw-things-grpc-server-cli:latest`

**Key gRPC Server Configuration:**
```bash
# For macOS binary
gRPCServerCLI-macOS [path to models] --no-response-compression --model-browser

# Default port: 7859
# Protocol: gRPC with TLS enabled
# Response compression: Must be disabled for client compatibility
# Model browser: Should be enabled for model discovery
```

### 2.2 Proto File Location Strategy

**Where to Find Proto Definitions:**

The proto files are in the Draw Things community repository. Key locations to check:
- `Libraries/` directory
- Look for files with `.proto` extension
- The Swift implementation uses swift-protobuf (see WORKSPACE files)

**Implementation Strategy:**
1. Clone the Draw Things community repo
2. Extract the .proto files (likely in `Libraries/DrawThingsGRPC/` or similar)
3. Use Swift's `protoc` compiler with swift-protobuf plugin to generate Swift code:
   ```bash
   # Install swift-protobuf plugin
   brew install swift-protobuf
   
   # Generate Swift code from proto files
   protoc --swift_out=. --grpc-swift_out=. [proto_files]
   ```

### 2.3 Core gRPC Operations Required

Based on Draw Things functionality, the app needs to support:

**Model Operations:**
- `ListModels()` - Discover available models on server
- `GetModelInfo(model_id)` - Get model metadata

**Generation Operations:**
- `GenerateImage(request)` - Primary image generation
- `GenerateImageStream(request)` - Streaming generation with progress
- `CancelGeneration(generation_id)` - Cancel ongoing generation

**Image Operations:**
- `UploadImage(image_data)` - For img2img workflows
- `DownloadImage(image_id)` - Retrieve completed images

**Configuration Parameters to Support:**
```swift
struct ImageGenerationRequest {
    // Required
    var prompt: String
    var modelId: String
    var width: Int
    var height: Int
    
    // Common parameters
    var negativePrompt: String?
    var steps: Int = 30
    var guidanceScale: Float = 7.5
    var seed: Int64? = nil  // nil for random
    var batchSize: Int = 1
    var samplerName: String = "dpmpp_2m"
    
    // Advanced
    var strength: Float? = nil  // For img2img (0.0-1.0)
    var initImage: Data? = nil   // For img2img
    var controlNet: ControlNetConfig? = nil
    var loras: [LoRAConfig]? = nil
}

struct ControlNetConfig {
    var model: String
    var image: Data
    var weight: Float = 1.0
}

struct LoRAConfig {
    var name: String
    var weight: Float = 1.0
}
```

### 2.4 Connection Management

**Swift gRPC Client Setup:**
```swift
import GRPC
import NIO

class DrawThingsClient {
    private let eventLoopGroup: EventLoopGroup
    private let channel: GRPCChannel
    private let client: DrawThingsServiceClient
    
    init(host: String = "localhost", port: Int = 7859) throws {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // Configure TLS if needed
        self.channel = try GRPCChannelPool.with(
            target: .host(host, port: port),
            transportSecurity: .plaintext, // or .tls for TLS
            eventLoopGroup: eventLoopGroup
        )
        
        self.client = DrawThingsServiceClient(channel: channel)
    }
    
    func shutdown() {
        try? channel.close().wait()
        try? eventLoopGroup.syncShutdownGracefully()
    }
}
```

---

## 3. OLLAMA INTEGRATION

### 3.1 Ollama HTTP API

**Base URL:** `http://localhost:11434`

**Key Endpoints:**

1. **Generate Completion** (for prompt creation/iteration)
```swift
POST /api/generate
{
    "model": "llama3.3",  // or other model
    "prompt": "Create a detailed image generation prompt for: a mystical forest",
    "stream": true,        // false for single response
    "options": {
        "temperature": 0.8,
        "top_p": 0.9,
        "num_predict": 200  // max tokens
    }
}

// Response (streaming or single)
{
    "model": "llama3.3",
    "response": "A mystical forest bathed in ethereal moonlight...",
    "done": true
}
```

2. **List Models**
```swift
GET /api/tags
// Returns list of available models
```

3. **Model Info**
```swift
POST /api/show
{
    "name": "llama3.3"
}
```

### 3.2 Swift URLSession Integration

```swift
import Foundation

class OllamaClient {
    private let baseURL = URL(string: "http://localhost:11434")!
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: config)
    }
    
    func generatePrompt(
        model: String = "llama3.3",
        instruction: String,
        streaming: Bool = true,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let url = baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "prompt": instruction,
            "stream": streaming,
            "options": [
                "temperature": 0.8,
                "top_p": 0.9,
                "num_predict": 300
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // Implementation for streaming or single response
        // ...
    }
}
```

### 3.3 Prompt Generation Patterns

**System Prompts for Different Use Cases:**

```swift
enum PromptStyle {
    case creative
    case technical
    case photorealistic
    case artistic
    
    var systemPrompt: String {
        switch self {
        case .creative:
            return """
            You are an expert at creating detailed, imaginative prompts for AI image generation.
            Focus on vivid descriptions, artistic style, mood, lighting, and composition.
            Keep prompts clear and under 200 words.
            """
        case .technical:
            return """
            Create precise, technical prompts for AI image generation.
            Include specific details about camera angles, lighting setups, materials, and rendering style.
            """
        case .photorealistic:
            return """
            Generate prompts for photorealistic image generation.
            Include camera settings, lighting conditions, time of day, and realistic details.
            """
        case .artistic:
            return """
            Create artistic prompts inspired by famous art movements and styles.
            Reference specific artists, techniques, and artistic periods when appropriate.
            """
        }
    }
}
```

**Iteration Strategy:**
```swift
struct PromptIteration {
    let originalPrompt: String
    let userFeedback: String
    let iteration: Int
    
    func buildIterationPrompt() -> String {
        return """
        Original prompt: \(originalPrompt)
        
        User feedback: \(userFeedback)
        
        Iteration #\(iteration): Improve the prompt based on the feedback. Maintain the core concept while addressing the user's concerns.
        """
    }
}
```

---

## 4. LM STUDIO & MSTYSTUDIO INTEGRATION

### 4.1 LM Studio API

LM Studio provides an OpenAI-compatible API:

**Base URL:** `http://localhost:1234/v1`

```swift
class LMStudioClient {
    private let baseURL = URL(string: "http://localhost:1234/v1")!
    
    func generateCompletion(
        model: String,
        messages: [[String: String]],
        temperature: Float = 0.8
    ) async throws -> String {
        let url = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": 300
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return response.choices.first?.message.content ?? ""
    }
}

struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
            let role: String
        }
        let message: Message
    }
    let choices: [Choice]
}
```

### 4.2 MstyStudio Integration

MstyStudio also uses OpenAI-compatible API (similar to LM Studio):

**Base URL:** `http://localhost:10000/v1` (verify actual port)

Implementation is identical to LM Studio client above.

### 4.3 Unified LLM Interface

Create an abstraction to support multiple providers:

```swift
protocol LLMProvider {
    func generateText(prompt: String) async throws -> String
    func listModels() async throws -> [String]
}

class OllamaProvider: LLMProvider { /* ... */ }
class LMStudioProvider: LLMProvider { /* ... */ }
class MstyStudioProvider: LLMProvider { /* ... */ }

enum LLMProviderType {
    case ollama
    case lmStudio
    case mstyStudio
    
    func createProvider() -> LLMProvider {
        switch self {
        case .ollama: return OllamaProvider()
        case .lmStudio: return LMStudioProvider()
        case .mstyStudio: return MstyStudioProvider()
        }
    }
}
```

---

## 5. WORKFLOW MANAGEMENT SYSTEM

### 5.1 Workflow Queue Architecture

Inspired by StoryFlow pattern - manage complex multi-step operations:

```swift
// Workflow step definitions
enum WorkflowStepType {
    case generatePrompt(instruction: String, style: PromptStyle)
    case refinePrompt(feedback: String)
    case generateImage(prompt: String, config: ImageConfig)
    case saveImage(path: URL)
    case batchGenerate(prompts: [String], config: ImageConfig)
}

struct WorkflowStep: Identifiable {
    let id = UUID()
    let type: WorkflowStepType
    var status: StepStatus = .pending
    var result: Any?
    var error: Error?
    
    enum StepStatus {
        case pending
        case running
        case completed
        case failed
        case cancelled
    }
}

class WorkflowQueue: ObservableObject {
    @Published var steps: [WorkflowStep] = []
    @Published var currentStepIndex: Int = 0
    @Published var isPaused: Bool = false
    
    private let llmProvider: LLMProvider
    private let drawThingsClient: DrawThingsClient
    
    func addStep(_ step: WorkflowStep) {
        steps.append(step)
    }
    
    func executeNext() async throws {
        guard currentStepIndex < steps.count, !isPaused else { return }
        
        var step = steps[currentStepIndex]
        step.status = .running
        steps[currentStepIndex] = step
        
        do {
            let result = try await executeStep(step)
            step.status = .completed
            step.result = result
            currentStepIndex += 1
        } catch {
            step.status = .failed
            step.error = error
        }
        
        steps[currentStepIndex] = step
        
        // Continue to next step
        if currentStepIndex < steps.count {
            try await executeNext()
        }
    }
    
    private func executeStep(_ step: WorkflowStep) async throws -> Any {
        switch step.type {
        case .generatePrompt(let instruction, let style):
            return try await llmProvider.generateText(prompt: style.systemPrompt + "\n" + instruction)
        case .refinePrompt(let feedback):
            // Get previous prompt and refine
            return try await llmProvider.generateText(prompt: feedback)
        case .generateImage(let prompt, let config):
            return try await drawThingsClient.generateImage(prompt: prompt, config: config)
        case .saveImage(let path):
            // Save logic
            return path
        case .batchGenerate(let prompts, let config):
            return try await withThrowingTaskGroup(of: Data.self) { group in
                for prompt in prompts {
                    group.addTask {
                        try await self.drawThingsClient.generateImage(prompt: prompt, config: config)
                    }
                }
                var results: [Data] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }
        }
    }
    
    func pause() {
        isPaused = true
    }
    
    func resume() async throws {
        isPaused = false
        try await executeNext()
    }
    
    func cancel() {
        steps.indices.forEach { index in
            if steps[index].status == .pending || steps[index].status == .running {
                steps[index].status = .cancelled
            }
        }
        isPaused = true
    }
}
```

### 5.2 Workflow Templates

Pre-defined workflow patterns:

```swift
enum WorkflowTemplate {
    case simpleGeneration
    case iterativeRefinement(iterations: Int)
    case batchVariations(count: Int)
    case storySequence(scenes: [String])
    
    func buildSteps(basePrompt: String) -> [WorkflowStep] {
        switch self {
        case .simpleGeneration:
            return [
                WorkflowStep(type: .generateImage(prompt: basePrompt, config: .default))
            ]
            
        case .iterativeRefinement(let iterations):
            var steps: [WorkflowStep] = []
            steps.append(WorkflowStep(type: .generatePrompt(instruction: basePrompt, style: .creative)))
            for i in 1...iterations {
                steps.append(WorkflowStep(type: .refinePrompt(feedback: "Iteration \(i)")))
                steps.append(WorkflowStep(type: .generateImage(prompt: "", config: .default)))
            }
            return steps
            
        case .batchVariations(let count):
            var prompts: [String] = []
            for i in 1...count {
                prompts.append(basePrompt + ", variation \(i)")
            }
            return [
                WorkflowStep(type: .batchGenerate(prompts: prompts, config: .default))
            ]
            
        case .storySequence(let scenes):
            return scenes.map { scene in
                WorkflowStep(type: .generateImage(prompt: scene, config: .default))
            }
        }
    }
}
```

---

## 6. DATA MODELS & PERSISTENCE

### 6.1 Core Data Models

```swift
import Foundation
import SwiftData

@Model
class GeneratedImage {
    @Attribute(.unique) var id: UUID
    var prompt: String
    var negativePrompt: String?
    var modelName: String
    var parameters: ImageParameters
    var imageData: Data?
    var imagePath: URL?
    var createdAt: Date
    var favorite: Bool
    
    init(prompt: String, modelName: String, parameters: ImageParameters) {
        self.id = UUID()
        self.prompt = prompt
        self.modelName = modelName
        self.parameters = parameters
        self.createdAt = Date()
        self.favorite = false
    }
}

struct ImageParameters: Codable {
    var width: Int
    var height: Int
    var steps: Int
    var guidanceScale: Float
    var seed: Int64?
    var samplerName: String
    var strength: Float?
}

@Model
class Workflow {
    @Attribute(.unique) var id: UUID
    var name: String
    var steps: [WorkflowStep]
    var createdAt: Date
    var lastExecuted: Date?
    
    init(name: String, steps: [WorkflowStep]) {
        self.id = UUID()
        self.name = name
        self.steps = steps
        self.createdAt = Date()
    }
}

@Model
class PromptTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var template: String
    var style: String
    var variables: [String]
    
    init(name: String, template: String, style: String) {
        self.id = UUID()
        self.name = name
        self.template = template
        self.style = style
        self.variables = []
    }
}
```

### 6.2 File System Organization

```swift
class FileManager {
    static let shared = FileManager()
    
    let baseDirectory: URL
    let imagesDirectory: URL
    let workflowsDirectory: URL
    let promptsDirectory: URL
    
    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        self.baseDirectory = appSupport.appendingPathComponent("DrawThingsPromptGenerator")
        self.imagesDirectory = baseDirectory.appendingPathComponent("Images")
        self.workflowsDirectory = baseDirectory.appendingPathComponent("Workflows")
        self.promptsDirectory = baseDirectory.appendingPathComponent("Prompts")
        
        createDirectories()
    }
    
    private func createDirectories() {
        [imagesDirectory, workflowsDirectory, promptsDirectory].forEach { dir in
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    
    func saveImage(_ data: Data, prompt: String) throws -> URL {
        let filename = "\(Date().timeIntervalSince1970)_\(prompt.prefix(50)).png"
        let url = imagesDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }
}
```

---

## 7. USER INTERFACE STRUCTURE

### 7.1 Main Window Layout (SwiftUI)

```swift
struct ContentView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView()
        } content: {
            // Main content area
            MainWorkspaceView()
        } detail: {
            // Preview/details
            DetailView()
        }
        .environmentObject(appState)
    }
}

struct SidebarView: View {
    var body: some View {
        List {
            Section("Quick Actions") {
                NavigationLink("New Generation", destination: GenerationView())
                NavigationLink("Workflows", destination: WorkflowsView())
                NavigationLink("History", destination: HistoryView())
            }
            
            Section("Connections") {
                ConnectionStatusView(service: "Draw Things")
                ConnectionStatusView(service: "Ollama")
                ConnectionStatusView(service: "LM Studio")
            }
            
            Section("Templates") {
                ForEach(appState.templates) { template in
                    NavigationLink(template.name, destination: TemplateDetailView(template: template))
                }
            }
        }
        .listStyle(.sidebar)
    }
}
```

### 7.2 Key Views

**Generation View:**
```swift
struct GenerationView: View {
    @State private var promptInstruction = ""
    @State private var selectedStyle: PromptStyle = .creative
    @State private var selectedModel = ""
    @State private var imageConfig = ImageConfig.default
    @StateObject private var generator = ImageGenerator()
    
    var body: some View {
        VStack(spacing: 20) {
            // Prompt generation section
            PromptInputSection(
                instruction: $promptInstruction,
                style: $selectedStyle
            )
            
            // Image configuration
            ImageConfigSection(config: $imageConfig)
            
            // Generate button
            Button("Generate") {
                Task {
                    await generator.generate(
                        instruction: promptInstruction,
                        style: selectedStyle,
                        config: imageConfig
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            
            // Progress and preview
            if generator.isGenerating {
                ProgressView(generator.progress)
            }
            
            if let image = generator.currentImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .padding()
    }
}
```

---

## 8. DEPENDENCIES & PACKAGE MANAGEMENT

### 8.1 Swift Package Manager Dependencies

Create `Package.swift` or add to Xcode project:

```swift
dependencies: [
    // gRPC Swift
    .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.21.0"),
    
    // Swift Protobuf
    .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.25.0"),
    
    // SwiftNIO (required by gRPC)
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.62.0"),
    
    // Optional: Async algorithms
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
]
```

### 8.2 System Requirements

**Minimum:**
- macOS 13.0+ (for SwiftUI features)
- Xcode 15.0+
- Swift 5.9+

**Runtime Dependencies:**
- Draw Things app OR gRPCServerCLI running
- Ollama (optional: LM Studio, MstyStudio)

---

## 9. CONFIGURATION & SETTINGS

### 9.1 App Configuration

```swift
class AppConfiguration: ObservableObject {
    // Draw Things settings
    @AppStorage("drawThings.host") var drawThingsHost = "localhost"
    @AppStorage("drawThings.port") var drawThingsPort = 7859
    @AppStorage("drawThings.useTLS") var drawThingsUseTLS = false
    
    // Ollama settings
    @AppStorage("ollama.host") var ollamaHost = "localhost"
    @AppStorage("ollama.port") var ollamaPort = 11434
    @AppStorage("ollama.defaultModel") var ollamaDefaultModel = "llama3.3"
    
    // LM Studio settings
    @AppStorage("lmstudio.host") var lmStudioHost = "localhost"
    @AppStorage("lmstudio.port") var lmStudioPort = 1234
    @AppStorage("lmstudio.enabled") var lmStudioEnabled = false
    
    // MstyStudio settings
    @AppStorage("mstystudio.host") var mstyStudioHost = "localhost"
    @AppStorage("mstystudio.port") var mstyStudioPort = 10000
    @AppStorage("mstystudio.enabled") var mstyStudioEnabled = false
    
    // Image save settings
    @AppStorage("images.saveDirectory") var imagesSaveDirectory = ""
    @AppStorage("images.autoSave") var imagesAutoSave = true
    @AppStorage("images.format") var imagesFormat = "png"
    
    // Default generation settings
    @AppStorage("defaults.width") var defaultWidth = 512
    @AppStorage("defaults.height") var defaultHeight = 512
    @AppStorage("defaults.steps") var defaultSteps = 30
    @AppStorage("defaults.guidanceScale") var defaultGuidanceScale = 7.5
}
```

---

## 10. ANIMATION WORKFLOW SUPPORT

### 10.1 Animation Sequence Generation

```swift
struct AnimationFrame {
    let frameNumber: Int
    let prompt: String
    let interpolationWeight: Float
    let imageData: Data?
}

class AnimationWorkflow {
    func generateKeyframePrompts(
        startPrompt: String,
        endPrompt: String,
        frames: Int
    ) async throws -> [AnimationFrame] {
        var keyframes: [AnimationFrame] = []
        
        for i in 0..<frames {
            let weight = Float(i) / Float(frames - 1)
            let interpolatedPrompt = try await interpolatePrompts(
                startPrompt,
                endPrompt,
                weight: weight
            )
            
            keyframes.append(AnimationFrame(
                frameNumber: i,
                prompt: interpolatedPrompt,
                interpolationWeight: weight,
                imageData: nil
            ))
        }
        
        return keyframes
    }
    
    private func interpolatePrompts(
        _ start: String,
        _ end: String,
        weight: Float
    ) async throws -> String {
        // Use LLM to generate intermediate prompt
        let instruction = """
        Create a transition prompt between these two descriptions:
        Start: \(start)
        End: \(end)
        Transition weight: \(weight) (0.0 = start, 1.0 = end)
        """
        
        // Call LLM provider
        return try await llmProvider.generateText(prompt: instruction)
    }
}
```

---

## 11. ERROR HANDLING & LOGGING

### 11.1 Error Types

```swift
enum AppError: LocalizedError {
    case connectionFailed(service: String, details: String)
    case generationFailed(reason: String)
    case modelNotFound(modelName: String)
    case invalidConfiguration(field: String)
    case fileSystemError(details: String)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let service, let details):
            return "Failed to connect to \(service): \(details)"
        case .generationFailed(let reason):
            return "Image generation failed: \(reason)"
        case .modelNotFound(let modelName):
            return "Model '\(modelName)' not found"
        case .invalidConfiguration(let field):
            return "Invalid configuration: \(field)"
        case .fileSystemError(let details):
            return "File system error: \(details)"
        }
    }
}
```

### 11.2 Logging

```swift
import OSLog

extension Logger {
    static let app = Logger(subsystem: "com.yourapp.drawthings", category: "app")
    static let grpc = Logger(subsystem: "com.yourapp.drawthings", category: "grpc")
    static let llm = Logger(subsystem: "com.yourapp.drawthings", category: "llm")
    static let workflow = Logger(subsystem: "com.yourapp.drawthings", category: "workflow")
}

// Usage:
Logger.grpc.info("Connected to Draw Things at \(host):\(port)")
Logger.llm.error("Failed to generate prompt: \(error.localizedDescription)")
```

---

## 12. TESTING STRATEGY

### 12.1 Unit Tests

```swift
import XCTest
@testable import DrawThingsPromptGenerator

class DrawThingsClientTests: XCTestCase {
    var client: DrawThingsClient!
    
    override func setUpWithError() throws {
        client = try DrawThingsClient(host: "localhost", port: 7859)
    }
    
    func testModelListing() async throws {
        let models = try await client.listModels()
        XCTAssertFalse(models.isEmpty, "Should have at least one model")
    }
    
    func testImageGeneration() async throws {
        let config = ImageConfig(
            prompt: "test prompt",
            width: 512,
            height: 512
        )
        
        let imageData = try await client.generateImage(config: config)
        XCTAssertFalse(imageData.isEmpty, "Should return image data")
    }
}
```

---

## 13. PERFORMANCE OPTIMIZATION

### 13.1 Caching Strategy

```swift
class PromptCache {
    private var cache: [String: String] = [:]
    private let maxSize = 100
    
    func get(key: String) -> String? {
        return cache[key]
    }
    
    func set(key: String, value: String) {
        if cache.count >= maxSize {
            // Remove oldest entry (simple FIFO)
            if let firstKey = cache.keys.first {
                cache.removeValue(forKey: firstKey)
            }
        }
        cache[key] = value
    }
}

class ImageCache {
    private let cache = NSCache<NSString, NSImage>()
    
    init() {
        cache.countLimit = 50  // Max 50 images in memory
        cache.totalCostLimit = 500 * 1024 * 1024  // 500 MB
    }
    
    func get(key: String) -> NSImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func set(key: String, image: NSImage) {
        cache.setObject(image, forKey: key as NSString)
    }
}
```

---

## 14. SECURITY CONSIDERATIONS

### 14.1 API Key Management (if needed in future)

```swift
import Security

class KeychainManager {
    static func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed
        }
    }
    
    static func load(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw KeychainError.loadFailed
        }
        
        return data
    }
}

enum KeychainError: Error {
    case saveFailed
    case loadFailed
}
```

---

## 15. DEPLOYMENT & DISTRIBUTION

### 15.1 Build Configuration

**Release Build Settings:**
- Enable Swift optimization
- Strip debug symbols
- Code signing for distribution
- Hardened runtime enabled
- Sandboxing (if App Store)

### 15.2 Distribution Methods

1. **Direct Distribution:**
   - DMG installer with app bundle
   - Notarized by Apple
   
2. **Mac App Store:**
   - Full sandboxing required
   - Network entitlements needed
   - File access permissions

---

## APPENDIX A: QUICK START CHECKLIST

### For Claude Code Development:

1. **Setup Phase:**
   - [ ] Clone Draw Things community repo to extract proto files
   - [ ] Generate Swift code from proto files using protoc
   - [ ] Set up SPM dependencies (gRPC Swift, SwiftProtobuf)
   - [ ] Create Xcode project structure

2. **Core Implementation Order:**
   - [ ] Implement DrawThingsClient (gRPC connection)
   - [ ] Implement OllamaClient (HTTP requests)
   - [ ] Create unified LLMProvider protocol
   - [ ] Build WorkflowQueue system
   - [ ] Implement data models with SwiftData
   - [ ] Create main UI structure

3. **Feature Implementation:**
   - [ ] Basic prompt generation
   - [ ] Image generation
   - [ ] Image saving
   - [ ] Workflow management
   - [ ] Settings/preferences
   - [ ] Secondary LLM providers

4. **Polish:**
   - [ ] Error handling
   - [ ] Progress indicators
   - [ ] Caching
   - [ ] Testing
   - [ ] Documentation

---

## APPENDIX B: TOKEN-SAVING STRATEGIES FOR CLAUDE CODE

**What to include in prompts to Claude Code:**

1. **Always reference this spec document:** "Following the technical specifications in `draw-things-prompt-generator-specs.md`..."

2. **Be specific about which section to implement:** "Implement section 2.4 (Connection Management) from the specs"

3. **Reference existing patterns:** "Use the error handling pattern from section 11.1"

4. **Avoid re-explaining architecture:** The specs contain all architectural decisions

5. **Focus on incremental development:** Build one feature at a time, referencing the spec for context

**What NOT to repeat in prompts:**
- Proto file generation process (covered in 2.2)
- API endpoint details (covered in 3.1, 4.1, 4.2)
- Data model structures (covered in 6.1)
- UI component structures (covered in 7.1, 7.2)

---

## APPENDIX C: COMMON SWIFT PATTERNS FOR THIS PROJECT

### C.1 Async/Await Network Calls

```swift
// Pattern for all network operations
func performNetworkOperation() async throws -> Result {
    let url = URL(string: "...")!
    let (data, response) = try await URLSession.shared.data(from: url)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw NetworkError.invalidResponse
    }
    
    return try JSONDecoder().decode(Result.self, from: data)
}
```

### C.2 SwiftUI State Management

```swift
// Use @StateObject for owned objects
@StateObject private var viewModel = ViewModel()

// Use @ObservedObject for injected objects  
@ObservedObject var appState: AppState

// Use @State for simple values
@State private var text = ""

// Use @Binding for two-way communication
@Binding var isPresented: Bool
```

### C.3 Error Presentation in SwiftUI

```swift
struct ContentView: View {
    @State private var error: Error?
    @State private var showError = false
    
    var body: some View {
        VStack {
            // Content
        }
        .alert("Error", isPresented: $showError, presenting: error) { _ in
            Button("OK") { }
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}
```

---

**END OF SPECIFICATIONS**
