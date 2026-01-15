//
//  StoryflowInstructionGenerator.swift
//  DrawThingsStudio
//
//  Generator for creating StoryFlow instruction sequences
//

import Foundation

/// Generates StoryFlow instruction arrays for various workflow types
class StoryflowInstructionGenerator {

    // MARK: - Simple Sequences

    /// Generate a simple sequence with prompts and saves
    /// - Parameters:
    ///   - prompts: Array of prompt strings
    ///   - config: Draw Things configuration
    ///   - outputPrefix: Prefix for output files (default: "scene_")
    /// - Returns: Array of instruction dictionaries
    func generateSimpleSequence(
        prompts: [String],
        config: DrawThingsConfig,
        outputPrefix: String = "scene_"
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []

        // Add initial config
        instructions.append(ConfigInstruction(config: config).instructionDict)

        // Add each prompt with save
        for (index, prompt) in prompts.enumerated() {
            instructions.append(PromptInstruction(prompt: prompt).instructionDict)
            instructions.append(CanvasSaveInstruction(canvasSave: "\(outputPrefix)\(index).png").instructionDict)
        }

        return instructions
    }

    /// Generate a simple sequence with prompts, negative prompt, and saves
    func generateSimpleSequence(
        prompts: [String],
        negativePrompt: String,
        config: DrawThingsConfig,
        outputPrefix: String = "scene_"
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []

        // Add initial config and negative prompt
        instructions.append(ConfigInstruction(config: config).instructionDict)
        instructions.append(NegativePromptInstruction(negPrompt: negativePrompt).instructionDict)

        // Add each prompt with save
        for (index, prompt) in prompts.enumerated() {
            instructions.append(PromptInstruction(prompt: prompt).instructionDict)
            instructions.append(CanvasSaveInstruction(canvasSave: "\(outputPrefix)\(index).png").instructionDict)
        }

        return instructions
    }

    // MARK: - Batch Variations

    /// Generate batch variations using a loop
    /// - Parameters:
    ///   - basePrompt: The base prompt to vary
    ///   - variationCount: Number of variations to generate
    ///   - config: Draw Things configuration
    ///   - outputPrefix: Prefix for output files
    /// - Returns: Array of instruction dictionaries
    func generateBatchVariations(
        basePrompt: String,
        variationCount: Int,
        config: DrawThingsConfig,
        outputPrefix: String = "variation_"
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []

        // Setup
        instructions.append(NoteInstruction(note: "Batch variations: \(variationCount) versions").instructionDict)
        instructions.append(ConfigInstruction(config: config).instructionDict)
        instructions.append(PromptInstruction(prompt: basePrompt).instructionDict)

        // Loop through variations
        instructions.append(LoopInstruction(count: variationCount, start: 0).instructionDict)
        instructions.append(LoopSaveInstruction(prefix: outputPrefix).instructionDict)
        instructions.append(LoopEndInstruction().instructionDict)

        return instructions
    }

    /// Generate batch variations with explicit variation prompts
    func generateBatchVariations(
        basePrompt: String,
        variations: [String],
        config: DrawThingsConfig,
        outputPrefix: String = "variation_"
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []

        // Setup
        instructions.append(NoteInstruction(note: "Batch variations: \(variations.count) versions").instructionDict)
        instructions.append(ConfigInstruction(config: config).instructionDict)

        // Each variation as separate prompt/save
        for (index, variation) in variations.enumerated() {
            let fullPrompt = variation.isEmpty ? basePrompt : "\(basePrompt), \(variation)"
            instructions.append(PromptInstruction(prompt: fullPrompt).instructionDict)
            instructions.append(CanvasSaveInstruction(canvasSave: "\(outputPrefix)\(index).png").instructionDict)
        }

        return instructions
    }

    // MARK: - Animation Sequences

    /// Generate animation keyframes sequence
    /// - Parameters:
    ///   - startPrompt: Starting prompt for animation
    ///   - endPrompt: Ending prompt for animation
    ///   - frames: Number of frames
    ///   - config: Draw Things configuration
    /// - Returns: Array of instruction dictionaries
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

        // Generate with start prompt (interpolation would be handled externally)
        instructions.append(PromptInstruction(prompt: startPrompt).instructionDict)
        instructions.append(CanvasSaveInstruction(canvasSave: "animation.png").instructionDict)

        return instructions
    }

    /// Generate animation from input frames folder
    func generateAnimationFromFrames(
        inputFolder: String,
        frameCount: Int,
        prompt: String,
        config: DrawThingsConfig,
        outputPrefix: String = "enhanced_frame_"
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []

        instructions.append(NoteInstruction(note: "Process \(frameCount) animation frames").instructionDict)
        instructions.append(ConfigInstruction(config: config).instructionDict)
        instructions.append(PromptInstruction(prompt: prompt).instructionDict)

        // Loop through input frames
        instructions.append(LoopInstruction(count: frameCount, start: 0).instructionDict)
        instructions.append(LoopLoadInstruction(folderName: inputFolder).instructionDict)
        instructions.append(LoopSaveInstruction(prefix: outputPrefix).instructionDict)
        instructions.append(LoopEndInstruction().instructionDict)

        return instructions
    }

    // MARK: - Story Sequences

    /// Generate story sequence with scene transitions
    /// - Parameters:
    ///   - scenes: Array of tuples containing prompt and optional config override
    ///   - outputPrefix: Prefix for output files
    /// - Returns: Array of instruction dictionaries
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

    /// Generate story sequence with base config and simple prompts
    func generateStorySequence(
        prompts: [String],
        config: DrawThingsConfig,
        outputPrefix: String = "scene_"
    ) -> [[String: Any]] {
        let scenes = prompts.map { (prompt: $0, config: nil as DrawThingsConfig?) }

        var instructions: [[String: Any]] = []
        instructions.append(ConfigInstruction(config: config).instructionDict)
        instructions.append(contentsOf: generateStorySequence(scenes: scenes, outputPrefix: outputPrefix).dropFirst())

        return instructions
    }

    // MARK: - Character Consistency Workflows

    /// Generate workflow with character consistency using moodboard
    /// - Parameters:
    ///   - characterDescription: Detailed character description prompt
    ///   - scenes: Scene prompts that will include the character
    ///   - config: Draw Things configuration
    /// - Returns: Array of instruction dictionaries
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

        // Add to moodboard for reference
        instructions.append(MoodboardClearInstruction().instructionDict)
        instructions.append(MoodboardCanvasInstruction().instructionDict)
        instructions.append(MoodboardWeightsInstruction(weights: [0: 1.0]).instructionDict)

        // Generate each scene with moodboard reference
        for (index, scenePrompt) in scenes.enumerated() {
            instructions.append(PromptInstruction(prompt: "\(characterDescription), \(scenePrompt)").instructionDict)
            instructions.append(CanvasSaveInstruction(canvasSave: "scene_\(index + 1).png").instructionDict)
        }

        return instructions
    }

    /// Generate workflow with multiple reference images for consistency
    func generateMultiReferenceWorkflow(
        referenceImages: [String],
        referenceWeights: [Float],
        scenes: [String],
        config: DrawThingsConfig
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []

        instructions.append(NoteInstruction(note: "Multi-reference consistency workflow").instructionDict)
        instructions.append(ConfigInstruction(config: config).instructionDict)

        // Setup moodboard with reference images
        instructions.append(MoodboardClearInstruction().instructionDict)
        for image in referenceImages {
            instructions.append(MoodboardAddInstruction(moodboardAdd: image).instructionDict)
        }

        // Set weights
        var weights: [Int: Float] = [:]
        for (index, weight) in referenceWeights.enumerated() {
            weights[index] = weight
        }
        instructions.append(MoodboardWeightsInstruction(weights: weights).instructionDict)

        // Generate scenes
        for (index, prompt) in scenes.enumerated() {
            instructions.append(PromptInstruction(prompt: prompt).instructionDict)
            instructions.append(CanvasSaveInstruction(canvasSave: "scene_\(index + 1).png").instructionDict)
        }

        return instructions
    }

    // MARK: - Img2Img Workflows

    /// Generate img2img workflow from input image
    func generateImg2ImgWorkflow(
        inputImage: String,
        prompt: String,
        strength: Float,
        config: DrawThingsConfig
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []

        instructions.append(NoteInstruction(note: "Img2Img workflow").instructionDict)

        var img2imgConfig = config
        img2imgConfig.strength = strength
        instructions.append(ConfigInstruction(config: img2imgConfig).instructionDict)

        instructions.append(CanvasLoadInstruction(canvasLoad: inputImage).instructionDict)
        instructions.append(PromptInstruction(prompt: prompt).instructionDict)
        instructions.append(CanvasSaveInstruction(canvasSave: "img2img_result.png").instructionDict)

        return instructions
    }

    /// Generate batch img2img from folder
    func generateBatchImg2Img(
        inputFolder: String,
        imageCount: Int,
        prompt: String,
        strength: Float,
        config: DrawThingsConfig,
        outputPrefix: String = "processed_"
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []

        instructions.append(NoteInstruction(note: "Batch img2img: \(imageCount) images").instructionDict)

        var img2imgConfig = config
        img2imgConfig.strength = strength
        instructions.append(ConfigInstruction(config: img2imgConfig).instructionDict)
        instructions.append(PromptInstruction(prompt: prompt).instructionDict)

        instructions.append(LoopInstruction(count: imageCount, start: 0).instructionDict)
        instructions.append(LoopLoadInstruction(folderName: inputFolder).instructionDict)
        instructions.append(LoopSaveInstruction(prefix: outputPrefix).instructionDict)
        instructions.append(LoopEndInstruction().instructionDict)

        return instructions
    }

    // MARK: - Inpainting Workflows

    /// Generate inpainting workflow with mask
    func generateInpaintingWorkflow(
        inputImage: String,
        maskImage: String,
        prompt: String,
        inpaintConfig: InpaintToolsConfig,
        config: DrawThingsConfig
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []

        instructions.append(NoteInstruction(note: "Inpainting workflow").instructionDict)
        instructions.append(ConfigInstruction(config: config).instructionDict)
        instructions.append(InpaintToolsInstruction(
            strength: inpaintConfig.strength,
            maskBlur: inpaintConfig.maskBlur,
            maskBlurOutset: inpaintConfig.maskBlurOutset,
            restoreOriginalAfterInpaint: inpaintConfig.restoreOriginalAfterInpaint
        ).instructionDict)

        instructions.append(CanvasLoadInstruction(canvasLoad: inputImage).instructionDict)
        instructions.append(MaskLoadInstruction(maskLoad: maskImage).instructionDict)
        instructions.append(PromptInstruction(prompt: prompt).instructionDict)
        instructions.append(CanvasSaveInstruction(canvasSave: "inpaint_result.png").instructionDict)

        return instructions
    }

    /// Generate AI-mask inpainting workflow
    func generateAIMaskInpaintWorkflow(
        inputImage: String,
        maskDescription: String,
        prompt: String,
        inpaintStrength: Float,
        config: DrawThingsConfig
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []

        instructions.append(NoteInstruction(note: "AI-mask inpainting workflow").instructionDict)
        instructions.append(ConfigInstruction(config: config).instructionDict)
        instructions.append(InpaintToolsInstruction(strength: inpaintStrength).instructionDict)

        instructions.append(CanvasLoadInstruction(canvasLoad: inputImage).instructionDict)
        instructions.append(MaskAskInstruction(description: maskDescription).instructionDict)
        instructions.append(PromptInstruction(prompt: prompt).instructionDict)
        instructions.append(CanvasSaveInstruction(canvasSave: "ai_inpaint_result.png").instructionDict)

        return instructions
    }

    // MARK: - Background Replacement

    /// Generate background replacement workflow
    func generateBackgroundReplacementWorkflow(
        inputImage: String,
        newBackgroundPrompt: String,
        config: DrawThingsConfig
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []

        instructions.append(NoteInstruction(note: "Background replacement workflow").instructionDict)
        instructions.append(ConfigInstruction(config: config).instructionDict)

        instructions.append(CanvasLoadInstruction(canvasLoad: inputImage).instructionDict)
        instructions.append(MaskBackgroundInstruction().instructionDict)
        instructions.append(PromptInstruction(prompt: newBackgroundPrompt).instructionDict)
        instructions.append(CanvasSaveInstruction(canvasSave: "new_background.png").instructionDict)

        return instructions
    }

    // MARK: - Depth-based Workflows

    /// Generate depth-guided workflow
    func generateDepthGuidedWorkflow(
        inputImage: String,
        prompt: String,
        config: DrawThingsConfig
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []

        instructions.append(NoteInstruction(note: "Depth-guided generation").instructionDict)
        instructions.append(ConfigInstruction(config: config).instructionDict)

        instructions.append(CanvasLoadInstruction(canvasLoad: inputImage).instructionDict)
        instructions.append(DepthExtractInstruction().instructionDict)
        instructions.append(PromptInstruction(prompt: prompt).instructionDict)
        instructions.append(CanvasSaveInstruction(canvasSave: "depth_guided_result.png").instructionDict)

        return instructions
    }

    // MARK: - Face Operations

    /// Generate face zoom and enhance workflow
    func generateFaceEnhanceWorkflow(
        inputImage: String,
        facePrompt: String,
        config: DrawThingsConfig
    ) -> [[String: Any]] {
        var instructions: [[String: Any]] = []

        instructions.append(NoteInstruction(note: "Face enhancement workflow").instructionDict)
        instructions.append(ConfigInstruction(config: config).instructionDict)

        instructions.append(CanvasLoadInstruction(canvasLoad: inputImage).instructionDict)
        instructions.append(FaceZoomInstruction().instructionDict)
        instructions.append(PromptInstruction(prompt: facePrompt).instructionDict)
        instructions.append(CanvasSaveInstruction(canvasSave: "face_enhanced.png").instructionDict)

        return instructions
    }

    // MARK: - Utility Methods

    /// Add a note to instruction array
    func addNote(_ note: String, to instructions: inout [[String: Any]]) {
        instructions.insert(NoteInstruction(note: note).instructionDict, at: 0)
    }

    /// Wrap instructions in a loop
    func wrapInLoop(
        instructions: [[String: Any]],
        count: Int,
        start: Int = 0,
        outputPrefix: String? = nil
    ) -> [[String: Any]] {
        var wrapped: [[String: Any]] = []

        wrapped.append(LoopInstruction(count: count, start: start).instructionDict)
        wrapped.append(contentsOf: instructions)

        if let prefix = outputPrefix {
            wrapped.append(LoopSaveInstruction(prefix: prefix).instructionDict)
        }

        wrapped.append(LoopEndInstruction().instructionDict)

        return wrapped
    }

    /// Combine multiple instruction arrays into one workflow
    func combineWorkflows(_ workflows: [[String: Any]]...) -> [[String: Any]] {
        var combined: [[String: Any]] = []
        for workflow in workflows {
            combined.append(contentsOf: workflow)
        }
        return combined
    }
}
