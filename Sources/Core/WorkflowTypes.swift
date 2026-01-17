import Foundation

// MARK: - Image Configuration

struct ImageConfig: Codable, Equatable {
    // Required (contextually)
    var width: Int
    var height: Int
    
    // Common parameters
    var steps: Int
    var guidanceScale: Float
    var seed: Int64? // nil for random
    var modelId: String?
    var samplerName: String
    var batchSize: Int
    
    // Advanced
    var strength: Float? // For img2img (0.0-1.0)
    var negativePrompt: String?
    
    static let `default` = ImageConfig(
        width: 1024,
        height: 1024,
        steps: 30,
        guidanceScale: 7.5,
        seed: nil,
        modelId: nil,
        samplerName: "dpmpp_2m",
        batchSize: 1,
        strength: nil,
        negativePrompt: nil
    )
}

struct ControlNetConfig: Codable, Equatable {
    var model: String
    var image: Data
    var weight: Float = 1.0
}

struct LoRAConfig: Codable, Equatable {
    var name: String
    var weight: Float = 1.0
}

// MARK: - Workflow Definitions

enum PromptStyle: String, Codable, CaseIterable {
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

enum WorkflowStepType {
    case generatePrompt(instruction: String, style: PromptStyle)
    case refinePrompt(feedback: String)
    case generateImage(prompt: String, config: ImageConfig)
    case saveImage(path: URL)
    case batchGenerate(prompts: [String], config: ImageConfig)
}

// Need to make WorkflowStepType Codable manually if we want to persist it easily within SwiftData or other storage,
// but for now relying on specs which suggest it might be part of an @Model class where complex enums might need handling.
// However, the spec shows `var steps: [WorkflowStep]` in a SwiftData model. 
// SwiftData handles simple Codable enums well, but enums with associated values are trickier.
// For now, I will implement Codable for WorkflowStepType to be safe.

extension WorkflowStepType: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case instruction, style
        case feedback
        case prompt, config
        case path
        case prompts
    }
    
    enum StepType: String, Codable {
        case generatePrompt
        case refinePrompt
        case generateImage
        case saveImage
        case batchGenerate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(StepType.self, forKey: .type)
        
        switch type {
        case .generatePrompt:
            let instruction = try container.decode(String.self, forKey: .instruction)
            let style = try container.decode(PromptStyle.self, forKey: .style)
            self = .generatePrompt(instruction: instruction, style: style)
        case .refinePrompt:
            let feedback = try container.decode(String.self, forKey: .feedback)
            self = .refinePrompt(feedback: feedback)
        case .generateImage:
            let prompt = try container.decode(String.self, forKey: .prompt)
            let config = try container.decode(ImageConfig.self, forKey: .config)
            self = .generateImage(prompt: prompt, config: config)
        case .saveImage:
            let path = try container.decode(URL.self, forKey: .path)
            self = .saveImage(path: path)
        case .batchGenerate:
            let prompts = try container.decode([String].self, forKey: .prompts)
            let config = try container.decode(ImageConfig.self, forKey: .config)
            self = .batchGenerate(prompts: prompts, config: config)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .generatePrompt(let instruction, let style):
            try container.encode(StepType.generatePrompt, forKey: .type)
            try container.encode(instruction, forKey: .instruction)
            try container.encode(style, forKey: .style)
        case .refinePrompt(let feedback):
            try container.encode(StepType.refinePrompt, forKey: .type)
            try container.encode(feedback, forKey: .feedback)
        case .generateImage(let prompt, let config):
            try container.encode(StepType.generateImage, forKey: .type)
            try container.encode(prompt, forKey: .prompt)
            try container.encode(config, forKey: .config)
        case .saveImage(let path):
            try container.encode(StepType.saveImage, forKey: .type)
            try container.encode(path, forKey: .path)
        case .batchGenerate(let prompts, let config):
            try container.encode(StepType.batchGenerate, forKey: .type)
            try container.encode(prompts, forKey: .prompts)
            try container.encode(config, forKey: .config)
        }
    }
}

enum StepStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
    case cancelled
}

struct WorkflowStep: Identifiable, Codable {
    var id: UUID = UUID()
    var type: WorkflowStepType
    var status: StepStatus = .pending
    // 'result' and 'error' are hard to codable since they are Any? and Error?
    // We will omit them from Codable for now or make them transiet if possible.
    // For specific storage we might need a dedicated Result enum.
    
    // For now, complying with basic struct definition.
    // Note: 'Any' is not Codable. 'Error' is not Codable.
    // We will exclude them from the Codable implementation if we were strict,
    // but since we added Codable to the struct, we must handle them.
    // I will make them computed or wrapper types if needed, but for simple DataModels, 
    // I will comment them out from the Codable requirements or make them String descriptions for now.
    
    var resultDescription: String?
    var errorDescription: String?
    
    // In-memory only storage for complex types
    var result: Any? {
        get { nil } // Placeholder
        set { _ = newValue }
    }
    
    var error: Error? {
        get { nil } // Placeholder
        set { _ = newValue } 
    }
    
    // Custom coding keys to exclude non-codable properties if we wanted to auto-synthesize,
    // but since we have non-codable properties (even computed ones don't affect synthesis mostly but Any? stored ones would),
    // simpler to just store what we can.
    
    init(type: WorkflowStepType) {
        self.type = type
    }
}
