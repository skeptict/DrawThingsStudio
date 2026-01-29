//
//  DrawThingsAssetManager.swift
//  DrawThingsStudio
//
//  Shared manager for fetching and caching Draw Things assets (models, LoRAs, etc.)
//

import Foundation
import AppKit
import Combine
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

    /// Fetch all available assets from Draw Things using the configured transport
    func fetchAssets() async {
        let client = AppSettings.shared.createDrawThingsClient()

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
                logger.info("Draw Things returned empty model list")
            } else {
                models = fetchedModels
                logger.info("Fetched \(self.models.count) models via \(client.transport.displayName)")
            }
        } catch let error as DrawThingsError {
            if case .requestFailed(let code, _) = error, code == 404 {
                logger.info("Endpoint not supported (404)")
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
                logger.info("Draw Things returned empty LoRA list")
            } else {
                loras = fetchedLoRAs
                logger.info("Fetched \(self.loras.count) LoRAs via \(client.transport.displayName)")
            }
        } catch let error as DrawThingsError {
            if case .requestFailed(let code, _) = error, code == 404 {
                logger.info("Endpoint not supported (404)")
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
