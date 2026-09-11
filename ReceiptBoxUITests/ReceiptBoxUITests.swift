//
//  ReceiptBoxUITests.swift
//  ReceiptBoxUITests
//
//  Covers the core user flows end to end against the real app (real
//  SwiftData persistence, real navigation) — everything that doesn't need
//  camera or barcode hardware, which the simulator can't provide reliably.
//  Locale-independent by construction: tab bar items are found positionally
//  and screens reached via custom controls use accessibilityIdentifiers
//  (see the views under Features/) rather than matching localized button
//  text, so these pass regardless of the simulator's system language.
//
//  The app's SwiftData store persists on disk across runs (this isn't an
//  in-memory test target), so tests that create data clean up after
//  themselves rather than assuming a pristine, empty app.
//

import XCTest

final class ReceiptBoxUITests: XCTestCase {
    private enum Tab {
        static let home = 0
        static let scan = 1
        static let analytics = 2
        static let settings = 3
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeDisplaysCoreUIOnLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["ReceiptBox"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.tabBars.buttons.count, 4)
    }

    @MainActor
    func testNavigatingToReceiptsAndSearchingForSeededData() throws {
        let app = XCUIApplication()
        app.launch()

        let seeAllButton = app.buttons["home.seeAllButton"]
        XCTAssertTrue(seeAllButton.waitForExistence(timeout: 5))
        seeAllButton.tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Starbucks")

        // Seeded on first launch (SampleData.receipts) and never deleted by
        // any other test, so this should always be findable.
        let starbucksResult = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Starbucks")
        ).firstMatch
        XCTAssertTrue(starbucksResult.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddingAManualReceiptThenViewingAndDeletingIt() throws {
        let app = XCUIApplication()
        app.launch()

        let merchantName = "UITest Merchant \(Int(Date().timeIntervalSince1970))"

        // Home -> Add -> Manual Entry
        let addButton = app.buttons["home.addReceiptButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let manualOption = app.buttons["addReceipt.manualOption"]
        XCTAssertTrue(manualOption.waitForExistence(timeout: 5))
        manualOption.tap()

        let merchantField = app.textFields["manualEntry.merchantField"]
        XCTAssertTrue(merchantField.waitForExistence(timeout: 5))
        merchantField.tap()
        merchantField.typeText(merchantName)

        let totalField = app.textFields["manualEntry.totalField"]
        XCTAssertTrue(totalField.exists)
        totalField.tap()
        totalField.typeText("1234")

        let saveButton = app.buttons["manualEntry.saveButton"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        // Back on Home, the new receipt is the most recent -> visible without scrolling.
        let newReceiptRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", merchantName)
        ).firstMatch
        XCTAssertTrue(newReceiptRow.waitForExistence(timeout: 5))
        newReceiptRow.tap()

        // Receipt Detail shows the merchant name as its navigation title.
        XCTAssertTrue(app.navigationBars[merchantName].waitForExistence(timeout: 5))

        // Delete it via the overflow menu, then confirm.
        let moreButton = app.buttons["receiptDetail.moreButton"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 5))
        moreButton.tap()

        let deleteMenuItem = app.buttons["receiptDetail.deleteMenuItem"]
        XCTAssertTrue(deleteMenuItem.waitForExistence(timeout: 5))
        deleteMenuItem.tap()

        let confirmDeleteButton = app.buttons["receiptDetail.confirmDeleteButton"]
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 5))
        confirmDeleteButton.tap()

        // Deleting dismisses Receipt Detail (ReceiptDetailView watches the
        // store and dismisses itself once its receipt is gone).
        XCTAssertTrue(app.staticTexts["ReceiptBox"].waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", merchantName)).firstMatch.exists
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
