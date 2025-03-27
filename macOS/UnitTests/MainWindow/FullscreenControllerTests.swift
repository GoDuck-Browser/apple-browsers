//
//  FullscreenControllerTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class FullscreenControllerTests: XCTestCase {

    @MainActor
    func testWhenSetShouldPreventFullscreenExitIsCalledThenFlagIsUpdated() {
        let controller = FullscreenController()
        controller.setShouldPreventFullscreenExit(true)
        XCTAssertTrue(controller.shouldPreventFullscreenExit)

        controller.setShouldPreventFullscreenExit(false)
        XCTAssertFalse(controller.shouldPreventFullscreenExit)
    }

    @MainActor
    func testWhenManuallyExitFullscreenIsCalledWhileInFullscreenThenWindowExitsFullscreen() async throws {
        let controller = FullscreenController()
        let window = try XCTUnwrap(WindowsManager.openNewWindow(isFullscreen: true))
        try? await Task.sleep(interval: 3)

        controller.manuallyExitFullscreen(window: window)

        try? await Task.sleep(interval: 3)

        XCTAssertFalse(window.styleMask.contains(.fullScreen))
    }

    @MainActor
    func testWhenManuallyExitFullscreenIsCalledWhileNotInFullscreenThenWindowStaysInNormalState() async throws {
        let controller = FullscreenController()
        let window = try XCTUnwrap(WindowsManager.openNewWindow(isFullscreen: false))

        controller.manuallyExitFullscreen(window: window)

        try? await Task.sleep(interval: 3)

        XCTAssertFalse(window.styleMask.contains(.fullScreen))
    }

    @MainActor
    func testWhenHandleEscapePressIsCalledAndWebsiteHandlesEscapeThenWindowStaysInFullscreen() async throws {
        let controller = FullscreenController()
        controller.setShouldPreventFullscreenExit(true)

        let window = try XCTUnwrap(WindowsManager.openNewWindow(isFullscreen: true))
        try? await Task.sleep(interval: 3)

        controller.handleEscapePress(handledByWebsite: true, window: window)

        try? await Task.sleep(interval: 3)

        XCTAssertTrue(window.styleMask.contains(.fullScreen))
        XCTAssertTrue(controller.shouldPreventFullscreenExit)
    }

    @MainActor
    func testWhenHandleEscapePressIsCalledAndWebsiteDoesNotHandleEscapeThenWindowExitsFullscreenAndFlagResets() async throws {
        let controller = FullscreenController()
        controller.setShouldPreventFullscreenExit(true)

        let window = try XCTUnwrap(WindowsManager.openNewWindow(isFullscreen: true))
        try? await Task.sleep(interval: 3)

        controller.handleEscapePress(handledByWebsite: false, window: window)

        try? await Task.sleep(interval: 3)

        XCTAssertFalse(window.styleMask.contains(.fullScreen))
        XCTAssertFalse(controller.shouldPreventFullscreenExit)
    }
}
