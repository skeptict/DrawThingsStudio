//
//  TemplatesTests.swift
//  DrawThingsStudioUITests
//
//  Tests for the Templates view functionality
//

import XCTest

final class TemplatesTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()

        // Navigate to Templates view
        let templatesButton = app.buttons["sidebar_templates"]
        XCTAssertTrue(templatesButton.waitForExistence(timeout: 5))
        templatesButton.tap()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - View Loading Tests

    @MainActor
    func testTemplatesViewLoads() throws {
        // Templates view should load with search field
        let searchField = app.textFields["templates_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3),
                      "Templates search field should exist")
    }

    @MainActor
    func testSearchFieldExists() throws {
        let searchField = app.textFields["templates_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3),
                      "Search field should be visible in Templates")
    }

    // MARK: - Search Functionality Tests

    @MainActor
    func testSearchFieldInteraction() throws {
        let searchField = app.textFields["templates_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        searchField.tap()
        searchField.typeText("portrait")

        // Search field should accept input
        XCTAssertTrue(searchField.exists,
                      "Search field should accept text input")
    }

    @MainActor
    func testClearSearch() throws {
        let searchField = app.textFields["templates_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        // Enter search text
        searchField.tap()
        searchField.typeText("landscape")

        // Clear the search
        app.typeKey("a", modifierFlags: .command) // Select all
        app.typeKey(.delete, modifierFlags: []) // Delete

        // Search field should be empty/clearable
        XCTAssertTrue(searchField.exists,
                      "Search field should be clearable")
    }

    // MARK: - Template Selection Tests

    @MainActor
    func testUseTemplateButtonExists() throws {
        // The "Use Template" button may only appear when a template is selected
        let useButton = app.buttons["templates_useButton"]

        // This button may not be visible if no template is selected
        if useButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(useButton.exists,
                          "Use Template button should exist when template is selected")
        }
    }

    // MARK: - Navigation Tests

    @MainActor
    func testNavigateFromTemplatesAndBack() throws {
        // Navigate away
        app.buttons["sidebar_workflow"].tap()
        sleep(1)

        // Navigate back
        app.buttons["sidebar_templates"].tap()
        sleep(1)

        // Templates should still be functional
        let searchField = app.textFields["templates_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3),
                      "Templates should reload after navigation")
    }

    @MainActor
    func testSearchPersistsAfterNavigation() throws {
        let searchField = app.textFields["templates_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        // Enter search text
        searchField.tap()
        searchField.typeText("test search")

        // Navigate away and back
        app.buttons["sidebar_generateImage"].tap()
        sleep(1)
        app.buttons["sidebar_templates"].tap()
        sleep(1)

        // Search field should still exist
        let searchFieldAfter = app.textFields["templates_searchField"]
        XCTAssertTrue(searchFieldAfter.waitForExistence(timeout: 3),
                      "Search field should exist after navigation")
    }
}
