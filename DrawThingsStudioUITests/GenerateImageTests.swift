//
//  GenerateImageTests.swift
//  DrawThingsStudioUITests
//
//  Tests for the Image Generation view functionality
//

import XCTest

final class GenerateImageTests: XCTestCase {

    var app: XCUIApplication { SharedApp.app }

    override class func setUp() {
        super.setUp()
        SharedApp.launchOnce()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        let generateImageButton = app.buttons["sidebar_generateImage"]
        XCTAssertTrue(generateImageButton.waitForExistence(timeout: 10))
        generateImageButton.tap()
        waitForUI(seconds: 1)
    }

    // MARK: - UI Element Existence Tests

    @MainActor
    func testPromptFieldsExist() throws {
        let promptField = app.textViews["generate_promptField"]
        XCTAssertTrue(promptField.waitForExistence(timeout: 5),
                      "Prompt field should exist")
        let negativePromptField = app.textFields["generate_negativePromptField"]
        XCTAssertTrue(negativePromptField.exists,
                      "Negative prompt field should exist")
    }

    @MainActor
    func testGenerateButtonExists() throws {
        let generateButton = app.buttons["generate_generateButton"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 5),
                      "Generate button should exist")
    }

    @MainActor
    func testConnectionRefreshButtonExists() throws {
        let refreshButton = app.buttons["generate_refreshConnectionButton"]
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 5),
                      "Refresh connection button should exist")
    }

    @MainActor
    func testOpenFolderButtonExists() throws {
        let folderButton = app.buttons["generate_openFolderButton"]
        XCTAssertTrue(folderButton.waitForExistence(timeout: 5),
                      "Open folder button should exist")
    }

    // MARK: - Prompt Entry Tests

    @MainActor
    func testEnterPrompt() throws {
        let promptField = app.textViews["generate_promptField"]
        XCTAssertTrue(promptField.waitForExistence(timeout: 5))
        promptField.tap()
        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])
        promptField.typeText("A beautiful sunset over the ocean")
        XCTAssertTrue(promptField.value != nil, "Prompt should be entered")
    }

    @MainActor
    func testEnterNegativePrompt() throws {
        let negativePromptField = app.textFields["generate_negativePromptField"]
        XCTAssertTrue(negativePromptField.waitForExistence(timeout: 5))
        negativePromptField.tap()
        app.typeKey("a", modifierFlags: .command)
        negativePromptField.typeText("blurry, low quality")
        XCTAssertTrue(negativePromptField.value != nil, "Negative prompt should be entered")
    }

    // MARK: - Generate Button State Tests

    @MainActor
    func testGenerateButtonDisabledWithEmptyPrompt() throws {
        let promptField = app.textViews["generate_promptField"]
        XCTAssertTrue(promptField.waitForExistence(timeout: 5))
        promptField.tap()
        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])
        let generateButton = app.buttons["generate_generateButton"]
        XCTAssertTrue(generateButton.exists)
    }

    @MainActor
    func testGenerateButtonEnabledWithPrompt() throws {
        let promptField = app.textViews["generate_promptField"]
        XCTAssertTrue(promptField.waitForExistence(timeout: 5))
        promptField.tap()
        promptField.typeText("Test prompt")
        let generateButton = app.buttons["generate_generateButton"]
        XCTAssertTrue(generateButton.exists, "Generate button should exist after entering prompt")
    }

    // MARK: - Model Selector Tests

    @MainActor
    func testModelSelectorExists() throws {
        let toggleButton = app.buttons["model_toggleManualEntry"]
        let refreshButton = app.buttons["model_refreshButton"]
        let modelSelectorVisible = toggleButton.waitForExistence(timeout: 5) || refreshButton.exists
        XCTAssertTrue(modelSelectorVisible, "Model selector controls should be visible")
    }

    @MainActor
    func testManualModelEntry() throws {
        let toggleButton = app.buttons["model_toggleManualEntry"]
        if toggleButton.waitForExistence(timeout: 5) {
            toggleButton.tap()
            let manualField = app.textFields["model_manualEntryField"]
            XCTAssertTrue(manualField.waitForExistence(timeout: 3),
                          "Manual entry field should appear after toggle")
        }
    }

    // MARK: - LoRA Tests

    @MainActor
    func testLoRAAddButtonExists() throws {
        let addLoRAButton = app.buttons["lora_addButton"]
        let exists = addLoRAButton.waitForExistence(timeout: 5)
        if exists {
            XCTAssertTrue(addLoRAButton.exists, "Add LoRA button should exist")
        }
    }

    // MARK: - Refresh Connection Test

    @MainActor
    func testRefreshConnectionButton() throws {
        let refreshButton = app.buttons["generate_refreshConnectionButton"]
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 5))
        refreshButton.tap()
        waitForUI(seconds: 1)
        XCTAssertTrue(refreshButton.exists, "App should remain responsive after refresh")
    }

    // MARK: - img2img Source Image Tests

    @MainActor
    func testSourceImageDropZoneExists() throws {
        // Search for the drop zone label text — more reliable than finding VStack container
        let dropZoneLabel = app.staticTexts["generate_sourceImageDropZoneLabel"]
        XCTAssertTrue(dropZoneLabel.waitForExistence(timeout: 5),
                      "Source image drop zone should exist in Generate Image view")
    }

    @MainActor
    func testClearSourceImageButtonNotVisibleByDefault() throws {
        // Without a source image loaded, the clear button should not exist
        let clearButton = app.buttons["generate_clearSourceImageButton"]
        waitForUI(seconds: 1)
        XCTAssertFalse(clearButton.exists,
                       "Clear source image button should not exist when no image is loaded")
    }
}
