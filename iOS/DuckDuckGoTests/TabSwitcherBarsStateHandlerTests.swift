//
//  TabSwitcherBarsStateHandlerTests.swift
//  DuckDuckGo
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import XCTest
import Core

@testable import DuckDuckGo

class TabSwitcherBarsStateHandlerTests: XCTestCase {

    var stateHandler: TabSwitcherBarsStateHandler!

    override func setUp() {
        super.setUp()
        stateHandler = TabSwitcherBarsStateHandler()
    }

    override func tearDown() {
        stateHandler = nil
        super.tearDown()
    }

    func testWhenDuckChatEnabledThenBottomBarItemsAreSetCorrectly() {
        stateHandler.update(.regularSize, selectedTabsCount: 0, totalTabsCount: 0, containsWebPages: false, showAIChatButton: true)

        XCTAssertEqual(stateHandler.bottomBarItems, [
            stateHandler.tabSwitcherStyleButton,
            UIBarButtonItem.flexibleSpace(),
            UIBarButtonItem.fixedSpace(11),
            UIBarButtonItem.flexibleSpace(),
            stateHandler.fireButton,
            UIBarButtonItem.flexibleSpace(),
            stateHandler.duckChatButton,
            UIBarButtonItem.flexibleSpace(),
            stateHandler.plusButton
        ])
        XCTAssertFalse(stateHandler.isBottomBarHidden)
    }

    func testWhenInterfaceModeIsEditingRegularSizeThenBottomBarItemsAreSetCorrectly() {
        stateHandler.update(.editingRegularSize, selectedTabsCount: 0, totalTabsCount: 0, containsWebPages: false, showAIChatButton: false)

        XCTAssertEqual(stateHandler.bottomBarItems, [
            stateHandler.closeTabsButton,
            UIBarButtonItem.flexibleSpace(),
            stateHandler.menuButton
        ])
        XCTAssertFalse(stateHandler.isBottomBarHidden)
    }

    func testWhenInterfaceModeIsEditingLargeThenBottomBarIsHidden() {
        stateHandler.update(.editingLargeSize, selectedTabsCount: 0, totalTabsCount: 0, containsWebPages: false, showAIChatButton: false)

        XCTAssertTrue(stateHandler.bottomBarItems.isEmpty)
        XCTAssertTrue(stateHandler.isBottomBarHidden)
    }

    func testWhenInterfaceModeIsRegularSizeThenTopRightButtonItemsAreSetCorrectly() {
        stateHandler.update(.regularSize, selectedTabsCount: 0, totalTabsCount: 2, containsWebPages: false, showAIChatButton: false)

        XCTAssertEqual(stateHandler.topBarRightButtonItems, [
            stateHandler.doneButton
        ])
    }

    func testWhenInterfaceModeIsEditingRegularSizeThenTopRightButtonItemsAreSetCorrectly() {
        stateHandler.update(.editingRegularSize, selectedTabsCount: 0, totalTabsCount: 2, containsWebPages: false, showAIChatButton: false)

        XCTAssertEqual(stateHandler.topBarRightButtonItems, [
            stateHandler.selectAllButton
        ])
    }

    func testWhenShowAIChatButtonIsTrueThenDuckChatButtonIsIncludedInToolbarItems() {
        stateHandler.update(.regularSize, selectedTabsCount: 0, totalTabsCount: 0, containsWebPages: false, showAIChatButton: true)

        XCTAssertTrue(stateHandler.bottomBarItems.contains(stateHandler.duckChatButton))
    }

    func testWhenTotalTabsCountIsGreaterThanOneThenCanShowEditButtonIsTrue() {
        stateHandler.update(.regularSize, selectedTabsCount: 0, totalTabsCount: 2, containsWebPages: false, showAIChatButton: false)

        XCTAssertTrue(stateHandler.canShowEditButton)
    }

    func testWhenContainsWebPagesIsTrueThenCanShowEditButtonIsTrue() {
        stateHandler.update(.regularSize, selectedTabsCount: 0, totalTabsCount: 0, containsWebPages: true, showAIChatButton: false)

        XCTAssertTrue(stateHandler.canShowEditButton)
    }

    func testWhenInterfaceModeIsLargeSizeThenBottomBarIsHidden() {
        stateHandler.update(.largeSize, selectedTabsCount: 0, totalTabsCount: 0, containsWebPages: false, showAIChatButton: false)

        XCTAssertTrue(stateHandler.bottomBarItems.isEmpty)
        XCTAssertTrue(stateHandler.isBottomBarHidden)
    }

    func testWhenInterfaceModeIsEditingRegularSizeThenTopLeftButtonItemsAreSetCorrectly() {
        stateHandler.update(.editingRegularSize, selectedTabsCount: 0, totalTabsCount: 2, containsWebPages: false, showAIChatButton: false)

        XCTAssertEqual(stateHandler.topBarLeftButtonItems, [
            stateHandler.doneButton
        ])
    }

    func testWhenInterfaceModeIsLargeSizeThenTopLeftButtonItemsAreSetCorrectly() {
        stateHandler.update(.largeSize, selectedTabsCount: 0, totalTabsCount: 2, containsWebPages: false, showAIChatButton: false)

        XCTAssertEqual(stateHandler.topBarLeftButtonItems, [
            stateHandler.editButton,
            stateHandler.tabSwitcherStyleButton
        ])
    }

    func testWhenInterfaceModeIsLargeSizeAndCannotShowEditButtonThenTopLeftButtonItemsAreSetCorrectly() {
        stateHandler.update(.largeSize, selectedTabsCount: 0, totalTabsCount: 0, containsWebPages: false, showAIChatButton: false)

        XCTAssertEqual(stateHandler.topBarLeftButtonItems, [
            stateHandler.tabSwitcherStyleButton
        ])
    }

    func testWhenInterfaceModeIsLargeSizeThenTopRightButtonItemsAreSetCorrectly() {
        stateHandler.update(.largeSize, selectedTabsCount: 0, totalTabsCount: 0, containsWebPages: false, showAIChatButton: true)

        XCTAssertEqual(stateHandler.topBarRightButtonItems, [
            stateHandler.doneButton,
            stateHandler.fireButton,
            stateHandler.plusButton,
            stateHandler.duckChatButton,
        ])
    }

}
