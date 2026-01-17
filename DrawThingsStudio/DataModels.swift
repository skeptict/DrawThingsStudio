//
//  DataModels.swift
//  DrawThingsStudio
//
//  SwiftData models for persistence
//

import Foundation
import SwiftData

// MARK: - Saved Workflow

/// A saved workflow stored in the library
/// Stores the workflow as JSON data for maximum compatibility
@Model
class SavedWorkflow {
    @Attribute(.unique) var id: UUID
    var name: String
    var workflowDescription: String
    var jsonData: Data
    var instructionCount: Int
    var createdAt: Date
    var modifiedAt: Date
    var isFavorite: Bool
    var category: String?

    /// Preview of first few instructions for display
    var instructionPreview: String

    init(name: String, description: String = "", jsonData: Data, instructionCount: Int, instructionPreview: String) {
        self.id = UUID()
        self.name = name
        self.workflowDescription = description
        self.jsonData = jsonData
        self.instructionCount = instructionCount
        self.instructionPreview = instructionPreview
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isFavorite = false
        self.category = nil
    }

    /// Convenience to get JSON string
    var jsonString: String? {
        String(data: jsonData, encoding: .utf8)
    }
}
