//
//  WorkflowExecutionView.swift
//  DrawThingsStudio
//
//  View for executing workflows with progress tracking
//

import SwiftUI

struct WorkflowExecutionView: View {
    @ObservedObject var viewModel: WorkflowExecutionViewModel
    let instructions: [WorkflowInstruction]
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Main content
            HStack(spacing: 0) {
                // Left: Execution log
                executionLog
                    .frame(minWidth: 300)

                Divider()

                // Right: Generated images
                generatedImagesPanel
                    .frame(minWidth: 250)
            }

            Divider()

            // Footer with controls
            footer
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(Color.neuBackground)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Workflow Execution")
                    .font(.headline)

                HStack(spacing: 16) {
                    Label(viewModel.status.displayText, systemImage: statusIcon)
                        .foregroundColor(statusColor)
                        .accessibilityLabel("Execution status: \(viewModel.status.displayText)")

                    if viewModel.status.isRunning {
                        Text("\(viewModel.currentInstructionIndex + 1) / \(viewModel.totalInstructions)")
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Progress: \(viewModel.currentInstructionIndex + 1) of \(viewModel.totalInstructions) instructions")
                    }
                }
                .font(.subheadline)
            }

            Spacer()

            // Working directory
            VStack(alignment: .trailing, spacing: 2) {
                Text("Working Directory")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: viewModel.browseWorkingDirectory) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text(viewModel.workingDirectory.lastPathComponent)
                            .lineLimit(1)
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.status.isRunning)
            }
        }
        .padding()
    }

    private var statusIcon: String {
        switch viewModel.status {
        case .idle: return "circle"
        case .running: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed(let success): return success ? "checkmark.circle.fill" : "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .idle: return .secondary
        case .running: return .blue
        case .paused: return .orange
        case .completed(let success): return success ? .green : .red
        case .cancelled: return .orange
        }
    }

    // MARK: - Execution Log

    private var executionLog: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Execution Log")
                    .font(.subheadline.bold())

                Spacer()

                if !viewModel.executionLog.isEmpty {
                    Text("\(viewModel.executedCount) executed, \(viewModel.skippedCount) skipped, \(viewModel.failedCount) failed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.executionLog.isEmpty && viewModel.status == .idle {
                // Show instruction preview before execution
                instructionPreview
            } else {
                // Show execution log
                ScrollViewReader { proxy in
                    List(viewModel.executionLog) { entry in
                        logEntryRow(entry)
                            .id(entry.id)
                    }
                    .listStyle(.plain)
                    .onChange(of: viewModel.executionLog.count) { _, _ in
                        if let lastId = viewModel.executionLog.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Generation progress
            if let progress = viewModel.generationProgress {
                generationProgressView(progress)
            }
        }
        .padding()
    }

    private var instructionPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            let analysis = viewModel.analyzeWorkflow(instructions)

            HStack(spacing: 16) {
                StatBadge(value: analysis.full, label: "Supported", color: .green)
                StatBadge(value: analysis.partial, label: "Partial", color: .yellow)
                StatBadge(value: analysis.unsupported, label: "Skipped", color: .red)
            }

            if !analysis.hasGenerationTrigger {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("This workflow has no generation trigger. Add a \"Save Canvas\", \"Loop Save\", or \"Generate Image\" instruction to generate images via Draw Things.")
                        .font(.callout)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
            }

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(instructions.enumerated()), id: \.element.id) { index, instruction in
                        instructionPreviewRow(instruction, index: index)
                    }
                }
            }
        }
    }

    private func instructionPreviewRow(_ instruction: WorkflowInstruction, index: Int) -> some View {
        let support = StoryflowExecutor.supportLevel(for: instruction)

        return HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)

            Image(systemName: supportIcon(support))
                .foregroundColor(supportColor(support))
                .frame(width: 16)

            Image(systemName: instruction.icon)
                .foregroundColor(instruction.color)
                .frame(width: 16)

            Text(instruction.title)
                .font(.callout)

            Spacer()

            if case .notSupported(let reason) = support {
                Text("Skip")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .help(reason)
            }
        }
        .padding(.vertical, 2)
    }

    private func supportIcon(_ level: InstructionSupportLevel) -> String {
        switch level {
        case .full: return "checkmark.circle.fill"
        case .partial: return "exclamationmark.circle.fill"
        case .notSupported: return "xmark.circle"
        }
    }

    private func supportColor(_ level: InstructionSupportLevel) -> Color {
        switch level {
        case .full: return .green
        case .partial: return .yellow
        case .notSupported: return .red
        }
    }

    private func logEntryRow(_ entry: ExecutionLogEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: entry.statusIcon)
                .foregroundColor(entry.statusColor)

            Image(systemName: entry.instructionIcon)
                .foregroundColor(entry.instructionColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.instructionTitle)
                    .font(.callout)

                if let result = entry.result {
                    Text(result.skipped ? (result.skipReason ?? "Skipped") : result.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if entry.isCurrentlyExecuting {
                    Text("Executing...")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func generationProgressView(_ progress: GenerationProgress) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(progress.description)
                    .font(.caption)
                Spacer()
                Text("\(Int(progress.fraction * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: progress.fraction)
                .progressViewStyle(.linear)
                .accessibilityLabel("Generation progress")
                .accessibilityValue("\(Int(progress.fraction * 100)) percent")
        }
        .padding()
        .background(Color.neuSurface)
        .cornerRadius(8)
    }

    // MARK: - Generated Images

    private var generatedImagesPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Generated Images")
                    .font(.subheadline.bold())

                Spacer()

                if !viewModel.generatedImages.isEmpty {
                    Text("\(viewModel.generatedImages.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.generatedImages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No Images")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Generated images will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(viewModel.generatedImages) { image in
                            generatedImageThumbnail(image)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func generatedImageThumbnail(_ generatedImage: GeneratedImage) -> some View {
        Image(nsImage: generatedImage.image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 100, height: 100)
            .clipped()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .help(generatedImage.prompt)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // Error message
            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()

            // Execution time
            if viewModel.executionTimeMs > 0 {
                Text("Completed in \(formatTime(viewModel.executionTimeMs))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Close") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                if viewModel.status == .idle {
                    let analysis = viewModel.analyzeWorkflow(instructions)
                    Button("Execute") {
                        Task {
                            await viewModel.execute(instructions: instructions)
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!analysis.hasGenerationTrigger)
                    .help(analysis.hasGenerationTrigger ? "Execute workflow" : "Add a Save Canvas, Loop Save, or Generate Image instruction first")
                    .accessibilityLabel("Execute workflow")
                } else if viewModel.status.isRunning {
                    Button("Cancel") {
                        viewModel.cancel()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Run Again") {
                        viewModel.reset()
                        Task {
                            await viewModel.execute(instructions: instructions)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }

    private func formatTime(_ ms: Int) -> String {
        if ms < 1000 {
            return "\(ms)ms"
        } else if ms < 60000 {
            return String(format: "%.1fs", Double(ms) / 1000)
        } else {
            let minutes = ms / 60000
            let seconds = (ms % 60000) / 1000
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 60)
    }
}
