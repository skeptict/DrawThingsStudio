//
//  ImageStorageManager.swift
//  DrawThingsStudio
//
//  Manages auto-saving generated images to ~/Pictures/DrawThingsStudio/
//

import Foundation
import AppKit
import Combine
import OSLog

/// Manages persistent storage of generated images and their metadata
@MainActor
final class ImageStorageManager: ObservableObject {
    static let shared = ImageStorageManager()

    private let logger = Logger(subsystem: "com.drawthingsstudio", category: "image-storage")

    private let storageDirectory: URL

    @Published var savedImages: [GeneratedImage] = []

    // MARK: - Initialization

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.storageDirectory = appSupport.appendingPathComponent("DrawThingsStudio/GeneratedImages", isDirectory: true)
        ensureDirectoryExists()
    }

    // MARK: - Public Methods

    /// Save a generated image to disk with metadata sidecar
    func saveImage(_ image: NSImage, prompt: String, negativePrompt: String, config: DrawThingsGenerationConfig, inferenceTimeMs: Int?) -> GeneratedImage? {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "T", with: "_")
        let filename = "gen_\(timestamp)_\(UUID().uuidString.prefix(8))"

        let imageURL = storageDirectory.appendingPathComponent("\(filename).png")
        let metadataURL = storageDirectory.appendingPathComponent("\(filename).json")

        // Save PNG
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            logger.error("Failed to convert image to PNG data")
            return nil
        }

        do {
            try pngData.write(to: imageURL)
        } catch {
            logger.error("Failed to write image file: \(error.localizedDescription)")
            return nil
        }

        // Save metadata sidecar
        let metadata = ImageMetadata(
            prompt: prompt,
            negativePrompt: negativePrompt,
            config: config,
            generatedAt: Date(),
            inferenceTimeMs: inferenceTimeMs
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(metadata)
            try jsonData.write(to: metadataURL)
        } catch {
            logger.warning("Failed to write metadata file: \(error.localizedDescription)")
            // Non-fatal: image is saved even without metadata
        }

        let generatedImage = GeneratedImage(
            image: image,
            prompt: prompt,
            negativePrompt: negativePrompt,
            config: config,
            generatedAt: Date(),
            inferenceTimeMs: inferenceTimeMs,
            filePath: imageURL
        )

        savedImages.insert(generatedImage, at: 0)
        logger.info("Saved image to \(imageURL.path)")
        return generatedImage
    }

    /// Load previously saved images from disk
    func loadSavedImages() {
        ensureDirectoryExists()

        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let pngFiles = files
            .filter { $0.pathExtension == "png" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }

        var loaded: [GeneratedImage] = []
        for pngURL in pngFiles {
            guard let image = NSImage(contentsOf: pngURL) else { continue }

            let metadataURL = pngURL.deletingPathExtension().appendingPathExtension("json")
            var prompt = ""
            var negativePrompt = ""
            var config = DrawThingsGenerationConfig()
            var generatedAt = (try? pngURL.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            var inferenceTimeMs: Int?

            if let metadataData = try? Data(contentsOf: metadataURL),
               let metadata = try? JSONDecoder().decode(ImageMetadata.self, from: metadataData) {
                prompt = metadata.prompt
                negativePrompt = metadata.negativePrompt
                config = metadata.config
                generatedAt = metadata.generatedAt
                inferenceTimeMs = metadata.inferenceTimeMs
            }

            loaded.append(GeneratedImage(
                image: image,
                prompt: prompt,
                negativePrompt: negativePrompt,
                config: config,
                generatedAt: generatedAt,
                inferenceTimeMs: inferenceTimeMs,
                filePath: pngURL
            ))
        }

        savedImages = loaded
        logger.info("Loaded \(loaded.count) saved images from disk")
    }

    /// Delete a saved image and its metadata
    func deleteImage(_ generatedImage: GeneratedImage) {
        guard let filePath = generatedImage.filePath else { return }

        let fileManager = FileManager.default
        try? fileManager.removeItem(at: filePath)

        let metadataURL = filePath.deletingPathExtension().appendingPathExtension("json")
        try? fileManager.removeItem(at: metadataURL)

        savedImages.removeAll { $0.id == generatedImage.id }
        logger.info("Deleted image at \(filePath.path)")
    }

    /// Reveal image in Finder
    func revealInFinder(_ generatedImage: GeneratedImage) {
        guard let filePath = generatedImage.filePath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([filePath])
    }

    /// Copy image to clipboard
    func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    /// Open storage directory in Finder
    func openStorageDirectory() {
        NSWorkspace.shared.open(storageDirectory)
    }

    // MARK: - Private

    private func ensureDirectoryExists() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            do {
                try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
                logger.info("Created storage directory at \(self.storageDirectory.path)")
            } catch {
                logger.error("Failed to create storage directory: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Metadata Model

private struct ImageMetadata: Codable {
    let prompt: String
    let negativePrompt: String
    let config: DrawThingsGenerationConfig
    let generatedAt: Date
    let inferenceTimeMs: Int?
}
