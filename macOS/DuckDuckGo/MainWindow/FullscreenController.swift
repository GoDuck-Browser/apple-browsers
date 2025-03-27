//
//  FullscreenController.swift
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


import Cocoa
import WebKit

final class FullscreenController {

    private(set) var shouldPreventFullscreenExit: Bool = false

    func setShouldPreventFullscreenExit(_ value: Bool) {
        shouldPreventFullscreenExit = value
    }

    func manuallyExitFullscreen(window: NSWindow?) {
        guard let window = window, window.styleMask.contains(.fullScreen) else {
            return
        }
        shouldPreventFullscreenExit = false

        // Exit full screen
        window.toggleFullScreen(nil)
    }

    func handleFullscreenExitDecision(tagName: String?, window: NSWindow?) {
        if let tag = tagName, ["INPUT", "TEXTAREA", "DIV"].contains(tag) {
            // Website is likely handling ESC. Staying in full-screen
        } else {
            // Website is not handling ESC. Exiting full-screen manually
            manuallyExitFullscreen(window: window)
        }
    }
}
