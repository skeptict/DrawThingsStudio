//
//  DTVideoExporter.swift
//  DrawThingsStudio
//
//  Exports a DTVideoClip as a .mov file using AVAssetWriter.
//  Full-resolution thumbnails are loaded from the source database for maximum quality.
//

import Foundation
import AVFoundation
import AppKit

// MARK: - Error

enum DTVideoExportError: LocalizedError {
    case noFrames
    case invalidDimensions
    case databaseUnavailable
    case writerFailed(String)

    var errorDescription: String? {
        switch self {
        case .noFrames:             return "No frames to export"
        case .invalidDimensions:    return "Invalid frame dimensions — cannot create video"
        case .databaseUnavailable:  return "Could not open source database for export"
        case .writerFailed(let m):  return "Export failed: \(m)"
        }
    }
}

// MARK: - Exporter

/// Exports a `DTVideoClip` to a temporary .mov file.
/// The caller is responsible for moving the result to the final destination.
struct DTVideoExporter {

    /// Export a flat array of images (e.g. directly from a generation call) to a temporary .mov.
    /// Metadata is embedded from `prompt` and `config`. The caller moves the result to its
    /// final destination.
    static func exportFrames(
        _ frames: [NSImage],
        fps: Double = 16.0,
        prompt: String = "",
        config: DrawThingsGenerationConfig
    ) async throws -> URL {
        guard !frames.isEmpty else { throw DTVideoExportError.noFrames }
        let width  = config.width  > 0 ? config.width  : Int(frames[0].size.width)
        let height = config.height > 0 ? config.height : Int(frames[0].size.height)
        guard width > 0, height > 0 else { throw DTVideoExportError.invalidDimensions }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey:  width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey:    max(width * height * 2, 500_000),
                AVVideoProfileLevelKey:      AVVideoProfileLevelH264HighAutoLevel
            ] as [String: Any]
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey  as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )

        // Embed generation metadata
        var metadataItems: [AVMetadataItem] = []
        if !prompt.isEmpty {
            let titleItem = AVMutableMetadataItem()
            titleItem.identifier = .commonIdentifierTitle
            titleItem.locale = Locale(identifier: "und")
            titleItem.value = String(prompt.prefix(255)) as NSString
            metadataItems.append(titleItem)
        }
        let descParts: [String] = [
            config.model.isEmpty ? nil : "Model: \(config.model)",
            "Seed: \(config.seed)",
            config.steps > 0 ? "Steps: \(config.steps)" : nil,
            "Guidance: \(config.guidanceScale)",
            "Sampler: \(config.sampler)",
            "\(width)×\(height)",
            config.loras.isEmpty ? nil : config.loras.map { "LoRA: \($0.file) @ \(String(format: "%.2f", $0.weight))" }.joined(separator: ", ")
        ].compactMap { $0 }.filter { !$0.isEmpty }
        if !descParts.isEmpty {
            let descItem = AVMutableMetadataItem()
            descItem.identifier = .commonIdentifierDescription
            descItem.locale = Locale(identifier: "und")
            descItem.value = descParts.joined(separator: "\n") as NSString
            metadataItems.append(descItem)
        }
        writer.metadata = metadataItems
        writer.add(writerInput)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        for (index, image) in frames.enumerated() {
            let pts = CMTimeMultiply(frameDuration, multiplier: Int32(index))
            if let pb = image.toDTCVPixelBuffer(width: width, height: height) {
                if !adaptor.append(pb, withPresentationTime: pts) { break }
            }
        }

        writerInput.markAsFinished()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            writer.finishWriting { cont.resume() }
        }
        if let error = writer.error { throw DTVideoExportError.writerFailed(error.localizedDescription) }
        return outputURL
    }

    /// Export the clip and return the URL of the temporary .mov file.
    /// This function is designed to run inside a `Task.detached` on a background thread.
    static func export(clip: DTVideoClip, fps: Double = 8.0, projectURL: URL) async throws -> URL {
        let frames = clip.frames
        guard !frames.isEmpty else { throw DTVideoExportError.noFrames }
        let width  = clip.width  > 0 ? clip.width  : 512
        let height = clip.height > 0 ? clip.height : 512

        // ── 1. Load full-size thumbnails from the database ───────────────────
        // Note: this opens a second read-only connection to the project database while
        // DTProjectBrowserViewModel may have one open on the main actor. Both connections
        // are read-only (SQLITE_OPEN_READONLY) so concurrent access is safe — SQLite
        // allows multiple readers. The connections do not share a WAL cache but that is
        // acceptable for the infrequent export use case.
        guard let db = DTProjectDatabase(fileURL: projectURL) else {
            throw DTVideoExportError.databaseUnavailable
        }
        let images: [NSImage] = frames.map { frame in
            db.fetchFullSizeThumbnail(previewId: frame.previewId)
                ?? frame.thumbnail
                ?? NSImage(size: NSSize(width: width, height: height))
        }

        // ── 2. Set up AVAssetWriter ──────────────────────────────────────────
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey:  width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey:    max(width * height * 2, 500_000),
                AVVideoProfileLevelKey:      AVVideoProfileLevelH264HighAutoLevel
            ] as [String: Any]
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let pixelBufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey  as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pixelBufferAttrs
        )

        // ── 3. Embed metadata ────────────────────────────────────────────────
        var metadata: [AVMetadataItem] = []

        if !clip.prompt.isEmpty {
            let item = AVMutableMetadataItem()
            item.identifier = .commonIdentifierTitle
            item.locale = Locale(identifier: "und")
            item.value = String(clip.prompt.prefix(255)) as NSString
            metadata.append(item)
        }

        let descParts: [String] = [
            clip.model.isEmpty ? nil : "Model: \(clip.model)",
            "Seed: \(clip.seed)",
            clip.steps > 0 ? "Steps: \(clip.steps)" : nil,
            "Guidance: \(clip.guidanceScale)",
            "Sampler: \(clip.sampler)",
            "\(clip.width)×\(clip.height)",
            clip.loras.map { "LoRA: \($0.file) @ \(String(format: "%.2f", $0.weight))" }.joined(separator: ", ")
        ].compactMap { $0 }.filter { !$0.isEmpty }

        if !descParts.isEmpty {
            let descItem = AVMutableMetadataItem()
            descItem.identifier = .commonIdentifierDescription
            descItem.locale = Locale(identifier: "und")
            descItem.value = descParts.joined(separator: "\n") as NSString
            metadata.append(descItem)
        }

        writer.metadata = metadata
        writer.add(writerInput)

        // ── 4. Write frames ──────────────────────────────────────────────────
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))

        // With expectsMediaDataInRealTime = false, AVAssetWriter processes frames
        // synchronously — isReadyForMoreMediaData is always true on the first check.
        // A spin-wait is unnecessary and would silently drop frames on timeout.
        // append(_:withPresentationTime:) returns false only on encoder error; stop
        // immediately so the caller sees the writerFailed error below.
        for (index, image) in images.enumerated() {
            let pts = CMTimeMultiply(frameDuration, multiplier: Int32(index))
            if let pixelBuffer = image.toDTCVPixelBuffer(width: width, height: height) {
                if !adaptor.append(pixelBuffer, withPresentationTime: pts) {
                    break
                }
            }
        }

        writerInput.markAsFinished()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            writer.finishWriting { cont.resume() }
        }

        if let error = writer.error {
            throw DTVideoExportError.writerFailed(error.localizedDescription)
        }

        return outputURL
    }
}

// MARK: - NSImage → CVPixelBuffer

private extension NSImage {
    /// Convert to a 32-BGRA CVPixelBuffer scaled to fill `width × height`.
    func toDTCVPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey:           kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey:                     width,
            kCVPixelBufferHeightKey:                    height,
            kCVPixelBufferCGImageCompatibilityKey:      true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        guard CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pb
        ) == kCVReturnSuccess, let pixelBuffer = pb else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddr = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: baseAddr,
                width: width, height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              ) else { return nil }

        ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))

        var rect = CGRect(origin: .zero, size: self.size)
        guard let cgImg = cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }

        // Scale to fill while preserving aspect ratio
        let sx = CGFloat(width)  / self.size.width
        let sy = CGFloat(height) / self.size.height
        let s  = max(sx, sy)
        let dw = self.size.width  * s
        let dh = self.size.height * s
        let dx = (CGFloat(width)  - dw) / 2
        let dy = (CGFloat(height) - dh) / 2

        ctx.draw(cgImg, in: CGRect(x: dx, y: dy, width: dw, height: dh))
        return pixelBuffer
    }
}
