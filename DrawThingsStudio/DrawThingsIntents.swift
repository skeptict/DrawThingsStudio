//
//  DrawThingsIntents.swift
//  DrawThingsStudio
//
//  AppIntents Phase 1: GenerateImageIntent + RunWorkflowIntent
//  Accessible via Shortcuts app and Siri voice commands.
//

import AppIntents
import AppKit
import SwiftData
import UniformTypeIdentifiers

// MARK: - Error Type

private struct DTIntentError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - Shared Image Helper

/// Encodes an NSImage as a PNG temp file. Handles gRPC CGImage-backed images
/// that lack a native tiffRepresentation.
private func saveImageAsPNG(_ image: NSImage, filename: String = "output") throws -> URL {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("png")

    let source: NSImage
    if image.tiffRepresentation == nil,
       let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let rebuilt = NSImage(size: image.size)
        rebuilt.addRepresentation(rep)
        source = rebuilt
    } else {
        source = image
    }

    guard let tiff = source.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw DTIntentError(message: "Failed to encode image as PNG.")
    }

    try png.write(to: tempURL)
    return tempURL
}

// MARK: - Generate Image Intent

/// Generates an image via Draw Things and returns it as a PNG file.
/// Add to Siri with a phrase like "Generate an image with Draw Things Studio".
struct GenerateImageIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate Image"
    static let description = IntentDescription(
        "Generate an AI image using Tanque Studio. Draw Things must be running.",
        categoryName: "Image Generation"
    )
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Prompt", description: "Describe the image you want to generate")
    var prompt: String

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let (client, config) = await MainActor.run {
            let settings = AppSettings.shared
            var cfg = DrawThingsGenerationConfig()
            cfg.width = settings.defaultWidth
            cfg.height = settings.defaultHeight
            return (settings.createDrawThingsClient(), cfg)
        }

        guard await client.checkConnection() else {
            throw DTIntentError(message:
                "Cannot reach Draw Things. Make sure it is running and the connection is configured in Draw Things Studio Settings."
            )
        }

        let images = try await client.generateImage(
            prompt: prompt,
            sourceImage: nil,
            mask: nil,
            config: config,
            onProgress: { _ in }
        )

        guard let image = images.first else {
            throw DTIntentError(message:
                "Draw Things returned no image. Check that a model is loaded in Draw Things."
            )
        }

        let fileURL = try saveImageAsPNG(image, filename: "generated")
        return .result(value: IntentFile(fileURL: fileURL, filename: "generated.png", type: .png))
    }
}

// MARK: - Run Workflow Intent

/// Executes a saved workflow from the library and returns the last generated image (if any).
/// Add to Siri with a phrase like "Run a workflow with Draw Things Studio".
struct RunWorkflowIntent: AppIntent {
    static let title: LocalizedStringResource = "Run Saved Workflow"
    static let description = IntentDescription(
        "Execute a saved workflow from Tanque Studio's library. Draw Things must be running.",
        categoryName: "Workflows"
    )
    static var openAppWhenRun: Bool = true

    @Parameter(
        title: "Workflow Name",
        description: "The exact name of the saved workflow to run (as shown in Saved Workflows)"
    )
    var workflowName: String

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<IntentFile?> {
        let jsonData = try fetchWorkflowJSON(named: workflowName)

        let instructions = await MainActor.run { WorkflowBuilderViewModel.parseInstructions(from: jsonData) }
        guard !instructions.isEmpty else {
            throw DTIntentError(message:
                "'\(workflowName)' could not be decoded or is empty. It may have been saved with an incompatible version."
            )
        }

        let (client, executor) = await MainActor.run {
            let c = AppSettings.shared.createDrawThingsClient()
            let e = StoryflowExecutor(provider: c)
            return (c, e)
        }

        guard await client.checkConnection() else {
            throw DTIntentError(message:
                "Cannot reach Draw Things. Make sure it is running before executing a workflow."
            )
        }

        let (result, images) = await Task { @MainActor in
            await executor.execute(instructions: instructions)
        }.value

        if !result.success, let errMsg = result.errorMessage {
            throw DTIntentError(message: "Workflow failed: \(errMsg)")
        }

        let summary = "Workflow '\(workflowName)' completed — \(result.generatedImageCount) image(s) generated."

        if let lastURL = images.last?.filePath {
            return .result(
                value: IntentFile(fileURL: lastURL, filename: lastURL.lastPathComponent, type: .png),
                dialog: IntentDialog(stringLiteral: summary)
            )
        }

        if let lastImage = images.last?.image,
           let tempURL = try? saveImageAsPNG(lastImage, filename: "workflow_output") {
            return .result(
                value: IntentFile(fileURL: tempURL, filename: "workflow_output.png", type: .png),
                dialog: IntentDialog(stringLiteral: summary)
            )
        }

        return .result(value: nil, dialog: IntentDialog(stringLiteral: summary))
    }

    // MARK: Private

    private func fetchWorkflowJSON(named name: String) throws -> Data {
        let schema = Schema(TanqueStudioSchema.models)
        let config = ModelConfiguration("TanqueStudio", schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<SavedWorkflow>(
                predicate: #Predicate { $0.name == name }
            )
            descriptor.fetchLimit = 1
            let results = try context.fetch(descriptor)
            guard let workflow = results.first else {
                throw DTIntentError(message:
                    "No saved workflow named '\(name)' was found. Check the exact name in Saved Workflows."
                )
            }
            return workflow.jsonData
        } catch let err as DTIntentError {
            throw err
        } catch {
            throw DTIntentError(message: "Could not open the workflow library: \(error.localizedDescription)")
        }
    }
}

// MARK: - App Shortcuts Provider

/// Surfaces suggested Siri phrases for Draw Things Studio.
/// Users can add these to Siri from the Shortcuts app or via "Add to Siri".
struct DrawThingsAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GenerateImageIntent(),
            phrases: [
                "Generate an image with \(.applicationName)",
                "Create a picture with \(.applicationName)",
                "Make an image using \(.applicationName)"
            ],
            shortTitle: "Generate Image",
            systemImageName: "photo.badge.plus"
        )
        AppShortcut(
            intent: RunWorkflowIntent(),
            phrases: [
                "Run a workflow with \(.applicationName)",
                "Execute a \(.applicationName) workflow"
            ],
            shortTitle: "Run Workflow",
            systemImageName: "play.rectangle"
        )
    }
}
