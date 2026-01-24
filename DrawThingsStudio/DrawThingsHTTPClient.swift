//
//  DrawThingsHTTPClient.swift
//  DrawThingsStudio
//
//  HTTP client for Draw Things API (port 7860)
//

import Foundation
import AppKit
import OSLog

/// HTTP client for Draw Things image generation API
class DrawThingsHTTPClient: DrawThingsProvider {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.drawthingsstudio", category: "drawthings-http")

    let transport: DrawThingsTransport = .http

    private let host: String
    private let port: Int
    private let sharedSecret: String
    private let session: URLSession

    private var baseURL: URL {
        URL(string: "http://\(host):\(port)")!
    }

    // MARK: - Initialization

    init(host: String = "127.0.0.1", port: Int = 7860, sharedSecret: String = "") {
        self.host = host
        self.port = port
        self.sharedSecret = sharedSecret

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)
    }

    // MARK: - Connection Check

    func checkConnection() async -> Bool {
        do {
            let url = baseURL.appendingPathComponent("sdapi/v1/options")
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            applyAuth(&request)

            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }

            let success = httpResponse.statusCode == 200
            if success {
                logger.info("Connected to Draw Things HTTP API at \(self.host):\(self.port)")
            }
            return success
        } catch {
            logger.error("Failed to connect to Draw Things: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Image Generation

    func generateImage(
        prompt: String,
        config: DrawThingsGenerationConfig,
        onProgress: ((GenerationProgress) -> Void)?
    ) async throws -> [NSImage] {
        onProgress?(.starting)

        let url = baseURL.appendingPathComponent("sdapi/v1/txt2img")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)

        let body = config.toRequestBody(prompt: prompt)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        logger.debug("Sending generation request: prompt=\(prompt.prefix(50))...")

        onProgress?(.sampling(step: 0, totalSteps: config.steps))

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DrawThingsError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Generation failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw DrawThingsError.requestFailed(httpResponse.statusCode, errorMessage)
        }

        onProgress?(.decoding)

        let images = try decodeImageResponse(data)

        onProgress?(.complete)

        logger.info("Generated \(images.count) image(s)")
        return images
    }

    // MARK: - Private Helpers

    private func applyAuth(_ request: inout URLRequest) {
        if !sharedSecret.isEmpty {
            request.setValue("Bearer \(sharedSecret)", forHTTPHeaderField: "Authorization")
        }
    }

    private func decodeImageResponse(_ data: Data) throws -> [NSImage] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DrawThingsError.invalidResponse
        }

        guard let imagesArray = json["images"] as? [String] else {
            // Some Draw Things versions return a different format
            if let singleImage = json["image"] as? String {
                guard let imageData = Data(base64Encoded: singleImage),
                      let nsImage = NSImage(data: imageData) else {
                    throw DrawThingsError.imageDecodingFailed
                }
                return [nsImage]
            }
            throw DrawThingsError.invalidResponse
        }

        var images: [NSImage] = []
        for base64String in imagesArray {
            // Strip data URI prefix if present
            let cleanBase64 = base64String.replacingOccurrences(
                of: "^data:image/[^;]+;base64,",
                with: "",
                options: .regularExpression
            )

            guard let imageData = Data(base64Encoded: cleanBase64),
                  let nsImage = NSImage(data: imageData) else {
                logger.warning("Failed to decode one image from response")
                continue
            }
            images.append(nsImage)
        }

        if images.isEmpty {
            throw DrawThingsError.imageDecodingFailed
        }

        return images
    }
}
