//
//  ImageInspectorView.swift
//  DrawThingsStudio
//
//  PNG metadata inspector with drag-and-drop, history timeline, and Discord support
//

import SwiftUI
import UniformTypeIdentifiers

struct ImageInspectorView: View {
    @ObservedObject var viewModel: ImageInspectorViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var lightboxImage: NSImage?

    // Layout state indicator
    @State private var stageIndicatorVisible = true
    @State private var stageHovering = false
    @State private var indicatorTask: Task<Void, Never>?

    @State private var selectedRightTab: RightPanelTab = .metadata
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                collectionSidebar
                    .frame(width: leftColumnWidth)
                    .clipped()
                    .allowsHitTesting(leftColumnWidth > 0)

                imageStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                rightPanel
                    .frame(width: rightColumnWidth)
                    .clipped()
                    .allowsHitTesting(rightColumnWidth > 0)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: viewModel.layoutState)

            Divider()

            filmstripPlaceholder
                .frame(height: 104)
        }
        .padding(20)
        .neuBackground()
        .lightbox(image: $lightboxImage, browseList: viewModel.filteredHistory.map(\.image))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                layoutStatePicker
            }
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress(.upArrow)    { viewModel.selectPrevious(); return .handled }
        .onKeyPress(.leftArrow)  { viewModel.selectPrevious(); return .handled }
        .onKeyPress(.downArrow)  { viewModel.selectNext(); return .handled }
        .onKeyPress(.rightArrow) { viewModel.selectNext(); return .handled }
        .onAppear { isFocused = true; scheduleIndicatorFade() }
        .onChange(of: viewModel.layoutState) {
            withAnimation(.easeIn(duration: 0.15)) { stageIndicatorVisible = true }
            scheduleIndicatorFade()
        }
        .onChange(of: viewModel.sourceFilter) {
            // If selected image is no longer visible under new filter, pick first visible
            if let selected = viewModel.selectedImage,
               !viewModel.filteredHistory.contains(where: { $0.id == selected.id }) {
                viewModel.selectedImage = viewModel.filteredHistory.first
            }
        }
    }

    // MARK: - Column Widths

    private var leftColumnWidth: CGFloat {
        switch viewModel.layoutState {
        case .balanced:  return 200
        case .focus:     return 48
        case .immersive: return 0
        }
    }

    private var rightColumnWidth: CGFloat {
        switch viewModel.layoutState {
        case .balanced:  return 300
        case .focus:     return 44
        case .immersive: return 0
        }
    }

    // MARK: - Image Stage

    private var imageStage: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    if let selected = viewModel.selectedImage { lightboxImage = selected.image }
                }
                .onTapGesture(count: 1) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        viewModel.layoutState = viewModel.layoutState.next()
                    }
                }
                .onHover { hovering in
                    stageHovering = hovering
                    if hovering {
                        indicatorTask?.cancel()
                        withAnimation(.easeIn(duration: 0.15)) { stageIndicatorVisible = true }
                    } else {
                        scheduleIndicatorFade()
                    }
                }

            if let selected = viewModel.selectedImage {
                Image(nsImage: selected.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            } else {
                stageEmptyState
            }

            // State indicator: bottom-left, fades after 2s, reappears on hover
            Text(viewModel.layoutState.indicatorText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
                .padding(.leading, 12)
                .padding(.bottom, 12)
                .opacity((stageIndicatorVisible || stageHovering) ? 1 : 0)
                .animation(.easeOut(duration: 0.35), value: stageIndicatorVisible)
                .animation(.easeOut(duration: 0.35), value: stageHovering)
        }
    }

    private var stageEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.arrow.down")
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.2))
                .symbolEffect(.pulse, options: .repeating)
            Text("Drop an Image to Inspect")
                .font(.title3)
                .foregroundColor(.white.opacity(0.5))
            Text("Drag a PNG from Finder, Discord, or any app.\nSupports A1111/Forge, Draw Things, and ComfyUI metadata.")
                .font(.callout)
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
            Button("Open File…") { openFilePanel() }
                .buttonStyle(NeumorphicButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Right Panel (tabbed)

    private var rightPanel: some View {
        Group {
            if viewModel.layoutState == .focus {
                rightFocusRail
            } else {
                rightPanelContent
            }
        }
        .neuCard(cornerRadius: 20)
    }

    private var rightFocusRail: some View {
        VStack(spacing: 12) {
            Spacer()
            ForEach(RightPanelTab.allCases, id: \.self) { tab in
                Button {
                    selectedRightTab = tab
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        viewModel.layoutState = .balanced
                    }
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 14))
                        .foregroundColor(selectedRightTab == tab ? .neuAccent : .neuTextSecondary)
                }
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selectedRightTab == tab ? Color.neuAccent.opacity(0.12) : Color.clear)
                )
                .buttonStyle(.plain)
                .help(tab.label)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rightPanelContent: some View {
        VStack(spacing: 0) {
            rightTabBar
            Divider()
            Group {
                switch selectedRightTab {
                case .metadata:
                    DTImageInspectorMetadataView(
                        entry: viewModel.selectedImage,
                        errorMessage: viewModel.errorMessage
                    )
                case .assist:
                    assistTabContent
                case .actions:
                    actionsTabContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var rightTabBar: some View {
        HStack(spacing: 0) {
            ForEach(RightPanelTab.allCases, id: \.self) { tab in
                Button { selectedRightTab = tab } label: {
                    VStack(spacing: 0) {
                        Spacer()
                        Text(tab.label)
                            .font(.system(size: 12, weight: selectedRightTab == tab ? .semibold : .regular))
                            .foregroundColor(
                                selectedRightTab == tab
                                    ? Color(NSColor.labelColor)
                                    : Color(NSColor.secondaryLabelColor)
                            )
                            .padding(.bottom, 7)
                        Rectangle()
                            .fill(selectedRightTab == tab ? Color.accentColor : Color.clear)
                            .frame(height: 1.5)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 36)
            }
        }
    }

    private var assistTabContent: some View {
        DTImageInspectorAssistView(entry: viewModel.selectedImage, viewModel: viewModel)
    }

    private var actionsTabContent: some View {
        DTImageInspectorActionsView(entry: viewModel.selectedImage, viewModel: viewModel)
    }

    // MARK: - Filmstrip

    private var filmstripPlaceholder: some View { filmstrip }

    private var filmstrip: some View {
        HStack(spacing: 0) {
            // SIBLINGS section
            if !viewModel.filmstripSiblings.isEmpty {
                // Pinned label
                Text("SIBLINGS")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.neuTextSecondary.opacity(0.6))
                    .kerning(0.4)
                    .frame(width: 52)
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                    .frame(width: 18)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.filmstripSiblings) { entry in
                            FilmstripCell(
                                entry: entry,
                                isSelected: viewModel.selectedImage?.id == entry.id
                            )
                            .onTapGesture {
                                viewModel.selectedImage = entry
                                viewModel.errorMessage = nil
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }

                // Divider between sections
                Rectangle()
                    .fill(Color(NSColor.separatorColor).opacity(0.5))
                    .frame(width: 0.5, height: 56)
                    .padding(.horizontal, 4)
            }

            // HISTORY section
            if !viewModel.filmstripHistory.isEmpty {
                // Pinned label
                Text("HISTORY")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.neuTextSecondary.opacity(0.6))
                    .kerning(0.4)
                    .frame(width: 52)
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                    .frame(width: 18)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.filmstripHistory) { entry in
                            FilmstripCell(
                                entry: entry,
                                isSelected: viewModel.selectedImage?.id == entry.id
                            )
                            .onTapGesture {
                                viewModel.selectedImage = entry
                                viewModel.errorMessage = nil
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            } else if viewModel.filmstripSiblings.isEmpty {
                // Empty state — no images at all
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "film.stack")
                        .font(.caption)
                        .foregroundColor(.neuTextSecondary.opacity(0.3))
                    Text("Drop images to inspect")
                        .font(.caption2)
                        .foregroundColor(.neuTextSecondary.opacity(0.3))
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.neuBackground)
    }

    // MARK: - Layout Picker (Toolbar)

    private var layoutStatePicker: some View {
        HStack(spacing: 2) {
            ForEach(LayoutState.allCases, id: \.self) { state in
                Button(state.label) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        viewModel.layoutState = state
                    }
                }
                .buttonStyle(LayoutPillButtonStyle(isActive: viewModel.layoutState == state))
            }
        }
    }

    // MARK: - Indicator Timer

    private func scheduleIndicatorFade() {
        indicatorTask?.cancel()
        stageIndicatorVisible = true
        indicatorTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, !stageHovering else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                stageIndicatorVisible = false
            }
        }
    }

    // MARK: - Collection Sidebar (left column)

    private var collectionSidebar: some View {
        Group {
            if viewModel.layoutState == .focus {
                focusRailContent
            } else {
                balancedSidebarContent
            }
        }
        .neuCard(cornerRadius: 20)
    }

    private var balancedSidebarContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("COLLECTION")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.neuTextSecondary)
                    .kerning(0.5)
                Spacer()
                Button(action: importFilePanel) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(NeumorphicIconButtonStyle())
                .help("Import image")
                .accessibilityIdentifier("inspector_importButton")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Source filter tabs
            Picker("Source", selection: $viewModel.sourceFilter) {
                ForEach(SourceFilter.allCases, id: \.self) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .accessibilityIdentifier("inspector_sourceFilterPicker")

            // Thumbnail grid or empty state
            if viewModel.filteredHistory.isEmpty {
                sidebarEmptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3),
                        spacing: 4
                    ) {
                        ForEach(viewModel.filteredHistory) { entry in
                            CollectionThumbnailCell(
                                entry: entry,
                                isSelected: viewModel.selectedImage?.id == entry.id,
                                fixedSize: nil
                            )
                            .onTapGesture {
                                viewModel.selectedImage = entry
                                viewModel.errorMessage = nil
                            }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    viewModel.deleteImage(entry)
                                }
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var focusRailContent: some View {
        VStack(spacing: 6) {
            // Import button
            Button(action: importFilePanel) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(width: 28, height: 28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .buttonStyle(.plain)
            .help("Import image")
            .padding(.top, 8)

            // Mini thumbnails (32×32pt)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(viewModel.filteredHistory) { entry in
                        CollectionThumbnailCell(
                            entry: entry,
                            isSelected: viewModel.selectedImage?.id == entry.id,
                            fixedSize: 32
                        )
                        .onTapGesture {
                            viewModel.selectedImage = entry
                            viewModel.errorMessage = nil
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidebarEmptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "photo.badge.arrow.down")
                .font(.title2)
                .foregroundColor(.neuTextSecondary.opacity(0.4))
                .symbolEffect(.pulse, options: .repeating)
            Text("Drop images here")
                .font(.caption)
                .foregroundColor(.neuTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func historyRow(_ entry: InspectedImage) -> some View {
        HistoryRowView(
            entry: entry,
            isSelected: viewModel.selectedImage?.id == entry.id,
            onSelect: {
                viewModel.selectedImage = entry
                viewModel.errorMessage = nil
            },
            onDelete: {
                viewModel.deleteImage(entry)
            }
        )
    }


    // MARK: - Actions

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [viewModel] response in
            guard response == .OK, let url = panel.url else { return }
            viewModel.loadImage(url: url)
        }
    }

    private func importFilePanel() {
        let panel = NSOpenPanel()
        var types: [UTType] = [.png, .jpeg, .tiff, .image]
        if let webp = UTType(filenameExtension: "webp") { types.append(webp) }
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Import Image"
        panel.begin { [viewModel] response in
            guard response == .OK, let url = panel.url else { return }
            viewModel.loadImage(url: url, source: .imported(sourceURL: url))
        }
    }

}

// MARK: - Right Panel Tab

private enum RightPanelTab: CaseIterable {
    case metadata, assist, actions

    var label: String {
        switch self {
        case .metadata: return "Metadata"
        case .assist:   return "Assist"
        case .actions:  return "Actions"
        }
    }

    var icon: String {
        switch self {
        case .metadata: return "doc.text"
        case .assist:   return "wand.and.stars"
        case .actions:  return "square.and.arrow.up"
        }
    }
}

// MARK: - Layout Pill Button Style

private struct LayoutPillButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(isActive ? .white : Color(NSColor.secondaryLabelColor))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isActive ? Color.neuAccent : Color.clear)
                    .opacity(configuration.isPressed ? 0.75 : 1)
            )
    }
}

// MARK: - Collection Thumbnail Cell

private struct CollectionThumbnailCell: View {
    let entry: InspectedImage
    let isSelected: Bool
    let fixedSize: CGFloat?

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(nsImage: entry.image)
                .resizable()
                .aspectRatio(contentMode: .fill)

            // Source indicator dot
            Circle()
                .fill(entry.source.dotColor)
                .frame(width: 6, height: 6)
                .padding(3)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(width: fixedSize, height: fixedSize)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.6),
                    lineWidth: isSelected ? 2 : 0.5
                )
        )
        .scaleEffect(isHovered && !isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Filmstrip Cell

private struct FilmstripCell: View {
    let entry: InspectedImage
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Image(nsImage: entry.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 76, height: 76)
                .clipped()

            // Caption scrim + filename
            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 28)

            Text(entry.sourceName)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 4)
                .padding(.bottom, 3)
        }
        .frame(width: 76, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.5),
                    lineWidth: isSelected ? 2 : 0.5
                )
        )
    }
}

// MARK: - History Row View with Hover State

private struct HistoryRowView: View {
    let entry: InspectedImage
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var backgroundColor: Color {
        if isSelected {
            return Color.neuAccent.opacity(0.12)
        } else if isHovered {
            return Color.neuSurface.opacity(0.6)
        }
        return Color.clear
    }

    private var strokeColor: Color {
        if isSelected {
            return Color.neuAccent.opacity(0.3)
        } else if isHovered {
            return Color.neuShadowDark.opacity(0.1)
        }
        return Color.clear
    }

    private var scaleAmount: CGFloat {
        isHovered && !isSelected ? 1.02 : 1.0
    }

    private var accessibilityText: String {
        let metadataDesc = entry.metadata != nil ? entry.metadata!.format.rawValue + " metadata" : "no metadata"
        return "\(entry.sourceName), \(metadataDesc)"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: entry.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.sourceName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .truncationMode(.middle)

                metadataIndicator
            }

            Spacer(minLength: 0)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
        .scaleEffect(scaleAmount)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button("Delete") {
                onDelete()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var metadataIndicator: some View {
        HStack(spacing: 4) {
            if let meta = entry.metadata {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text(meta.format.rawValue)
                    .font(.caption2)
                    .foregroundColor(.neuTextSecondary)
            } else {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                Text("No metadata")
                    .font(.caption2)
                    .foregroundColor(.neuTextSecondary)
            }
        }
    }
}
