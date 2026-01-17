import Foundation
#if os(macOS)
import AppKit
#endif

enum ExportError: Error {
    case encodingFailed
}

class StoryflowExporter {
    
    func exportToJSON(instructions: [[String: Any]]) throws -> String {
        let jsonData = try JSONSerialization.data(
            withJSONObject: instructions,
            options: [.prettyPrinted, .sortedKeys]
        )
        
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        return jsonString
    }
    
    func exportToFile(instructions: [[String: Any]], filename: String) throws -> URL {
        let jsonString = try exportToJSON(instructions: instructions)
        
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
            .appendingPathExtension("txt")
        
        try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    #if os(macOS)
    func copyToClipboard(instructions: [[String: Any]]) throws {
        let jsonString = try exportToJSON(instructions: instructions)
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonString, forType: .string)
    }
    #endif
}
