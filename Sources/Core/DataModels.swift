import Foundation
import SwiftData

@Model
class GeneratedImage {
    @Attribute(.unique) var id: UUID
    var prompt: String
    var negativePrompt: String?
    var modelName: String
    var parameters: ImageConfig // Reusing ImageConfig from WorkflowTypes
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

@Model
class Workflow {
    @Attribute(.unique) var id: UUID
    var name: String
    var steps: [WorkflowStep]
    var createdAt: Date
    var lastExecuted: Date?
    
    init(name: String, steps: [WorkflowStep]) {
        self.id = UUID()
        self.name = name
        self.steps = steps
        self.createdAt = Date()
    }
}

@Model
class PromptTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var template: String
    var style: String // Could map to PromptStyle.rawValue
    var variables: [String]
    
    init(name: String, template: String, style: String) {
        self.id = UUID()
        self.name = name
        self.template = template
        self.style = style
        self.variables = []
    }
}
