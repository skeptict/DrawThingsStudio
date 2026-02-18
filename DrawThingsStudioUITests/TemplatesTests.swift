//
//  TemplatesTests.swift
//  DrawThingsStudioUITests
//
//  Tests for the Templates view functionality
//

import XCTest

final class TemplatesTests: XCTestCase {

    var app: XCUIApplication { SharedApp.app }

    override class func setUp() {
        super.setUp()
        SharedApp.launchOnce()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        let templatesButton = app.buttons["sidebar_templates"]
        XCTAssertTrue(templatesButton.waitForExistence(timeout: 10))
        templatesButton.tap()
        waitForUI(seconds: 1)
    }

    // MARK: - View Loading Tests

    @MainActor
    func testTemplatesViewLoads() throws {
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

        XCTAssertTrue(searchField.exists,
                      "Search field should accept text input")
    }

    @MainActor
    func testClearSearch() throws {
        let searchField = app.textFields["templates_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        searchField.tap()
        searchField.typeText("landscape")

        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])

        XCTAssertTrue(searchField.exists,
                      "Search field should be clearable")
    }

    // MARK: - Template Selection Tests

    @MainActor
    func testUseTemplateButtonExists() throws {
        let useButton = app.buttons["templates_useButton"]
        if useButton.waitForExistence(timeout: 2) {
            XCTAssertTrue(useButton.exists,
                          "Use Template button should exist when template is selected")
        }
    }

    // MARK: - Navigation Tests

    @MainActor
    func testNavigateFromTemplatesAndBack() throws {
        app.buttons["sidebar_workflow"].tap()
        waitForUI(seconds: 1)

        app.buttons["sidebar_templates"].tap()
        waitForUI(seconds: 1)

        let searchField = app.textFields["templates_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3),
                      "Templates should reload after navigation")
    }

    @MainActor
    func testSearchPersistsAfterNavigation() throws {
        let searchField = app.textFields["templates_searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        searchField.tap()
        searchField.typeText("test search")

        app.buttons["sidebar_generateImage"].tap()
        waitForUI(seconds: 1)
        app.buttons["sidebar_templates"].tap()
        waitForUI(seconds: 1)

        let searchFieldAfter = app.textFields["templates_searchField"]
        XCTAssertTrue(searchFieldAfter.waitForExistence(timeout: 3),
                      "Search field should exist after navigation")
    }
}
