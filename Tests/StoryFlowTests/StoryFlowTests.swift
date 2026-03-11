import XCTest
@testable import StoryFlow

final class StoryFlowTests: XCTestCase {
    func testDrawThingsConfigDictionaryOmitsUnsetValues() {
        let config = DrawThingsConfig(width: 1024, steps: 30, model: "flux.safetensors")
        let dict = config.toDictionary()

        XCTAssertEqual(dict["width"] as? Int, 1024)
        XCTAssertEqual(dict["steps"] as? Int, 30)
        XCTAssertEqual(dict["model"] as? String, "flux.safetensors")
        XCTAssertNil(dict["height"])
        XCTAssertNil(dict["seed"])
    }

    func testSimpleSequenceGeneratorIncludesConfigAndPromptSavePairs() {
        let generator = StoryflowInstructionGenerator()
        let config = DrawThingsConfig(width: 512)
        let prompts = ["first scene", "second scene"]

        let instructions = generator.generateSimpleSequence(prompts: prompts, config: config)

        XCTAssertEqual(instructions.count, 5)
        let configDict = instructions[0]["config"] as? [String: Any]
        XCTAssertEqual(configDict?["width"] as? Int, 512)
        XCTAssertEqual(instructions[1]["prompt"] as? String, "first scene")
        XCTAssertEqual(instructions[2]["canvasSave"] as? String, "scene_0.png")
        XCTAssertEqual(instructions[3]["prompt"] as? String, "second scene")
        XCTAssertEqual(instructions[4]["canvasSave"] as? String, "scene_1.png")
    }

    func testExporterProducesSortedPrettyPrintedJSON() throws {
        let exporter = StoryflowExporter()
        let instructions: [[String: Any]] = [
            ["prompt": "hello"],
            ["canvasSave": "out.png"]
        ]

        let json = try exporter.exportToJSON(instructions: instructions)

        XCTAssertTrue(json.contains("\"prompt\""))
        XCTAssertTrue(json.contains("\"canvasSave\""))
        XCTAssertTrue(json.contains("\n"))
    }
}
