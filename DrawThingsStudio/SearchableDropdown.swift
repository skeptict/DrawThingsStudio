//
//  SearchableDropdown.swift
//  DrawThingsStudio
//
//  Reusable searchable dropdown component for model/sampler/LoRA selection
//

import SwiftUI

/// A searchable dropdown component that allows filtering and selecting from a list
struct SearchableDropdown<Item: Identifiable & Hashable>: View {
    let title: String
    let items: [Item]
    let itemLabel: (Item) -> String
    @Binding var selection: String
    var placeholder: String = "Search..."

    @State private var searchText = ""
    @State private var isExpanded = false
    @FocusState private var isSearchFocused: Bool

    private var filteredItems: [Item] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { item in
            itemLabel(item).localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedItemLabel: String {
        if selection.isEmpty {
            return "Select \(title)"
        }
        if let item = items.first(where: { itemLabel($0) == selection || String(describing: $0.id) == selection }) {
            return itemLabel(item)
        }
        return selection
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with selection button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                    if isExpanded {
                        searchText = ""
                    }
                }
            } label: {
                HStack {
                    Text(selectedItemLabel)
                        .foregroundColor(selection.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.neuSurface)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title): \(selectedItemLabel)")
            .accessibilityHint("Double-tap to \(isExpanded ? "close" : "open") dropdown")

            // Dropdown panel
            if isExpanded {
                VStack(spacing: 0) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        TextField(placeholder, text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .focused($isSearchFocused)
                            .accessibilityLabel("Search \(title)")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.neuBackground)

                    Divider()

                    // Results list
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if filteredItems.isEmpty {
                                Text("No results")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(filteredItems) { item in
                                    let label = itemLabel(item)
                                    let isSelected = selection == label || selection == String(describing: item.id)

                                    Button {
                                        selection = label
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isExpanded = false
                                        }
                                    } label: {
                                        HStack {
                                            Text(label)
                                                .font(.caption)
                                                .lineLimit(1)
                                                .truncationMode(.middle)

                                            Spacer()

                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.caption)
                                                    .foregroundColor(.accentColor)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(label)
                                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .background(Color.neuSurface)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .onAppear {
                    isSearchFocused = true
                }
            }
        }
    }
}

/// Simplified searchable dropdown for string items
struct SimpleSearchableDropdown: View {
    let title: String
    let items: [String]
    @Binding var selection: String
    var placeholder: String = "Search..."

    private struct StringItem: Identifiable, Hashable {
        let id: String
        var value: String { id }
    }

    var body: some View {
        SearchableDropdown(
            title: title,
            items: items.map { StringItem(id: $0) },
            itemLabel: { $0.value },
            selection: $selection,
            placeholder: placeholder
        )
    }
}

// MARK: - LoRA Configuration View

/// A row for configuring a single LoRA with weight slider
struct LoRAConfigRow: View {
    let lora: DrawThingsLoRA
    @Binding var weight: Double
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // LoRA name
            Text(lora.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Weight slider
            HStack(spacing: 4) {
                Slider(value: $weight, in: 0...2, step: 0.1)
                    .frame(width: 80)
                    .accessibilityLabel("Weight for \(lora.name)")
                    .accessibilityValue(String(format: "%.1f", weight))

                Text(String(format: "%.1f", weight))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }

            // Remove button
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(lora.name)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.neuSurface)
        .cornerRadius(6)
    }
}

/// View for managing multiple LoRA configurations
struct LoRAConfigurationView: View {
    let availableLoRAs: [DrawThingsLoRA]
    @Binding var selectedLoRAs: [DrawThingsGenerationConfig.LoRAConfig]

    @State private var showAddLoRA = false
    @State private var searchText = ""

    private var filteredLoRAs: [DrawThingsLoRA] {
        let alreadySelected = Set(selectedLoRAs.map { $0.file })
        let available = availableLoRAs.filter { !alreadySelected.contains($0.filename) }

        if searchText.isEmpty {
            return available
        }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("LoRAs")
                    .font(.caption.weight(.medium))

                Spacer()

                Button {
                    showAddLoRA.toggle()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .disabled(availableLoRAs.isEmpty)
                .accessibilityLabel("Add LoRA")
            }

            // Selected LoRAs
            if selectedLoRAs.isEmpty {
                Text("No LoRAs selected")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(selectedLoRAs.enumerated()), id: \.offset) { index, config in
                    if let lora = availableLoRAs.first(where: { $0.filename == config.file }) {
                        LoRAConfigRow(
                            lora: lora,
                            weight: Binding(
                                get: { selectedLoRAs[index].weight },
                                set: { selectedLoRAs[index].weight = $0 }
                            ),
                            onRemove: {
                                selectedLoRAs.remove(at: index)
                            }
                        )
                    }
                }
            }

            // Add LoRA dropdown
            if showAddLoRA {
                VStack(spacing: 0) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        TextField("Search LoRAs...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .accessibilityLabel("Search LoRAs")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.neuBackground)

                    Divider()

                    // Results
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if filteredLoRAs.isEmpty {
                                Text("No LoRAs available")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(filteredLoRAs) { lora in
                                    Button {
                                        selectedLoRAs.append(
                                            DrawThingsGenerationConfig.LoRAConfig(
                                                file: lora.filename,
                                                weight: 0.6
                                            )
                                        )
                                        showAddLoRA = false
                                        searchText = ""
                                    } label: {
                                        Text(lora.name)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Add \(lora.name)")
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
                .background(Color.neuSurface)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SimpleSearchableDropdown(
            title: "Sampler",
            items: DrawThingsSampler.builtIn.map { $0.name },
            selection: .constant("UniPC Trailing")
        )
        .frame(width: 250)

        LoRAConfigurationView(
            availableLoRAs: [
                DrawThingsLoRA(filename: "detail_tweaker.safetensors"),
                DrawThingsLoRA(filename: "add_more_details.safetensors"),
                DrawThingsLoRA(filename: "epi_noiseoffset.safetensors"),
            ],
            selectedLoRAs: .constant([
                DrawThingsGenerationConfig.LoRAConfig(file: "detail_tweaker.safetensors", weight: 0.6)
            ])
        )
        .frame(width: 300)
    }
    .padding()
    .background(Color.neuBackground)
}
