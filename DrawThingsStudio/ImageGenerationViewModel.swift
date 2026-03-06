//
//  ImageGenerationViewModel.swift
//  DrawThingsStudio
//
//  ViewModel for image generation state management
//

import Foundation
import AppKit
import Combine
import OSLog
import SwiftUI

// MARK: - Generation Step

/// A single step in a multi-step generation pipeline.
struct GenerationStep: Identifiable {
    var id = UUID()
    var name: String
    var prompt: String = ""
    var negativePrompt: String = ""
    var config: DrawThingsGenerationConfig = DrawThingsGenerationConfig()
    var useOutputFromPreviousStep: Bool = false
    var strength: Double = 1.0   // img2img chain strength; 1.0 = full denoising (txt2img)
    var resultImages: [GeneratedImage] = []
    var isRunning: Bool = false
}

/// ViewModel managing Draw Things image generation state
@MainActor
final class ImageGenerationViewModel: ObservableObject {

    private let logger = Logger(subsystem: "com.drawthingsstudio", category: "image-generation")

    // MARK: - Published State

    @Published var prompt: String = ""
    @Published var negativePrompt: String = ""
    @Published var config = DrawThingsGenerationConfig()

    @Published var isGenerating = false
    @Published var progress: GenerationProgress = .starting
    @Published var progressFraction: Double = 0
    @Published var generationImageLabel: String = ""

    @Published var generatedImages: [GeneratedImage] = []
    @Published var selectedImage: GeneratedImage?

    @Published var connectionStatus: DrawThingsConnectionStatus = .disconnected
    @Published var errorMessage: String?

    // MARK: - Prompt Enhancement
    @Published var isEnhancing: Bool = false

    // MARK: - img2img Source
    @Published var inputImage: NSImage?
    @Published var inputImageName: String?

    // MARK: - Pipeline Steps

    @Published var steps: [GenerationStep] = [GenerationStep(name: "Step 1")]
    @Published var selectedStepIndex: Int = 0

    // MARK: - Private

    private var client: (any DrawThingsProvider)?
    private var generationTask: Task<Void, Never>?
    private let storageManager = ImageStorageManager.shared

    // MARK: - Initialization

    init() {
        loadSavedImages()
    }

    // MARK: - Connection

    func checkConnection() async {
        let settings = AppSettings.shared
        client = settings.createDrawThingsClient()
        connectionStatus = .connecting

        guard let client = client else {
            connectionStatus = .error("No client configured")
            return
        }

        let connected = await client.checkConnection()
        connectionStatus = connected ? .connected : .error("Cannot reach Draw Things at configured address")
    }

    // MARK: - Generation

    func generate() {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a prompt"
            return
        }

        guard !config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please specify a model (enter manually or refresh from Draw Things)"
            return
        }

        guard !isGenerating else { return }

        errorMessage = nil
        isGenerating = true
        progressFraction = 0
        progress = .starting

        generationTask = Task {
            do {
                let settings = AppSettings.shared
                if client == nil {
                    client = settings.createDrawThingsClient()
                }

                guard let client = client else {
                    throw DrawThingsError.connectionFailed("No client available")
                }

                // Check connection first
                let connected = await client.checkConnection()
                guard connected else {
                    throw DrawThingsError.connectionFailed("Draw Things is not reachable")
                }
                connectionStatus = .connected

                // DTS controls iteration count; always send batchCount=1 to Draw Things
                // so its local batch setting is overridden by the single-image request.
                var generationConfig = config
                generationConfig.negativePrompt = negativePrompt
                generationConfig.batchCount = 1
                generationConfig.batchSize = 1
                // If no source image, force strength=1.0 so Draw Things runs txt2img.
                // A leftover strength<1.0 (from a prior img2img session) would otherwise
                // tell Draw Things to denoise pure noise → static output.
                if inputImage == nil {
                    generationConfig.strength = 1.0
                }

                let totalImages = max(1, config.batchCount)
                var totalSaved = 0

                for imageIndex in 1...totalImages {
                    try Task.checkCancellation()

                    if totalImages > 1 {
                        generationImageLabel = "Image \(imageIndex) of \(totalImages)"
                    } else {
                        generationImageLabel = ""
                    }
                    progressFraction = Double(imageIndex - 1) / Double(totalImages)

                    let images = try await client.generateImage(
                        prompt: prompt,
                        sourceImage: inputImage,
                        mask: nil,
                        config: generationConfig,
                        onProgress: { [weak self] prog in
                            guard let self else { return }
                            self.progress = prog
                            // Scale fraction within this image's slice
                            let base = Double(imageIndex - 1) / Double(totalImages)
                            let slice = 1.0 / Double(totalImages)
                            self.progressFraction = base + prog.fraction * slice
                        }
                    )

                    guard !images.isEmpty else {
                        errorMessage = "No images returned for image \(imageIndex). Check that the model is ready."
                        progress = .failed("No images returned")
                        isGenerating = false
                        generationImageLabel = ""
                        return
                    }

                    // Draw Things may ignore batchCount=1 and return multiple images
                    // (using its own local batch setting). Only collect as many as still
                    // needed to reach the user's requested total.
                    let remaining = totalImages - totalSaved
                    for image in images.prefix(remaining) {
                        // Ensure the NSImage has a valid bitmap representation before saving.
                        // Images from gRPC may arrive as CGImage-backed NSImages; force a
                        // concrete bitmap rep so tiffRepresentation doesn't return nil.
                        let saveImage: NSImage
                        if image.tiffRepresentation == nil,
                           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                            let rep = NSBitmapImageRep(cgImage: cgImage)
                            let rebuilt = NSImage(size: image.size)
                            rebuilt.addRepresentation(rep)
                            saveImage = rebuilt
                        } else {
                            saveImage = image
                        }

                        if let saved = storageManager.saveImage(
                            saveImage,
                            prompt: prompt,
                            negativePrompt: negativePrompt,
                            config: generationConfig,
                            inferenceTimeMs: nil
                        ) {
                            generatedImages.insert(saved, at: 0)
                            if selectedImage == nil {
                                selectedImage = saved
                            }
                            totalSaved += 1
                        }
                    }

                    // If DT returned enough images to satisfy the full request in one
                    // call (e.g. its local batch count ≥ totalImages), stop early.
                    if totalSaved >= totalImages {
                        break
                    }
                }

                if totalSaved == 0 {
                    errorMessage = "Image(s) were generated but could not be saved or displayed. Check Console.app for details."
                }

                generationImageLabel = ""
                progress = .complete
                progressFraction = 1.0

            } catch is CancellationError {
                progress = .failed("Cancelled")
                errorMessage = "Generation was cancelled"
            } catch let error as DrawThingsError {
                progress = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
                connectionStatus = .error(error.localizedDescription)
            } catch {
                progress = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
            }

            isGenerating = false
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        progress = .failed("Cancelled")
    }

    // MARK: - Pipeline Step Management

    /// Saves live state into the current step, then loads the new step's state.
    func switchStep(to index: Int) {
        guard index >= 0, index < steps.count else { return }
        // Save current live state back to the current step
        syncCurrentStepState()
        // Load the new step's state into live properties
        selectedStepIndex = index
        prompt = steps[index].prompt
        negativePrompt = steps[index].negativePrompt
        config = steps[index].config
        generatedImages = steps[index].resultImages
        selectedImage = generatedImages.first
        inputImage = nil
        inputImageName = nil
    }

    /// Persists the current live state into `steps[selectedStepIndex]` without switching.
    func syncCurrentStepState() {
        guard selectedStepIndex < steps.count else { return }
        steps[selectedStepIndex].prompt = prompt
        steps[selectedStepIndex].negativePrompt = negativePrompt
        steps[selectedStepIndex].config = config
        steps[selectedStepIndex].resultImages = generatedImages
    }

    /// Appends a new step inheriting the current model, then switches to it.
    func addStep() {
        syncCurrentStepState()
        var newStep = GenerationStep(name: "Step \(steps.count + 1)")
        newStep.config.model = config.model
        newStep.config.width = config.width
        newStep.config.height = config.height
        newStep.config.sampler = config.sampler
        newStep.useOutputFromPreviousStep = true
        steps.append(newStep)
        switchStep(to: steps.count - 1)
    }

    /// Removes the step at `index`. Requires at least 2 steps.
    func removeStep(at index: Int) {
        guard steps.count > 1, index >= 0, index < steps.count else { return }
        syncCurrentStepState()
        steps.remove(at: index)
        // Ensure first step never chains from previous
        steps[steps.startIndex].useOutputFromPreviousStep = false
        // Re-number steps with default names
        for i in steps.indices where steps[i].name.hasPrefix("Step ") {
            steps[i].name = "Step \(i + 1)"
        }
        let newIndex = max(0, min(selectedStepIndex, steps.count - 1))
        // Use direct assignment to avoid double-save
        selectedStepIndex = newIndex
        prompt = steps[newIndex].prompt
        negativePrompt = steps[newIndex].negativePrompt
        config = steps[newIndex].config
        generatedImages = steps[newIndex].resultImages
        selectedImage = generatedImages.first
        inputImage = nil
        inputImageName = nil
    }

    func moveSteps(from: IndexSet, to: Int) {
        syncCurrentStepState()
        steps.move(fromOffsets: from, toOffset: to)
        steps[steps.startIndex].useOutputFromPreviousStep = false
        // Clamp selectedStepIndex
        selectedStepIndex = max(0, min(selectedStepIndex, steps.count - 1))
    }

    /// Runs all steps sequentially, threading previous step output as img2img source.
    func runPipeline() {
        guard !isGenerating else { return }
        syncCurrentStepState()
        errorMessage = nil
        isGenerating = true
        progressFraction = 0
        progress = .starting

        generationTask = Task {
            do {
                let settings = AppSettings.shared
                if client == nil { client = settings.createDrawThingsClient() }
                guard let client else { throw DrawThingsError.connectionFailed("No client available") }
                let connected = await client.checkConnection()
                guard connected else { throw DrawThingsError.connectionFailed("Draw Things is not reachable") }
                connectionStatus = .connected

                var previousImage: NSImage? = nil

                for index in steps.indices {
                    try Task.checkCancellation()

                    // Update UI to show current step running
                    steps[index].isRunning = true
                    generationImageLabel = steps.count > 1 ? "Step \(index + 1) of \(steps.count)" : ""
                    progressFraction = Double(index) / Double(steps.count)

                    // If step 0 has a manual inputImage set (img2img), use it
                    let sourceImage: NSImage?
                    if steps[index].useOutputFromPreviousStep && index > 0 {
                        sourceImage = previousImage
                    } else if index == 0 {
                        sourceImage = inputImage
                    } else {
                        sourceImage = nil
                    }

                    var stepConfig = steps[index].config
                    stepConfig.negativePrompt = steps[index].negativePrompt
                    stepConfig.batchCount = 1
                    stepConfig.batchSize = 1
                    // Always set strength explicitly: img2img value when chaining, 1.0 otherwise.
                    // Never rely on a leftover value in config — it could trigger accidental
                    // img2img denoising (pure noise input → static output).
                    if steps[index].useOutputFromPreviousStep && sourceImage != nil {
                        stepConfig.strength = steps[index].strength
                    } else {
                        stepConfig.strength = 1.0
                    }

                    let images = try await client.generateImage(
                        prompt: steps[index].prompt,
                        sourceImage: sourceImage,
                        mask: nil,
                        config: stepConfig,
                        onProgress: { [weak self] prog in
                            guard let self else { return }
                            let base = Double(index) / Double(self.steps.count)
                            let slice = 1.0 / Double(self.steps.count)
                            self.progressFraction = base + prog.fraction * slice
                            self.progress = prog
                        }
                    )

                    steps[index].isRunning = false

                    guard let firstImage = images.first else {
                        errorMessage = "No image returned for Step \(index + 1)"
                        progress = .failed("No images returned")
                        isGenerating = false
                        generationImageLabel = ""
                        return
                    }

                    // Ensure valid bitmap rep before saving
                    let saveImage: NSImage
                    if firstImage.tiffRepresentation == nil,
                       let cgImage = firstImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        let rep = NSBitmapImageRep(cgImage: cgImage)
                        let rebuilt = NSImage(size: firstImage.size)
                        rebuilt.addRepresentation(rep)
                        saveImage = rebuilt
                    } else {
                        saveImage = firstImage
                    }

                    previousImage = saveImage

                    // Save result
                    if let saved = storageManager.saveImage(
                        saveImage,
                        prompt: steps[index].prompt,
                        negativePrompt: steps[index].negativePrompt,
                        config: stepConfig,
                        inferenceTimeMs: nil
                    ) {
                        steps[index].resultImages.insert(saved, at: 0)
                        // If this is the currently-selected step, also update live gallery
                        if index == selectedStepIndex {
                            generatedImages.insert(saved, at: 0)
                            if selectedImage == nil { selectedImage = saved }
                        }
                    }
                }

                generationImageLabel = ""
                progress = .complete
                progressFraction = 1.0

            } catch is CancellationError {
                for i in steps.indices { steps[i].isRunning = false }
                progress = .failed("Cancelled")
                errorMessage = "Generation was cancelled"
            } catch let error as DrawThingsError {
                for i in steps.indices { steps[i].isRunning = false }
                progress = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
                connectionStatus = .error(error.localizedDescription)
            } catch {
                for i in steps.indices { steps[i].isRunning = false }
                progress = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
            }

            isGenerating = false
        }
    }

    /// Dispatches to `runPipeline()` for multi-step, or `generate()` for single-step.
    func generateOrRunPipeline() {
        if steps.count > 1 {
            runPipeline()
        } else {
            generate()
        }
    }

    // MARK: - Image Management

    func deleteImage(_ image: GeneratedImage) {
        storageManager.deleteImage(image)
        generatedImages.removeAll { $0.id == image.id }
        if selectedImage?.id == image.id {
            selectedImage = generatedImages.first
        }
    }

    func revealInFinder(_ image: GeneratedImage) {
        storageManager.revealInFinder(image)
    }

    func copyToClipboard(_ image: GeneratedImage) {
        storageManager.copyToClipboard(image.image)
    }

    func openOutputFolder() {
        storageManager.openStorageDirectory()
    }

    // MARK: - Pipeline Persistence

    /// Encodes current pipeline steps as JSON data for saving to a SavedPipeline.
    func encodedSteps() -> Data? {
        syncCurrentStepState()
        let codable = steps.map { CodablePipelineStep(from: $0) }
        return try? JSONEncoder().encode(codable)
    }

    /// Loads pipeline steps from previously-encoded data, replacing the current pipeline.
    func loadSteps(from data: Data) {
        guard let codable = try? JSONDecoder().decode([CodablePipelineStep].self, from: data),
              !codable.isEmpty else { return }
        steps = codable.map { $0.toGenerationStep() }
        generatedImages = []
        selectedImage = nil
        inputImage = nil
        inputImageName = nil
        switchStep(to: 0)
    }

    // MARK: - img2img Source

    func loadInputImage(from url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            errorMessage = "Failed to load image from \(url.lastPathComponent)"
            return
        }
        inputImage = image
        inputImageName = url.lastPathComponent
        // Default strength for img2img if currently at 1.0 (txt2img default)
        if config.strength >= 1.0 {
            config.strength = 0.7
        }
    }

    func loadInputImage(from image: NSImage, name: String) {
        inputImage = image
        inputImageName = name
        if config.strength >= 1.0 {
            config.strength = 0.7
        }
    }

    func clearInputImage() {
        inputImage = nil
        inputImageName = nil
        config.strength = 1.0  // back to full denoising (txt2img)
    }

    // MARK: - Prompt Enhancement

    func enhancePrompt(_ prompt: String, customStyle: CustomPromptStyle) async throws -> String {
        isEnhancing = true
        defer { isEnhancing = false }

        let settings = AppSettings.shared
        let client = settings.createLLMClient()
        let connected = await client.checkConnection()

        let providerName = settings.providerType.displayName
        guard connected else {
            throw LLMError.connectionFailed("Could not connect to \(providerName). Check settings.")
        }

        let generator = WorkflowPromptGenerator(llmClient: client)
        return try await generator.enhancePrompt(concept: prompt, systemPrompt: customStyle.systemPrompt)
    }

    // MARK: - Preset Loading

    func loadPreset(_ modelConfig: ModelConfig) {
        config.width = modelConfig.width
        config.height = modelConfig.height
        config.steps = modelConfig.steps
        config.guidanceScale = Double(modelConfig.guidanceScale)
        config.sampler = modelConfig.samplerName
        if let shift = modelConfig.shift {
            config.shift = Double(shift)
        }
        if let strength = modelConfig.strength {
            config.strength = Double(strength)
        }
        config.stochasticSamplingGamma = Double(modelConfig.stochasticSamplingGamma ?? 0.3)
        config.model = modelConfig.modelName
        if let seedMode = modelConfig.seedMode {
            config.seedMode = SeedModeMapping.name(for: seedMode)
        }
        config.resolutionDependentShift = modelConfig.resolutionDependentShift
        config.cfgZeroStar = modelConfig.cfgZeroStar
    }

    // MARK: - Private

    private func loadSavedImages() {
        storageManager.loadSavedImages()
        generatedImages = storageManager.savedImages
        selectedImage = generatedImages.first
    }
}
