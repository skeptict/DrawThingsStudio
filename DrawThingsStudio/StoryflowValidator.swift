//
//  StoryflowValidator.swift
//  DrawThingsStudio
//
//  Validation for StoryFlow instructions
//

import Foundation

/// Validates StoryFlow instruction arrays for correctness
class StoryflowValidator {

    // MARK: - Allowed Keys

    /// All valid instruction keys recognized by StoryflowPipeline.js
    private let allowedKeys: Set<String> = [
        "note", "prompt", "config", "frames", "faceZoom", "askZoom",
        "removeBkgd", "canvasClear", "canvasSave", "canvasLoad",
        "moveScale", "adaptSize", "crop", "moodboardClear", "moodboardCanvas",
        "moodboardAdd", "loopAddMB", "moodboardRemove", "moodboardWeights",
        "maskClear", "maskLoad", "maskGet", "maskBkgd", "maskFG", "maskBody", "maskAsk",
        "depthExtract", "depthCanvas", "depthToCanvas", "inpaintTools", "xlMagic",
        "negPrompt", "poseExtract", "poseJSON", "loop", "loopLoad", "loopSave",
        "loopEnd", "end"
    ]

    /// Keys that require file path validation
    private let filePathKeys: Set<String> = [
        "canvasLoad", "canvasSave", "moodboardAdd", "maskLoad"
    ]

    /// Keys that require .png extension
    private let pngRequiredKeys: Set<String> = [
        "canvasSave"
    ]

    /// Keys that allow multiple extensions
    private let imageLoadKeys: Set<String> = [
        "canvasLoad", "moodboardAdd", "maskLoad"
    ]

    // MARK: - Validation

    /// Validate an array of instruction dictionaries
    /// - Parameter instructions: Array of instruction dictionaries
    /// - Returns: Validation result with errors and warnings
    func validate(instructions: [[String: Any]]) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []

        var inLoop = false
        var loopHasEnd = false
        var hasPrompt = false
        var hasConfig = false

        for (index, instruction) in instructions.enumerated() {
            // Check structure - must have exactly one key
            guard let key = instruction.keys.first, instruction.keys.count == 1 else {
                errors.append(.invalidStructure(index: index))
                continue
            }

            // Check if key is valid
            if !allowedKeys.contains(key) {
                errors.append(.unknownInstruction(index: index, key: key))
            }

            // Track prompt and config presence
            if key == "prompt" {
                hasPrompt = true
            }
            if key == "config" {
                hasConfig = true
            }

            // Check loop pairing
            if key == "loop" {
                if inLoop {
                    errors.append(.nestedLoop(index: index))
                }
                inLoop = true
                loopHasEnd = false
            }

            if key == "loopEnd" {
                if !inLoop {
                    errors.append(.unexpectedLoopEnd(index: index))
                } else {
                    loopHasEnd = true
                    inLoop = false
                }
            }

            // Validate file paths
            if filePathKeys.contains(key) {
                if let path = instruction[key] as? String {
                    if !isValidFilePath(path, forKey: key) {
                        errors.append(.invalidFilePath(index: index, path: path))
                    }
                }
            }
        }

        // Check unclosed loops
        if inLoop && !loopHasEnd {
            warnings.append(.unclosedLoop)
        }

        // Check for missing essentials
        if !hasPrompt && !instructions.isEmpty {
            warnings.append(.noPrompts)
        }

        if !hasConfig && !instructions.isEmpty {
            warnings.append(.noConfig)
        }

        return ValidationResult(errors: errors, warnings: warnings)
    }

    // MARK: - File Path Validation

    /// Validate a file path for a given instruction key
    private func isValidFilePath(_ path: String, forKey key: String) -> Bool {
        // Empty paths are invalid for file operations
        if path.isEmpty {
            return false
        }

        // Check extension requirements
        if pngRequiredKeys.contains(key) {
            return path.lowercased().hasSuffix(".png")
        }

        if imageLoadKeys.contains(key) {
            let lowercased = path.lowercased()
            return lowercased.hasSuffix(".png") ||
                   lowercased.hasSuffix(".jpg") ||
                   lowercased.hasSuffix(".jpeg") ||
                   lowercased.hasSuffix(".webp")
        }

        return true
    }

    // MARK: - Quick Validation

    /// Quick check if instructions are valid (no detailed errors)
    func isValid(instructions: [[String: Any]]) -> Bool {
        let result = validate(instructions: instructions)
        return result.isValid
    }

    /// Check if a single instruction dictionary is valid
    func isValidInstruction(_ instruction: [String: Any]) -> Bool {
        guard let key = instruction.keys.first, instruction.keys.count == 1 else {
            return false
        }
        return allowedKeys.contains(key)
    }
}

// MARK: - Validation Result

/// Result of validating StoryFlow instructions
struct ValidationResult {
    let errors: [ValidationError]
    let warnings: [ValidationWarning]

    /// True if there are no errors (warnings are acceptable)
    var isValid: Bool {
        errors.isEmpty
    }

    /// True if there are no errors or warnings
    var isPerfect: Bool {
        errors.isEmpty && warnings.isEmpty
    }

    /// Summary message
    var summary: String {
        if isPerfect {
            return "Valid workflow"
        } else if isValid {
            return "\(warnings.count) warning(s)"
        } else {
            return "\(errors.count) error(s), \(warnings.count) warning(s)"
        }
    }
}

// MARK: - Validation Errors

/// Errors found during validation
enum ValidationError: Error {
    case invalidStructure(index: Int)
    case unknownInstruction(index: Int, key: String)
    case nestedLoop(index: Int)
    case unexpectedLoopEnd(index: Int)
    case invalidFilePath(index: Int, path: String)
}

// MARK: - Validation Warnings

/// Warnings found during validation (non-fatal issues)
enum ValidationWarning {
    case unclosedLoop
    case noPrompts
    case noConfig
}

// MARK: - Error Descriptions

extension ValidationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidStructure(let index):
            return "Invalid instruction structure at index \(index)"
        case .unknownInstruction(let index, let key):
            return "Unknown instruction '\(key)' at index \(index)"
        case .nestedLoop(let index):
            return "Nested loop at index \(index) - loops cannot be nested"
        case .unexpectedLoopEnd(let index):
            return "Unexpected loopEnd at index \(index) - no matching loop"
        case .invalidFilePath(let index, let path):
            return "Invalid file path '\(path)' at index \(index)"
        }
    }
}
