import Foundation

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
        // For strict loop compliance, the loop iterates but usually you want params to change.
        // StoryFlow loop logic usually implies some external iterator or folder loading.
        // If we want explict prompts per iteration, we might not use the StoryFlow 'loop' instruction
        // but rather just unroll the loop in JSON.
        // However, the spec example had a loop.
        // The spec implies: 
        /*
          { "loop": { "loop": 5, "start": 0 } },
          { "loopSave": "variation_" },
          { "loopEnd": true }
        */ 
        // Loops in StoryFlow are useful if you are iterating seeds or loading files. 
        // If we are just changing prompt text, unrolling is safer unless we use wildcards.
        // I will follow the spec's simpler "loop" example where it iterates seeds implicitly or similar.
        
        // But the spec method signature takes `variations: [String]`.
        // If we have distinct prompts, we should probably unroll.
        // I will implement unrolling for robustness here despite the method name implying a 'loop' structure unless standard loop handles list variable.
        // Re-reading spec example 5.2: it uses a single prompt inside the loop.
        // "A cyberpunk street scene..."
        // So it likely iterates seeds.
        
        // If we want to use the specific `variations` strings, we must unroll OR use a hypothetical "list" feature.
        // I will IMPLEMENT UNROLLING as it is safer and supported by any linear executor.
        // WAIT, the spec has `generateBatchVariations` returning `[[String: Any]]`.
        
        // Let's implement unrolling for distinct prompts.
        
        for (index, variation) in variations.enumerated() {
             instructions.append(PromptInstruction(prompt: "\(basePrompt), \(variation)").instructionDict)
             instructions.append(CanvasSaveInstruction(canvasSave: "variation_\(index).png").instructionDict)
        }
        
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
        instructions.append(MoodboardClearInstruction().instructionDict)
        instructions.append(MoodboardCanvasInstruction().instructionDict)
        
        // Generate each scene with moodboard reference
        for (index, scenePrompt) in scenes.enumerated() {
            instructions.append(PromptInstruction(prompt: "\(characterDescription), \(scenePrompt)").instructionDict)
            instructions.append(CanvasSaveInstruction(canvasSave: "scene_\(index + 1).png").instructionDict)
        }
        
        return instructions
    }
}
