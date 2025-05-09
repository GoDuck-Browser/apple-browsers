//
//  NewTabPageLinkOpener.swift
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

import NewTabPage

struct NewTabPageLinkOpener: NewTabPageLinkOpening {

    @MainActor
    static func open(_ url: URL, source: Tab.Content.URLSource, sender: LinkOpenSender, target: LinkOpenTarget, sourceWindow: NSWindow?) {
        var tabCollectionViewModel: TabCollectionViewModel? {
            WindowControllersManager.shared.mainWindowController(for: sourceWindow)?.mainViewController.tabCollectionViewModel
        }
        let linkOpenBehavior: LinkOpenBehavior = {
            switch sender {
            case .userScript:
                // When using a real mouse, a middle click is sent as `.newTab`.
                // In this case, `NSApp.currentEvent` will be `.systemDefined` with no button number.
                LinkOpenBehavior(
                    event: NSApp.currentEvent,
                    switchToNewTabWhenOpenedPreference: TabsPreferences.shared.switchToNewTabWhenOpened,
                    // The frontend always sends `.newWindow` when activating a link with the Shift key pressed,
                    // which is a behavior specific to Windows. In this case we ignore the `.newWindow` target
                    // and let LinkOpenBehavior determine the necessary behavior.
                    canOpenLinkInCurrentTab: target != .newTab
                )
            case .contextMenuItem:
                switch target {
                case .current: .currentTab
                case .newTab: .newTab(selected: TabsPreferences.shared.switchToNewTabWhenOpened)
                case .newWindow: .newWindow(selected: TabsPreferences.shared.switchToNewTabWhenOpened)
                }
            }
        }()
        let targetWindowController = WindowControllersManager.shared.mainWindowController(for: sourceWindow ?? NSApp.currentEvent?.window)

        WindowControllersManager.shared.open(url, with: linkOpenBehavior, source: source, target: targetWindowController)
    }

    func openLink(_ target: NewTabPageDataModel.OpenAction.Target) async {
        switch target {
        case .settings:
            openAppearanceSettings()
        }
    }

    private func openAppearanceSettings() {
        Task.detached { @MainActor in
            WindowControllersManager.shared.showPreferencesTab(withSelectedPane: .appearance)
        }
    }
}
