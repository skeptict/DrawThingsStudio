//
//  DrawThingsAssetManager.swift
//  DrawThingsStudio
//
//  Shared manager for fetching and caching Draw Things assets (models, LoRAs, etc.)
//

import Foundation
import AppKit
import OSLog

/// Shared manager for Draw Things assets like models and LoRAs
@MainActor
final class DrawThingsAssetManager: ObservableObject {

    static let shared = DrawThingsAssetManager()

    private let logger = Logger(subsystem: "com.drawthingsstudio", category: "asset-manager")

    // MARK: - Published State

    @Published private(set) var models: [DrawThingsModel] = []
    @Published private(set) var loras: [DrawThingsLoRA] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastFetchDate: Date?

    // MARK: - Initialization

    private init() {}

    // MARK: - Fetch Assets

    /// Fetch all available assets from Draw Things
    func fetchAssets() async {
        // Create HTTP client for fetching (HTTP has better support for asset listing)
        let settings = AppSettings.shared
        let client = DrawThingsHTTPClient(
            host: settings.drawThingsHost,
            port: settings.drawThingsHTTPPort,
            sharedSecret: settings.drawThingsSharedSecret
        )

        isLoading = true
        lastError = nil

        // First check connection
        let connected = await client.checkConnection()
        guard connected else {
            lastError = "Cannot connect to Draw Things"
            isLoading = false
            return
        }

        // Fetch models
        do {
            let fetchedModels = try await client.fetchModels()
            if fetchedModels.isEmpty {
                logger.info("Draw Things returned empty model list - endpoint may not be supported")
            } else {
                models = fetchedModels
                logger.info("Fetched \(self.models.count) models")
            }
        } catch let error as DrawThingsError {
            // Check if it's a 404 or similar - endpoint might not exist
            if case .requestFailed(let code, _) = error, code == 404 {
                logger.info("Draw Things doesn't support /sdapi/v1/sd-models endpoint (404)")
            } else {
                logger.warning("Failed to fetch models: \(error.localizedDescription)")
                lastError = "Model list unavailable - type model name manually"
            }
        } catch {
            logger.warning("Failed to fetch models: \(error.localizedDescription)")
        }

        // Fetch LoRAs
        do {
            let fetchedLoRAs = try await client.fetchLoRAs()
            if fetchedLoRAs.isEmpty {
                logger.info("Draw Things returned empty LoRA list - endpoint may not be supported")
            } else {
                loras = fetchedLoRAs
                logger.info("Fetched \(self.loras.count) LoRAs")
            }
        } catch let error as DrawThingsError {
            if case .requestFailed(let code, _) = error, code == 404 {
                logger.info("Draw Things doesn't support /sdapi/v1/loras endpoint (404)")
            } else {
                logger.warning("Failed to fetch LoRAs: \(error.localizedDescription)")
            }
        } catch {
            logger.warning("Failed to fetch LoRAs: \(error.localizedDescription)")
        }

        isLoading = false
        lastFetchDate = Date()
    }

    /// Refresh assets if stale (older than 5 minutes) or never fetched
    func refreshIfNeeded() async {
        if let lastFetch = lastFetchDate {
            let staleInterval: TimeInterval = 5 * 60 // 5 minutes
            if Date().timeIntervalSince(lastFetch) < staleInterval {
                return // Not stale yet
            }
        }
        await fetchAssets()
    }

    /// Force refresh assets
    func forceRefresh() async {
        await fetchAssets()
    }

    // MARK: - Helpers

    /// Get model display name for a filename
    func modelDisplayName(for filename: String) -> String {
        if let model = models.first(where: { $0.filename == filename }) {
            return model.name
        }
        return filename
    }

    /// Get LoRA display name for a filename
    func loraDisplayName(for filename: String) -> String {
        if let lora = loras.first(where: { $0.filename == filename }) {
            return lora.name
        }
        return filename
    }
}
