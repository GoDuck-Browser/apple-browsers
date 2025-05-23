//
//  UpdateMenuItemFactory.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

#if SPARKLE

import Cocoa

final class UpdateMenuItemFactory {

    static func menuItem(for update: Update) -> NSMenuItem {
        let item = NSMenuItem(title: UserText.updateAvailableMenuItem)
        item.target = Application.appDelegate.updateController
        item.action = #selector(UpdateController.runUpdateFromMenuItem)
        item.image = NSImage.updateMenuItemIcon
        return item
    }

    static func menuItem(for controller: UpdateControllerProtocol) -> NSMenuItem {

        let title: String

        if controller.isAtRestartCheckpoint && !controller.shouldForceUpdateCheck {
            title = UserText.updateReadyMenuItem
        } else {
            title = UserText.updateNewVersionAvailableMenuItem
        }

        let item = NSMenuItem(title: title)
        item.target = Application.appDelegate.updateController
        item.action = #selector(UpdateController.runUpdateFromMenuItem)
        item.image = NSImage.updateMenuItemIcon
        return item
    }

}

#endif
