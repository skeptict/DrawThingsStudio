//
//  DTImageSource.swift
//  DrawThingsStudio
//
//  Source provenance for images in the collection.
//

import SwiftUI

/// Where an image in the collection came from.
enum DTImageSource: Equatable {
    case drawThings(projectURL: URL?)
    case civitai(sourceURL: URL?)
    case imported(sourceURL: URL?)
    case unknown

    /// Fill color for the 6×6pt source indicator dot on thumbnails.
    var dotColor: Color {
        switch self {
        case .drawThings: return Color(red: 0x28/255, green: 0xC8/255, blue: 0x40/255) // #28C840
        case .civitai:    return Color(red: 0xFF/255, green: 0xBD/255, blue: 0x2E/255) // #FFBD2E
        case .imported, .unknown:
            return Color(red: 0x88/255, green: 0x87/255, blue: 0x80/255)               // #888780
        }
    }

    /// Returns true if this source matches the given filter tab.
    func matches(_ filter: SourceFilter) -> Bool {
        switch filter {
        case .all: return true
        case .drawThings:
            if case .drawThings = self { return true }
            return false
        case .imported:
            switch self {
            case .drawThings: return false
            default: return true
            }
        }
    }
}

/// Filter tabs shown above the collection thumbnail grid.
enum SourceFilter: String, CaseIterable {
    case all, drawThings, imported

    var label: String {
        switch self {
        case .all:        return "All"
        case .drawThings: return "Draw Things"
        case .imported:   return "Imported"
        }
    }
}
