//
//  ImageInspectorViewModel.swift
//  DrawThingsStudio
//
//  ViewModel for PNG metadata inspection with history
//

import Foundation
import AppKit
import Combine

/// A single inspected image with its metadata
struct InspectedImage: Identifiable {
    let id = UUID()
    let image: NSImage
    let metadata: PNGMetadata?
    let sourceName: String
    let inspectedAt: Date
}

@MainActor
final class ImageInspectorViewModel: ObservableObject {

    private static let maxHistoryCount = 50

    @Published var history: [InspectedImage] = []
    @Published var selectedImage: InspectedImage?
    @Published var errorMessage: String?
    @Published var isProcessing = false

    // MARK: - Load Image from URL

    func loadImage(url: URL) {
        isProcessing = true
        errorMessage = nil

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let image = NSImage(contentsOf: url) else {
            errorMessage = "Failed to load image from file."
            isProcessing = false
            return
        }

        var metadata: PNGMetadata?

        if let data = try? Data(contentsOf: url) {
            metadata = PNGMetadataParser.parse(data: data, url: url)
        }

        let entry = InspectedImage(
            image: image,
            metadata: metadata,
            sourceName: url.lastPathComponent,
            inspectedAt: Date()
        )
        history.insert(entry, at: 0)
        trimHistoryIfNeeded()
        selectedImage = entry

        if metadata == nil {
            errorMessage = "No generation metadata found in this image."
        }

        isProcessing = false
    }

    // MARK: - Load Image from Data

    func loadImage(data: Data, sourceName: String = "Dropped Image") {
        isProcessing = true
        errorMessage = nil

        guard let image = NSImage(data: data) else {
            errorMessage = "Failed to load image data."
            isProcessing = false
            return
        }

        // Try parsing raw data for PNG chunks
        var metadata = PNGMetadataParser.parse(data: data)

        // If data is TIFF (pasteboard), try CGImageSource Exif
        if metadata == nil {
            if let source = CGImageSourceCreateWithData(data as CFData, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
               let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
               let userComment = exifDict[kCGImagePropertyExifUserComment as String] as? String {
                metadata = PNGMetadataParser.parseDrawThingsJSONPublic(userComment)
            }
        }

        let entry = InspectedImage(
            image: image,
            metadata: metadata,
            sourceName: sourceName,
            inspectedAt: Date()
        )
        history.insert(entry, at: 0)
        trimHistoryIfNeeded()
        selectedImage = entry

        if metadata == nil {
            errorMessage = "No metadata found. Images from Discord or browsers often have metadata stripped. Try saving the image first, then dragging the file."
        }

        isProcessing = false
    }

    // MARK: - Load from Web URL (Discord CDN, etc.)

    func loadImage(webURL: URL) {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: webURL)
                let sourceName = webURL.lastPathComponent
                loadImage(data: data, sourceName: sourceName)
            } catch {
                errorMessage = "Failed to download image: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }

    // MARK: - Delete / Select

    func deleteImage(_ image: InspectedImage) {
        history.removeAll { $0.id == image.id }
        if selectedImage?.id == image.id {
            selectedImage = history.first
        }
    }

    func clearHistory() {
        history.removeAll()
        selectedImage = nil
        errorMessage = nil
    }

    private func trimHistoryIfNeeded() {
        if history.count > Self.maxHistoryCount {
            history = Array(history.prefix(Self.maxHistoryCount))
        }
    }

    // MARK: - Clipboard

    func copyPromptToClipboard() {
        guard let meta = selectedImage?.metadata else { return }
        var text = ""
        if let prompt = meta.prompt { text += prompt }
        if let neg = meta.negativePrompt, !neg.isEmpty {
            text += "\nNegative prompt: \(neg)"
        }
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    func copyConfigToClipboard() {
        guard let meta = selectedImage?.metadata else { return }

        // For Draw Things format: export the full v2 config with proper key names
        if meta.format == .drawThings, let v2 = meta.rawV2Config {
            let exportDict = Self.buildDrawThingsExportConfig(v2: v2, topLevel: meta.rawTopLevel)
            guard let jsonData = try? JSONSerialization.data(
                withJSONObject: exportDict,
                options: [.prettyPrinted, .sortedKeys]
            ),
            let jsonString = String(data: jsonData, encoding: .utf8) else { return }

            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(jsonString, forType: .string)
            return
        }

        // For non-Draw Things formats, build from extracted fields
        var dict: [String: Any] = [:]
        if let w = meta.width { dict["width"] = w }
        if let h = meta.height { dict["height"] = h }
        if let steps = meta.steps { dict["steps"] = steps }
        if let guidance = meta.guidanceScale { dict["guidance_scale"] = guidance }
        if let seed = meta.seed { dict["seed"] = seed }
        if let sampler = meta.sampler { dict["sampler"] = sampler }
        if let model = meta.model { dict["model"] = model }
        if let strength = meta.strength { dict["strength"] = strength }
        if let shift = meta.shift { dict["shift"] = shift }
        if let seedMode = meta.seedMode { dict["seed_mode"] = seedMode }
        if !meta.loras.isEmpty {
            dict["loras"] = meta.loras.map { lora in
                ["file": lora.file, "weight": lora.weight, "mode": lora.mode] as [String: Any]
            }
        }

        guard !dict.isEmpty,
              let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(jsonString, forType: .string)
    }

    // MARK: - Draw Things Config Export

    /// Builds a Draw Things-compatible config dictionary from v2 config data.
    /// Transforms camelCase v2 keys to the snake_case/mixed format Draw Things expects.
    private static func buildDrawThingsExportConfig(v2: [String: Any], topLevel: [String: Any]?) -> [String: Any] {
        // Key mapping from v2 camelCase to Draw Things export format
        let keyMap: [String: String] = [
            "aestheticScore": "aesthetic_score",
            "batchCount": "batch_count",
            "batchSize": "batch_size",
            // causalInference, causalInferencePad, cfgZero* stay as-is
            "clipSkip": "clip_skip",
            "clipWeight": "clip_weight",
            "cropLeft": "crop_left",
            "cropTop": "crop_top",
            "decodingTileHeight": "decoding_tile_height",
            "decodingTileOverlap": "decoding_tile_overlap",
            "decodingTileWidth": "decoding_tile_width",
            "diffusionTileHeight": "diffusion_tile_height",
            "diffusionTileOverlap": "diffusion_tile_overlap",
            "diffusionTileWidth": "diffusion_tile_width",
            "guidanceEmbed": "guidance_embed",
            "guidanceScale": "guidance_scale",
            "guidingFrameNoise": "guiding_frame_noise",
            "hiresFix": "hires_fix",
            "hiresFixHeight": "hires_fix_height",
            "hiresFixStrength": "hires_fix_strength",
            "hiresFixWidth": "hires_fix_width",
            "imageGuidanceScale": "image_guidance",
            "imagePriorSteps": "image_prior_steps",
            "maskBlur": "mask_blur",
            "maskBlurOutset": "mask_blur_outset",
            "motionScale": "motion_scale",
            "negativeAestheticScore": "negative_aesthetic_score",
            "negativeOriginalImageHeight": "negative_original_height",
            "negativeOriginalImageWidth": "negative_original_width",
            "negativePromptForImagePrior": "negative_prompt_for_image_prior",
            "numFrames": "num_frames",
            "originalImageHeight": "original_height",
            "originalImageWidth": "original_width",
            "preserveOriginalAfterInpaint": "preserve_original_after_inpaint",
            "refinerStart": "refiner_start",
            "resolutionDependentShift": "resolution_dependent_shift",
            "seedMode": "seed_mode",
            "separateClipL": "separate_clip_l",
            "separateOpenClipG": "separate_open_clip_g",
            "speedUpWithGuidanceEmbed": "speed_up_with_guidance_embed",
            "stage2Guidance": "stage_2_guidance",
            "stage2Shift": "stage_2_shift",
            "stage2Steps": "stage_2_steps",
            "startFrameGuidance": "start_frame_guidance",
            "stochasticSamplingGamma": "stochastic_sampling_gamma",
            "t5TextEncoder": "t5_text_encoder_decoding",
            "targetImageHeight": "target_height",
            "targetImageWidth": "target_width",
            "tiledDecoding": "tiled_decoding",
            "tiledDiffusion": "tiled_diffusion",
            "upscalerScaleFactor": "upscaler_scale",
            "zeroNegativePrompt": "zero_negative_prompt",
        ]

        // seedMode int to string mapping
        let seedModeNames: [Int: String] = [
            0: "Legacy",
            1: "Torch CPU Compatible",
            2: "Scale Alike",
            3: "Nvidia GPU Compatible",
        ]

        var result: [String: Any] = [:]

        for (key, value) in v2 {
            let exportKey = keyMap[key] ?? key

            // Special handling for seedMode: convert int to string
            if key == "seedMode", let intVal = value as? Int {
                result[exportKey] = seedModeNames[intVal] ?? "Legacy"
            } else {
                result[exportKey] = value
            }
        }

        // Add duration from profile if available
        if let profile = topLevel?["profile"] as? [String: Any],
           let duration = profile["duration"] as? Double {
            result["duration"] = duration
        }

        // Add mask_blur from top level if not already in v2
        if result["mask_blur"] == nil, let maskBlur = topLevel?["mask_blur"] as? Double {
            result["mask_blur"] = maskBlur
        }

        return result
    }

    func copyAllToClipboard() {
        guard let meta = selectedImage?.metadata else { return }
        var text = ""
        if let prompt = meta.prompt { text += "Prompt: \(prompt)\n" }
        if let neg = meta.negativePrompt, !neg.isEmpty {
            text += "Negative prompt: \(neg)\n"
        }
        let config = formatConfig(meta)
        if !config.isEmpty { text += "\n\(config)" }
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    // MARK: - Config Conversion

    func toGenerationConfig() -> DrawThingsGenerationConfig {
        var config = DrawThingsGenerationConfig()
        guard let meta = selectedImage?.metadata else { return config }

        if let w = meta.width { config.width = w }
        if let h = meta.height { config.height = h }
        if let steps = meta.steps { config.steps = steps }
        if let guidance = meta.guidanceScale { config.guidanceScale = guidance }
        if let seed = meta.seed { config.seed = seed }
        if let sampler = meta.sampler { config.sampler = sampler }
        if let model = meta.model { config.model = model }
        if let strength = meta.strength { config.strength = strength }
        if let shift = meta.shift { config.shift = shift }

        return config
    }

    // MARK: - Private

    private func formatConfig(_ meta: PNGMetadata) -> String {
        var lines: [String] = []
        if let w = meta.width, let h = meta.height { lines.append("Size: \(w)x\(h)") }
        if let steps = meta.steps { lines.append("Steps: \(steps)") }
        if let guidance = meta.guidanceScale { lines.append("CFG scale: \(guidance)") }
        if let seed = meta.seed { lines.append("Seed: \(seed)") }
        if let sampler = meta.sampler { lines.append("Sampler: \(sampler)") }
        if let model = meta.model { lines.append("Model: \(model)") }
        if let strength = meta.strength { lines.append("Strength: \(strength)") }
        if let shift = meta.shift { lines.append("Shift: \(shift)") }
        for lora in meta.loras {
            lines.append("LoRA: \(lora.file) @ \(String(format: "%.2f", lora.weight))")
        }
        return lines.joined(separator: ", ")
    }
}
