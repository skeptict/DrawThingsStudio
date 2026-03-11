//
//  ImageDescriptionView.swift
//  DrawThingsStudio
//
//  Reusable sheet for describing an image with a vision LLM agent.
//

import SwiftUI
import AppKit

// MARK: - NSImage JPEG helper

private extension NSImage {
    func jpegData(compressionQuality: CGFloat = 0.85) -> Data? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}

// MARK: - ImageDescriptionView

/// A sheet that uses a vision LLM agent to describe an image and route the result to a prompt.
///
/// Callers provide closures for each available destination. If a closure is nil, that
/// destination button is not shown. The generate-image callback receives the prompt text
/// and an optional NSImage to use as img2img source (when the user enables the toggle).
struct ImageDescriptionView: View {
    let image: NSImage
    /// Called with (promptText, sourceImage?) when the user sends to Generate Image. nil = not offered.
    let onSendToGeneratePrompt: ((String, NSImage?) -> Void)?
    /// Called with promptText when the user sends to Story Studio. nil = not offered.
    let onSendToWorkflowPrompt: ((String) -> Void)?

    @ObservedObject private var agentsManager = DescribeAgentsManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAgentID: String = "general"
    @State private var isDescribing = false
    @State private var result: String = ""
    @State private var errorMessage: String?
    @State private var showAgentEditor = false
    @State private var sendImageAsSource = false
    // Cache client for the sheet lifetime — vision payloads are large; avoid reconnecting per tap
    @State private var llmClient: (any LLMProvider)?

    private var bothDestinationsAvailable: Bool {
        onSendToGeneratePrompt != nil && onSendToWorkflowPrompt != nil
    }

    /// Whether Generate Image is the active send target
    private var sendingToGenerate: Bool {
        if bothDestinationsAvailable {
            return settings.describeImageSendTarget == "generateImage"
        }
        return onSendToGeneratePrompt != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Describe Image", systemImage: "eye")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Image preview
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .neuCard(cornerRadius: 12)

                    // Agent picker
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Agent")
                                .font(.headline)
                            Spacer()
                            Button("Manage Agents...") { showAgentEditor = true }
                                .buttonStyle(NeumorphicButtonStyle())
                                .font(.caption)
                        }

                        Picker("Agent", selection: $selectedAgentID) {
                            ForEach(agentsManager.agents) { agent in
                                Label(agent.name, systemImage: agent.icon).tag(agent.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)

                        if let agent = agentsManager.agent(for: selectedAgentID) {
                            HStack(spacing: 8) {
                                if !agent.targetModel.isEmpty {
                                    Text("Target: \(agent.targetModel)")
                                        .font(.caption)
                                        .foregroundColor(.neuTextSecondary)
                                }
                                if !agent.preferredVisionModel.isEmpty {
                                    Text("Model: \(agent.preferredVisionModel)")
                                        .font(.caption)
                                        .foregroundColor(.neuTextSecondary)
                                }
                            }
                        }
                    }

                    // Describe button
                    Button(action: describe) {
                        HStack {
                            if isDescribing {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "eye")
                            }
                            Text(isDescribing ? "Describing..." : "Describe Image")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(NeumorphicButtonStyle(isProminent: true))
                    .controlSize(.large)
                    .disabled(isDescribing)

                    // Error
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.callout)
                                .foregroundColor(.orange)
                        }
                        .padding(12)
                        .neuInset(cornerRadius: 8)
                    }

                    // Result section
                    if !result.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Result")
                                .font(.headline)

                            TextEditor(text: $result)
                                .font(.body)
                                .frame(minHeight: 100)
                                .padding(4)
                                .neuInset(cornerRadius: 8)
                        }

                        // Send target preference (only when both destinations exist)
                        if bothDestinationsAvailable {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Send To")
                                    .font(.headline)
                                Picker("Send To", selection: $settings.describeImageSendTarget) {
                                    Text("Generate Image").tag("generateImage")
                                    Text("Story Studio").tag("storyStudio")
                                }
                                .pickerStyle(.radioGroup)
                            }
                        }

                        // img2img source toggle — only relevant when sending to Generate Image
                        if onSendToGeneratePrompt != nil && sendingToGenerate {
                            Toggle("Include image as img2img source", isOn: $sendImageAsSource)
                                .toggleStyle(.checkbox)
                                .font(.callout)
                                .help("Sends the image along with the prompt as a starting image — useful for video models like Wan 2.2 and LTX-2")
                        }

                        // Action buttons
                        VStack(spacing: 10) {
                            if bothDestinationsAvailable {
                                Button(action: sendToTarget) {
                                    HStack {
                                        Image(systemName: "arrow.right.circle.fill")
                                        Text(settings.describeImageSendTarget == "generateImage"
                                             ? "Send to Generate Image"
                                             : "Send to Story Studio")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(NeumorphicButtonStyle(isProminent: true))
                                .controlSize(.large)
                            } else {
                                // Single destination — show whichever is available
                                if let _ = onSendToGeneratePrompt {
                                    Button(action: sendToTarget) {
                                        HStack {
                                            Image(systemName: "arrow.right.circle.fill")
                                            Text("Send to Generate Image")
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(NeumorphicButtonStyle(isProminent: true))
                                    .controlSize(.large)
                                } else if let onSend = onSendToWorkflowPrompt {
                                    Button(action: { onSend(result); dismiss() }) {
                                        HStack {
                                            Image(systemName: "arrow.right.circle.fill")
                                            Text("Send to Story Studio")
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(NeumorphicButtonStyle(isProminent: true))
                                    .controlSize(.large)
                                }
                            }

                            Button("Copy to Clipboard") {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(result, forType: .string)
                            }
                            .buttonStyle(NeumorphicButtonStyle())
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 660)
        .neuBackground()
        .sheet(isPresented: $showAgentEditor) {
            DescribeAgentEditorView()
        }
        .onAppear {
            if agentsManager.agent(for: selectedAgentID) == nil,
               let first = agentsManager.agents.first {
                selectedAgentID = first.id
            }
        }
    }

    // MARK: - Actions

    private func describe() {
        guard let agent = agentsManager.agent(for: selectedAgentID) else { return }
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            errorMessage = "Failed to encode image."
            return
        }

        isDescribing = true
        errorMessage = nil
        result = ""

        if llmClient == nil { llmClient = AppSettings.shared.createLLMClient() }
        let client = llmClient!
        let model = agent.preferredVisionModel.isEmpty ? client.defaultModel : agent.preferredVisionModel
        let systemPrompt = agent.systemPrompt
        let userMessage = agent.userMessage

        Task { @MainActor in
            defer { isDescribing = false }
            do {
                result = try await client.describeImage(
                    imageData,
                    systemPrompt: systemPrompt,
                    userMessage: userMessage,
                    model: model
                )
                if result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    errorMessage = "The model returned an empty response. Make sure your LLM provider has a vision-capable model (e.g., llava, moondream, qwen-vl) loaded."
                    result = ""
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func sendToTarget() {
        guard !result.isEmpty else { return }
        let sourceImage: NSImage? = sendImageAsSource ? image : nil
        if settings.describeImageSendTarget == "generateImage" || !bothDestinationsAvailable {
            onSendToGeneratePrompt?(result, sourceImage)
        } else {
            onSendToWorkflowPrompt?(result)
        }
        dismiss()
    }
}
