//
//  TabSwitcherDelegate.swift
//  DuckDuckGo
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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

import Core

protocol TabSwitcherDelegate: AnyObject {

    func tabSwitcherDidRequestNewTab(tabSwitcher: TabSwitcherViewController)

    func tabSwitcher(_ tabSwitcher: TabSwitcherViewController, didSelectTab tab: Tab)

    func tabSwitcher(_ tabSwitcher: TabSwitcherViewController, didRemoveTab tab: Tab)
    
    func tabSwitcher(_ tabSwitcher: TabSwitcherViewController, editBookmarkForUrl url: URL)

    func tabSwitcherDidRequestForgetAll(tabSwitcher: TabSwitcherViewController)
    
    func tabSwitcherDidRequestCloseAll(tabSwitcher: TabSwitcherViewController)

    func tabSwitcherDidReorderTabs(tabSwitcher: TabSwitcherViewController)
    
    func tabSwitcherDidBulkCloseTabs(tabSwitcher: TabSwitcherViewController)

    func tabSwitcherDidRequestAIChat(tabSwitcher: TabSwitcherViewController)

}
