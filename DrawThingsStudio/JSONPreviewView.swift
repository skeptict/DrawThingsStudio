//
//  JSONPreviewView.swift
//  DrawThingsStudio
//
//  Preview and export JSON instructions
//

import SwiftUI
import AppKit

/// View for previewing and exporting StoryFlow JSON instructions
struct JSONPreviewView: View {
    @ObservedObject var viewModel: WorkflowBuilderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var jsonString: String = ""
    @State private var validationResult: ValidationResult?
    @State private var showCompact = false
    @State private var copySuccess = false

    private let exporter = StoryflowExporter()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Validation warnings
            if let result = validationResult, !result.isValid {
                validationBanner(result)
            }

            // JSON content
            ScrollView {
                Text(jsonString)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(NSColor.textBackgroundColor))

            Divider()

            // Footer
            footer
        }
        .frame(width: 700, height: 600)
        .onAppear {
            generateJSON()
            validateInstructions()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("StoryFlow Instructions Preview")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Copy this JSON and paste into StoryFlow Pipeline in Draw Things")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Label("\(viewModel.instructions.count) instructions", systemImage: "list.bullet")
                Label(formatSize(), systemImage: "doc")

                Spacer()

                Toggle("Compact", isOn: $showCompact)
                    .toggleStyle(.switch)
                    .onChange(of: showCompact) { _, _ in
                        generateJSON()
                    }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Validation Banner

    private func validationBanner(_ result: ValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !result.errors.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("\(result.errors.count) error(s) found")
                        .fontWeight(.medium)
                }

                ForEach(result.errors.prefix(3), id: \.self) { error in
                    Text("• \(errorDescription(error))")
                        .font(.caption)
                }
            }

            if !result.warnings.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.yellow)
                    Text("\(result.warnings.count) warning(s)")
                }

                ForEach(result.warnings.prefix(3), id: \.self) { warning in
                    Text("• \(warningDescription(warning))")
                        .font(.caption)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Validate") {
                validateInstructions()
            }

            if let result = validationResult, result.isValid {
                Label("Valid", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }

            Spacer()

            if copySuccess {
                Label("Copied!", systemImage: "checkmark")
                    .foregroundColor(.green)
                    .transition(.opacity)
            }

            Button("Copy to Clipboard") {
                copyToClipboard()
            }
            .keyboardShortcut("c", modifiers: .command)

            Button("Save to File...") {
                Task {
                    await saveToFile()
                }
            }

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    // MARK: - Actions

    private func generateJSON() {
        do {
            let instructions = viewModel.getInstructionDicts()
            if showCompact {
                jsonString = try exporter.exportToCompactJSON(instructions: instructions)
            } else {
                jsonString = try exporter.exportToJSON(instructions: instructions)
            }
        } catch {
            jsonString = "Error generating JSON: \(error.localizedDescription)"
        }
    }

    private func validateInstructions() {
        let validator = StoryflowValidator()
        validationResult = validator.validate(instructions: viewModel.getInstructionDicts())
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonString, forType: .string)

        withAnimation {
            copySuccess = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copySuccess = false
            }
        }
    }

    private func saveToFile() async {
        await viewModel.exportWithSavePanel()
    }

    private func formatSize() -> String {
        let bytes = jsonString.utf8.count
        return exporter.formatFileSize(bytes)
    }

    // MARK: - Error Descriptions

    private func errorDescription(_ error: ValidationError) -> String {
        switch error {
        case .invalidStructure(let index):
            return "Invalid structure at instruction \(index)"
        case .unknownInstruction(let index, let key):
            return "Unknown instruction '\(key)' at index \(index)"
        case .nestedLoop(let index):
            return "Nested loop at index \(index) (not allowed)"
        case .unexpectedLoopEnd(let index):
            return "Unexpected loopEnd at index \(index)"
        case .invalidFilePath(let index, let path):
            return "Invalid file path '\(path)' at index \(index)"
        }
    }

    private func warningDescription(_ warning: ValidationWarning) -> String {
        switch warning {
        case .unclosedLoop:
            return "Loop not closed with loopEnd"
        case .noPrompts:
            return "No prompt instructions found"
        case .noConfig:
            return "No config instruction found"
        }
    }
}

// MARK: - Hashable conformance for ForEach

extension ValidationError: Hashable {
    static func == (lhs: ValidationError, rhs: ValidationError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidStructure(let a), .invalidStructure(let b)):
            return a == b
        case (.unknownInstruction(let a1, let a2), .unknownInstruction(let b1, let b2)):
            return a1 == b1 && a2 == b2
        case (.nestedLoop(let a), .nestedLoop(let b)):
            return a == b
        case (.unexpectedLoopEnd(let a), .unexpectedLoopEnd(let b)):
            return a == b
        case (.invalidFilePath(let a1, let a2), .invalidFilePath(let b1, let b2)):
            return a1 == b1 && a2 == b2
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .invalidStructure(let index):
            hasher.combine(0)
            hasher.combine(index)
        case .unknownInstruction(let index, let key):
            hasher.combine(1)
            hasher.combine(index)
            hasher.combine(key)
        case .nestedLoop(let index):
            hasher.combine(2)
            hasher.combine(index)
        case .unexpectedLoopEnd(let index):
            hasher.combine(3)
            hasher.combine(index)
        case .invalidFilePath(let index, let path):
            hasher.combine(4)
            hasher.combine(index)
            hasher.combine(path)
        }
    }
}

extension ValidationWarning: Hashable {
    static func == (lhs: ValidationWarning, rhs: ValidationWarning) -> Bool {
        switch (lhs, rhs) {
        case (.unclosedLoop, .unclosedLoop):
            return true
        case (.noPrompts, .noPrompts):
            return true
        case (.noConfig, .noConfig):
            return true
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .unclosedLoop:
            hasher.combine(0)
        case .noPrompts:
            hasher.combine(1)
        case .noConfig:
            hasher.combine(2)
        }
    }
}

