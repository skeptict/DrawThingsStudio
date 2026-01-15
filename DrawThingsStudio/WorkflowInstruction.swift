//
//  WorkflowInstruction.swift
//  DrawThingsStudio
//
//  UI model for workflow instructions in the builder
//

import SwiftUI

/// Identifiable wrapper for workflow instructions used in the UI
struct WorkflowInstruction: Identifiable, Equatable {
    let id: UUID
    var type: InstructionType

    init(id: UUID = UUID(), type: InstructionType) {
        self.id = id
        self.type = type
    }

    static func == (lhs: WorkflowInstruction, rhs: WorkflowInstruction) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Instruction Type Enum

/// Enumeration of all supported instruction types
enum InstructionType {
    // Flow Control
    case note(String)
    case loop(count: Int, start: Int)
    case loopEnd
    case end

    // Prompts & Config
    case prompt(String)
    case negativePrompt(String)
    case config(DrawThingsConfig)
    case frames(Int)

    // Canvas Operations
    case canvasClear
    case canvasLoad(String)
    case canvasSave(String)
    case moveScale(x: Float, y: Float, scale: Float)
    case adaptSize(maxWidth: Int, maxHeight: Int)
    case crop

    // Moodboard Operations
    case moodboardClear
    case moodboardCanvas
    case moodboardAdd(String)
    case moodboardRemove(Int)
    case moodboardWeights([Int: Float])
    case loopAddMoodboard(String)

    // Mask Operations
    case maskClear
    case maskLoad(String)
    case maskGet
    case maskBackground
    case maskForeground
    case maskBody(upper: Bool, lower: Bool, clothes: Bool, neck: Int?)
    case maskAsk(String)

    // Depth & Pose
    case depthExtract
    case depthCanvas
    case depthToCanvas
    case poseExtract

    // Advanced Tools
    case removeBackground
    case faceZoom
    case askZoom(String)
    case inpaintTools(strength: Float?, maskBlur: Int?, maskBlurOutset: Int?, restoreOriginal: Bool?)
    case xlMagic(original: Float?, target: Float?, negative: Float?)

    // Loop-specific
    case loopLoad(String)
    case loopSave(String)
}

// MARK: - Display Properties

extension WorkflowInstruction {

    /// SF Symbol icon for the instruction type
    var icon: String {
        switch type {
        case .note: return "text.bubble"
        case .loop: return "repeat"
        case .loopEnd: return "repeat.1"
        case .end: return "stop.fill"

        case .prompt: return "text.cursor"
        case .negativePrompt: return "minus.circle"
        case .config: return "gearshape"
        case .frames: return "film"

        case .canvasClear: return "trash"
        case .canvasLoad: return "square.and.arrow.down"
        case .canvasSave: return "square.and.arrow.up"
        case .moveScale: return "arrow.up.left.and.arrow.down.right"
        case .adaptSize: return "aspectratio"
        case .crop: return "crop"

        case .moodboardClear: return "rectangle.stack.badge.minus"
        case .moodboardCanvas: return "rectangle.stack.badge.plus"
        case .moodboardAdd: return "plus.rectangle.on.rectangle"
        case .moodboardRemove: return "minus.rectangle"
        case .moodboardWeights: return "slider.horizontal.3"
        case .loopAddMoodboard: return "rectangle.stack"

        case .maskClear: return "eraser"
        case .maskLoad: return "theatermask.and.paintbrush"
        case .maskGet: return "square.on.square.dashed"
        case .maskBackground: return "rectangle.dashed.badge.record"
        case .maskForeground: return "person.crop.rectangle"
        case .maskBody: return "figure.stand"
        case .maskAsk: return "wand.and.stars"

        case .depthExtract: return "cube.transparent"
        case .depthCanvas: return "square.3.layers.3d.down.left"
        case .depthToCanvas: return "square.3.layers.3d.down.right"
        case .poseExtract: return "figure.walk"

        case .removeBackground: return "person.crop.rectangle.badge.plus"
        case .faceZoom: return "face.smiling"
        case .askZoom: return "magnifyingglass"
        case .inpaintTools: return "paintbrush.pointed"
        case .xlMagic: return "wand.and.rays"

        case .loopLoad: return "folder"
        case .loopSave: return "folder.badge.plus"
        }
    }

    /// Color for the instruction type
    var color: Color {
        switch type {
        case .note: return .gray
        case .loop, .loopEnd, .end: return .purple

        case .prompt, .negativePrompt: return .blue
        case .config, .frames: return .orange

        case .canvasClear, .canvasLoad, .canvasSave, .moveScale, .adaptSize, .crop: return .green

        case .moodboardClear, .moodboardCanvas, .moodboardAdd, .moodboardRemove, .moodboardWeights, .loopAddMoodboard: return .pink

        case .maskClear, .maskLoad, .maskGet, .maskBackground, .maskForeground, .maskBody, .maskAsk: return .yellow

        case .depthExtract, .depthCanvas, .depthToCanvas, .poseExtract: return .cyan

        case .removeBackground, .faceZoom, .askZoom, .inpaintTools, .xlMagic: return .red

        case .loopLoad, .loopSave: return .indigo
        }
    }

    /// Display title for the instruction
    var title: String {
        switch type {
        case .note: return "Note"
        case .loop: return "Loop"
        case .loopEnd: return "Loop End"
        case .end: return "End"

        case .prompt: return "Prompt"
        case .negativePrompt: return "Negative Prompt"
        case .config: return "Config"
        case .frames: return "Frames"

        case .canvasClear: return "Clear Canvas"
        case .canvasLoad: return "Load Canvas"
        case .canvasSave: return "Save Canvas"
        case .moveScale: return "Move & Scale"
        case .adaptSize: return "Adapt Size"
        case .crop: return "Crop"

        case .moodboardClear: return "Clear Moodboard"
        case .moodboardCanvas: return "Canvas to Moodboard"
        case .moodboardAdd: return "Add to Moodboard"
        case .moodboardRemove: return "Remove from Moodboard"
        case .moodboardWeights: return "Moodboard Weights"
        case .loopAddMoodboard: return "Loop Add Moodboard"

        case .maskClear: return "Clear Mask"
        case .maskLoad: return "Load Mask"
        case .maskGet: return "Get Mask"
        case .maskBackground: return "Mask Background"
        case .maskForeground: return "Mask Foreground"
        case .maskBody: return "Mask Body"
        case .maskAsk: return "AI Mask"

        case .depthExtract: return "Extract Depth"
        case .depthCanvas: return "Canvas to Depth"
        case .depthToCanvas: return "Depth to Canvas"
        case .poseExtract: return "Extract Pose"

        case .removeBackground: return "Remove Background"
        case .faceZoom: return "Face Zoom"
        case .askZoom: return "AI Zoom"
        case .inpaintTools: return "Inpaint Tools"
        case .xlMagic: return "XL Magic"

        case .loopLoad: return "Loop Load"
        case .loopSave: return "Loop Save"
        }
    }

    /// Summary description showing the instruction's value
    var summary: String {
        switch type {
        case .note(let text):
            return text.isEmpty ? "(empty)" : String(text.prefix(50))
        case .loop(let count, let start):
            return "Count: \(count), Start: \(start)"
        case .loopEnd:
            return "End of loop block"
        case .end:
            return "Stop pipeline execution"

        case .prompt(let text):
            return text.isEmpty ? "(empty)" : String(text.prefix(50))
        case .negativePrompt(let text):
            return text.isEmpty ? "(empty)" : String(text.prefix(50))
        case .config(let config):
            var parts: [String] = []
            if let w = config.width, let h = config.height { parts.append("\(w)x\(h)") }
            if let steps = config.steps { parts.append("\(steps) steps") }
            if let model = config.model { parts.append(model) }
            return parts.isEmpty ? "(default)" : parts.joined(separator: ", ")
        case .frames(let count):
            return "\(count) frames"

        case .canvasClear:
            return "Clear the canvas"
        case .canvasLoad(let path):
            return path.isEmpty ? "(no file)" : path
        case .canvasSave(let path):
            return path.isEmpty ? "(no file)" : path
        case .moveScale(let x, let y, let scale):
            return "X: \(x), Y: \(y), Scale: \(scale)"
        case .adaptSize(let w, let h):
            return "Max: \(w)x\(h)"
        case .crop:
            return "Crop canvas to content"

        case .moodboardClear:
            return "Clear all moodboard items"
        case .moodboardCanvas:
            return "Copy canvas to moodboard"
        case .moodboardAdd(let path):
            return path.isEmpty ? "(no file)" : path
        case .moodboardRemove(let index):
            return "Remove index \(index)"
        case .moodboardWeights(let weights):
            return weights.map { "[\($0.key)]: \($0.value)" }.joined(separator: ", ")
        case .loopAddMoodboard(let folder):
            return folder.isEmpty ? "(no folder)" : folder

        case .maskClear:
            return "Clear the mask"
        case .maskLoad(let path):
            return path.isEmpty ? "(no file)" : path
        case .maskGet:
            return "Copy mask to canvas"
        case .maskBackground:
            return "Auto-detect background"
        case .maskForeground:
            return "Auto-detect foreground"
        case .maskBody(let upper, let lower, let clothes, let neck):
            var parts: [String] = []
            if upper { parts.append("upper") }
            if lower { parts.append("lower") }
            if clothes { parts.append("clothes") }
            if let n = neck { parts.append("neck:\(n)") }
            return parts.isEmpty ? "(none)" : parts.joined(separator: ", ")
        case .maskAsk(let desc):
            return desc.isEmpty ? "(no description)" : String(desc.prefix(40))

        case .depthExtract:
            return "Extract depth from canvas"
        case .depthCanvas:
            return "Copy canvas to depth layer"
        case .depthToCanvas:
            return "Copy depth to canvas"
        case .poseExtract:
            return "Extract pose from canvas"

        case .removeBackground:
            return "Remove image background"
        case .faceZoom:
            return "Auto-zoom to detected face"
        case .askZoom(let desc):
            return desc.isEmpty ? "(no description)" : String(desc.prefix(40))
        case .inpaintTools(let strength, let blur, _, _):
            var parts: [String] = []
            if let s = strength { parts.append("strength: \(s)") }
            if let b = blur { parts.append("blur: \(b)") }
            return parts.isEmpty ? "(default)" : parts.joined(separator: ", ")
        case .xlMagic(let orig, let target, let neg):
            var parts: [String] = []
            if let o = orig { parts.append("orig: \(o)") }
            if let t = target { parts.append("target: \(t)") }
            if let n = neg { parts.append("neg: \(n)") }
            return parts.isEmpty ? "(default)" : parts.joined(separator: ", ")

        case .loopLoad(let folder):
            return folder.isEmpty ? "(no folder)" : folder
        case .loopSave(let prefix):
            return prefix.isEmpty ? "(no prefix)" : "\(prefix)0.png, \(prefix)1.png, ..."
        }
    }

    /// Category for grouping in UI
    var category: InstructionCategory {
        switch type {
        case .note, .loop, .loopEnd, .end:
            return .flowControl
        case .prompt, .negativePrompt, .config, .frames:
            return .promptConfig
        case .canvasClear, .canvasLoad, .canvasSave, .moveScale, .adaptSize, .crop:
            return .canvas
        case .moodboardClear, .moodboardCanvas, .moodboardAdd, .moodboardRemove, .moodboardWeights, .loopAddMoodboard:
            return .moodboard
        case .maskClear, .maskLoad, .maskGet, .maskBackground, .maskForeground, .maskBody, .maskAsk:
            return .mask
        case .depthExtract, .depthCanvas, .depthToCanvas, .poseExtract:
            return .depthPose
        case .removeBackground, .faceZoom, .askZoom, .inpaintTools, .xlMagic:
            return .advanced
        case .loopLoad, .loopSave:
            return .loopOperations
        }
    }
}

// MARK: - Category Enum

enum InstructionCategory: String, CaseIterable {
    case flowControl = "Flow Control"
    case promptConfig = "Prompt & Config"
    case canvas = "Canvas"
    case moodboard = "Moodboard"
    case mask = "Mask"
    case depthPose = "Depth & Pose"
    case advanced = "Advanced"
    case loopOperations = "Loop Operations"

    var icon: String {
        switch self {
        case .flowControl: return "arrow.triangle.branch"
        case .promptConfig: return "text.cursor"
        case .canvas: return "photo.artframe"
        case .moodboard: return "rectangle.stack"
        case .mask: return "theatermasks"
        case .depthPose: return "cube.transparent"
        case .advanced: return "wand.and.stars"
        case .loopOperations: return "repeat"
        }
    }
}

// MARK: - Conversion to Instruction Dict

extension WorkflowInstruction {

    /// Convert to instruction dictionary for JSON export
    func toInstructionDict() -> [String: Any] {
        switch type {
        case .note(let text):
            return NoteInstruction(note: text).instructionDict
        case .loop(let count, let start):
            return LoopInstruction(count: count, start: start).instructionDict
        case .loopEnd:
            return LoopEndInstruction().instructionDict
        case .end:
            return EndInstruction().instructionDict

        case .prompt(let text):
            return PromptInstruction(prompt: text).instructionDict
        case .negativePrompt(let text):
            return NegativePromptInstruction(negPrompt: text).instructionDict
        case .config(let config):
            return ConfigInstruction(config: config).instructionDict
        case .frames(let count):
            return FramesInstruction(frames: count).instructionDict

        case .canvasClear:
            return CanvasClearInstruction().instructionDict
        case .canvasLoad(let path):
            return CanvasLoadInstruction(canvasLoad: path).instructionDict
        case .canvasSave(let path):
            return CanvasSaveInstruction(canvasSave: path).instructionDict
        case .moveScale(let x, let y, let scale):
            return MoveScaleInstruction(positionX: x, positionY: y, canvasScale: scale).instructionDict
        case .adaptSize(let w, let h):
            return AdaptSizeInstruction(maxWidth: w, maxHeight: h).instructionDict
        case .crop:
            return CropInstruction().instructionDict

        case .moodboardClear:
            return MoodboardClearInstruction().instructionDict
        case .moodboardCanvas:
            return MoodboardCanvasInstruction().instructionDict
        case .moodboardAdd(let path):
            return MoodboardAddInstruction(moodboardAdd: path).instructionDict
        case .moodboardRemove(let index):
            return MoodboardRemoveInstruction(index: index).instructionDict
        case .moodboardWeights(let weights):
            return MoodboardWeightsInstruction(weights: weights).instructionDict
        case .loopAddMoodboard(let folder):
            return LoopAddMoodboardInstruction(folderName: folder).instructionDict

        case .maskClear:
            return MaskClearInstruction().instructionDict
        case .maskLoad(let path):
            return MaskLoadInstruction(maskLoad: path).instructionDict
        case .maskGet:
            return MaskGetInstruction().instructionDict
        case .maskBackground:
            return MaskBackgroundInstruction().instructionDict
        case .maskForeground:
            return MaskForegroundInstruction().instructionDict
        case .maskBody(let upper, let lower, let clothes, let neck):
            return MaskBodyInstruction(upper: upper, lower: lower, clothes: clothes, neck: neck).instructionDict
        case .maskAsk(let desc):
            return MaskAskInstruction(description: desc).instructionDict

        case .depthExtract:
            return DepthExtractInstruction().instructionDict
        case .depthCanvas:
            return DepthCanvasInstruction().instructionDict
        case .depthToCanvas:
            return DepthToCanvasInstruction().instructionDict
        case .poseExtract:
            return PoseExtractInstruction().instructionDict

        case .removeBackground:
            return RemoveBackgroundInstruction().instructionDict
        case .faceZoom:
            return FaceZoomInstruction().instructionDict
        case .askZoom(let desc):
            return AskZoomInstruction(description: desc).instructionDict
        case .inpaintTools(let strength, let blur, let outset, let restore):
            return InpaintToolsInstruction(strength: strength, maskBlur: blur, maskBlurOutset: outset, restoreOriginalAfterInpaint: restore).instructionDict
        case .xlMagic(let orig, let target, let neg):
            return XLMagicInstruction(original: orig, target: target, negative: neg).instructionDict

        case .loopLoad(let folder):
            return LoopLoadInstruction(folderName: folder).instructionDict
        case .loopSave(let prefix):
            return LoopSaveInstruction(prefix: prefix).instructionDict
        }
    }
}

// MARK: - Factory Methods

extension WorkflowInstruction {

    /// Create default instances for each instruction type
    static func makeNote(_ text: String = "") -> WorkflowInstruction {
        WorkflowInstruction(type: .note(text))
    }

    static func makePrompt(_ text: String = "") -> WorkflowInstruction {
        WorkflowInstruction(type: .prompt(text))
    }

    static func makeNegativePrompt(_ text: String = "") -> WorkflowInstruction {
        WorkflowInstruction(type: .negativePrompt(text))
    }

    static func makeConfig(_ config: DrawThingsConfig = DrawThingsConfig()) -> WorkflowInstruction {
        WorkflowInstruction(type: .config(config))
    }

    static func makeLoop(count: Int = 5, start: Int = 0) -> WorkflowInstruction {
        WorkflowInstruction(type: .loop(count: count, start: start))
    }

    static func makeLoopEnd() -> WorkflowInstruction {
        WorkflowInstruction(type: .loopEnd)
    }

    static func makeCanvasSave(_ path: String = "output.png") -> WorkflowInstruction {
        WorkflowInstruction(type: .canvasSave(path))
    }

    static func makeCanvasLoad(_ path: String = "") -> WorkflowInstruction {
        WorkflowInstruction(type: .canvasLoad(path))
    }

    static func makeCanvasClear() -> WorkflowInstruction {
        WorkflowInstruction(type: .canvasClear)
    }

    static func makeMoodboardClear() -> WorkflowInstruction {
        WorkflowInstruction(type: .moodboardClear)
    }

    static func makeMoodboardCanvas() -> WorkflowInstruction {
        WorkflowInstruction(type: .moodboardCanvas)
    }
}
