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

// MARK: - Generated Image

@Model
class GeneratedImage {
    @Attribute(.unique) var id: UUID
    var prompt: String
    var negativePrompt: String?
    var modelName: String
    var parameters: ImageConfig
    var imageData: Data?
    var imagePath: URL?
    var createdAt: Date
    var favorite: Bool

    init(prompt: String, modelName: String, parameters: ImageConfig) {
        self.id = UUID()
        self.prompt = prompt
        self.modelName = modelName
        self.parameters = parameters
        self.createdAt = Date()
        self.favorite = false
    }
}

// MARK: - Prompt Template

@Model
class PromptTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var template: String
    var style: String
    var variables: [String]

    init(name: String, template: String, style: String) {
        self.id = UUID()
        self.name = name
        self.template = template
        self.style = style
        self.variables = []
    }
}
