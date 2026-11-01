import XCTest

final class SinoDefenceUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDemoNewPostsAndThread() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-resetTabs"]
        app.launch()

        XCTAssertTrue(app.staticTexts["New posts"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["CV-18 Fujian/003 CATOBAR carrier thread"].waitForExistence(timeout: 5))

        app.staticTexts["CV-18 Fujian/003 CATOBAR carrier thread"].tap()
        XCTAssertTrue(app.staticTexts["CV-18 Fujian/003 CATOBAR carrier thread"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Demo Member said:"].waitForExistence(timeout: 5))

        let quote = app.buttons["Quote post"].firstMatch
        XCTAssertTrue(quote.waitForExistence(timeout: 5))
        quote.tap()
        XCTAssertTrue(app.staticTexts["Reply"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["subjectField"].exists)
        XCTAssertTrue(app.buttons["Post Reply"].isEnabled)
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testDemoBoardTabsAreDistinct() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-resetTabs"]
        app.launch()

        XCTAssertTrue(app.staticTexts["New posts"].waitForExistence(timeout: 10))

        let announce = app.buttons["Announce"]
        XCTAssertTrue(announce.waitForExistence(timeout: 5))
        announce.tap()
        XCTAssertTrue(app.staticTexts["Forum rules and updates"].waitForExistence(timeout: 5))

        let feedback = app.buttons["Feedback"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 5))
        feedback.tap()
        XCTAssertTrue(app.staticTexts["Reporting Problems"].waitForExistence(timeout: 5))

        let strategic = app.buttons["Strategic"]
        XCTAssertTrue(strategic.waitForExistence(timeout: 5))
        strategic.tap()
        XCTAssertTrue(app.staticTexts["China's Space Program Thread II"].waitForExistence(timeout: 5))

        XCTAssertFalse(app.buttons["More"].exists)
        let forums = app.buttons["Forums"]
        XCTAssertTrue(forums.waitForExistence(timeout: 5))
        forums.tap()
        XCTAssertTrue(app.staticTexts["Army"].waitForExistence(timeout: 5))
    }
}
