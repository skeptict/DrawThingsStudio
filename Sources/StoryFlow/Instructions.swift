import Foundation

// Base protocol
protocol StoryflowInstruction: Codable {
    var instructionDict: [String: Any] { get }
}

// Helper to allow heterogenous collections of instructions to be encoded
extension StoryflowInstruction {
    // Default implementation if needed, but the main goal is to get the dict
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

struct ConfigInstruction: StoryflowInstruction {
    let config: DrawThingsConfig
    
    var instructionDict: [String: Any] {
        ["config": config.toDictionary()]
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

struct LoopSaveInstruction: StoryflowInstruction {
    let loopSave: String
    
    var instructionDict: [String: Any] {
        ["loopSave": loopSave]
    }
}

struct LoopLoadInstruction: StoryflowInstruction {
    let loopLoad: String
    
    var instructionDict: [String: Any] {
        ["loopLoad": loopLoad]
    }
}

// Moodboard
struct MoodboardClearInstruction: StoryflowInstruction {
    var instructionDict: [String: Any] {
        ["moodboardClear": true]
    }
}

struct MoodboardCanvasInstruction: StoryflowInstruction {
    var instructionDict: [String: Any] {
        ["moodboardCanvas": true]
    }
}

struct MoodboardWeightsInstruction: StoryflowInstruction {
    let weights: [String: Float]
    
    var instructionDict: [String: Any] {
        ["moodboardWeights": weights]
    }
}
