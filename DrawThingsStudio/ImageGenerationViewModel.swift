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

    @Published var generatedImages: [GeneratedImage] = []
    @Published var selectedImage: GeneratedImage?

    @Published var connectionStatus: DrawThingsConnectionStatus = .disconnected
    @Published var errorMessage: String?

    // MARK: - img2img Source
    @Published var inputImage: NSImage?
    @Published var inputImageName: String?

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

                var generationConfig = config
                generationConfig.negativePrompt = negativePrompt

                let images = try await client.generateImage(
                    prompt: prompt,
                    sourceImage: inputImage,
                    mask: nil,
                    config: generationConfig,
                    onProgress: { [weak self] progress in
                        self?.progress = progress
                        self?.progressFraction = progress.fraction
                    }
                )

                guard !images.isEmpty else {
                    let mode = inputImage != nil ? "img2img" : "txt2img"
                    errorMessage = "No images returned from Draw Things (\(mode)). Check that the model supports this mode and that Draw Things is ready."
                    progress = .failed("No images returned")
                    isGenerating = false
                    return
                }

                // Save generated images
                for image in images {
                    if let saved = storageManager.saveImage(
                        image,
                        prompt: prompt,
                        negativePrompt: negativePrompt,
                        config: generationConfig,
                        inferenceTimeMs: nil
                    ) {
                        generatedImages.insert(saved, at: 0)
                        if selectedImage == nil {
                            selectedImage = saved
                        }
                    }
                }

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
