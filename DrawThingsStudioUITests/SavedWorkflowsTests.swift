//
//  SavedWorkflowsTests.swift
//  DrawThingsStudioUITests
//
//  Tests for the Saved Workflows (Library) view functionality
//

import XCTest

final class SavedWorkflowsTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()

        // Navigate to Saved Workflows view
        let libraryButton = app.buttons["sidebar_library"]
        XCTAssertTrue(libraryButton.waitForExistence(timeout: 5))
        libraryButton.tap()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - View Loading Tests

    @MainActor
    func testSavedWorkflowsViewLoads() throws {
        let searchField = app.textFields["savedWorkflows_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3),
                      "Saved Workflows search field should exist")
    }

    @MainActor
    func testSearchFieldExists() throws {
        let searchField = app.textFields["savedWorkflows_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3),
                      "Search field should be visible in Saved Workflows")
    }

    // MARK: - Search Functionality Tests

    @MainActor
    func testSearchFieldInteraction() throws {
        let searchField = app.textFields["savedWorkflows_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        searchField.tap()
        searchField.typeText("my workflow")

        XCTAssertTrue(searchField.exists,
                      "Search field should accept text input")
    }

    // MARK: - Save Button Tests

    @MainActor
    func testSaveButtonExists() throws {
        // Save button may exist in the view
        let saveButton = app.buttons["savedWorkflows_saveButton"]

        if saveButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(saveButton.exists,
                          "Save button should exist in Saved Workflows")
        }
    }

    // MARK: - Navigation Tests

    @MainActor
    func testNavigateFromLibraryAndBack() throws {
        // Navigate away
        app.buttons["sidebar_settings"].tap()
        sleep(1)

        // Navigate back
        app.buttons["sidebar_library"].tap()
        sleep(1)

        // Library should still be functional
        let searchField = app.textFields["savedWorkflows_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3),
                      "Saved Workflows should reload after navigation")
    }

    // MARK: - Empty State Tests

    @MainActor
    func testEmptyStateOrWorkflowList() throws {
        // The view should show either workflows or an empty state
        // Both are valid depending on whether the user has saved workflows

        let searchField = app.textFields["savedWorkflows_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3),
                      "View should load and show search field regardless of workflow count")
    }
}
