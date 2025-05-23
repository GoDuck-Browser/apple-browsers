//
//  WebExtensionsDebugMenu.swift
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

#if WEB_EXTENSIONS_ENABLED

@available(macOS 15.4, *)
final class WebExtensionsDebugMenu: NSMenu {

    private let webExtensionManager: WebExtensionManaging

    private let installExtensionMenuItem = NSMenuItem(title: "Install web extension...", action: #selector(WebExtensionsDebugMenu.selectAndLoadWebExtension))
    private let uninstallAllExtensionsMenuItem = NSMenuItem(title: "Uninstall all extensions", action: #selector(WebExtensionsDebugMenu.uninstallAllExtensions))

    init(webExtensionManager: WebExtensionManaging = WebExtensionManager.shared) {
        self.webExtensionManager = webExtensionManager
        super.init(title: "")

        installExtensionMenuItem.target = self
        installExtensionMenuItem.isEnabled = webExtensionManager.areExtenstionsEnabled
        uninstallAllExtensionsMenuItem.target = self
        uninstallAllExtensionsMenuItem.isEnabled = webExtensionManager.areExtenstionsEnabled && webExtensionManager.hasInstalledExtensions

        addItems()
    }

    private func addItems() {
        removeAllItems()

        addItem(installExtensionMenuItem)
        addItem(uninstallAllExtensionsMenuItem)

        if !webExtensionManager.webExtensionPaths.isEmpty {
            addItem(.separator())
            for webExtensionPath in webExtensionManager.webExtensionPaths {
                let name = webExtensionManager.extensionName(from: webExtensionPath)
                self.addItem(WebExtensionMenuItem(webExtensionPath: webExtensionPath,
                                                  webExtensionName: name))
            }
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update() {
        super.update()

        addItems()

        installExtensionMenuItem.isEnabled = webExtensionManager.areExtenstionsEnabled
        uninstallAllExtensionsMenuItem.isEnabled = webExtensionManager.areExtenstionsEnabled && webExtensionManager.hasInstalledExtensions
    }

    @objc func selectAndLoadWebExtension() {
        let panel = NSOpenPanel(allowedFileTypes: [.directory], directoryURL: .downloadsDirectory)
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        guard case .OK = panel.runModal(),
              let url = panel.url else { return }

        Task {
            await webExtensionManager.installExtension(path: url.absoluteString)
        }
    }

    @objc func uninstallAllExtensions() {
        webExtensionManager.uninstallAllExtensions()
    }

}

@available(macOS 15.4, *)
final class WebExtensionMenuItem: NSMenuItem {

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(webExtensionPath: String, webExtensionName: String?) {
        super.init(title: webExtensionName ?? webExtensionPath,
                   action: nil,
                   keyEquivalent: "")
        submenu = WebExtensionSubMenu(webExtensionPath: webExtensionPath)
    }

}

@available(macOS 15.4, *)
final class WebExtensionSubMenu: NSMenu {

    private let webExtensionPath: String
    private let webExtensionManager: WebExtensionManaging

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(webExtensionPath: String, webExtensionManager: WebExtensionManaging = WebExtensionManager.shared) {
        self.webExtensionManager = webExtensionManager
        self.webExtensionPath = webExtensionPath
        super.init(title: "")

        buildItems {
            NSMenuItem(title: "Remove the extension", action: #selector(uninstallExtension), target: self)
        }
    }

    @objc func uninstallExtension() {
        try? webExtensionManager.uninstallExtension(path: webExtensionPath)
    }

}

#endif
