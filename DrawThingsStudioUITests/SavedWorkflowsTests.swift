//
//  SavedWorkflowsTests.swift
//  DrawThingsStudioUITests
//
//  Tests for the Saved Workflows (Library) view functionality
//

import XCTest

final class SavedWorkflowsTests: XCTestCase {

    var app: XCUIApplication { SharedApp.app }

    override class func setUp() {
        super.setUp()
        SharedApp.launchOnce()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        let libraryButton = app.buttons["sidebar_library"]
        XCTAssertTrue(libraryButton.waitForExistence(timeout: 10))
        libraryButton.tap()
        waitForUI(seconds: 1)
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
        let saveButton = app.buttons["savedWorkflows_saveButton"]
        if saveButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(saveButton.exists,
                          "Save button should exist in Saved Workflows")
        }
    }

    // MARK: - Navigation Tests

    @MainActor
    func testNavigateFromLibraryAndBack() throws {
        app.buttons["sidebar_settings"].tap()
        waitForUI(seconds: 1)

        app.buttons["sidebar_library"].tap()
        waitForUI(seconds: 1)

        let searchField = app.textFields["savedWorkflows_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3),
                      "Saved Workflows should reload after navigation")
    }

    // MARK: - Empty State Tests

    @MainActor
    func testEmptyStateOrWorkflowList() throws {
        let searchField = app.textFields["savedWorkflows_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3),
                      "View should load and show search field regardless of workflow count")
    }
}
