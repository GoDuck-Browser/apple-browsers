//
//  HistoryViewActionsHandler.swift
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

import HistoryView
import SwiftUIExtensions

protocol HistoryViewBookmarksHandling: AnyObject {
    func isUrlBookmarked(url: URL) -> Bool
    func isUrlFavorited(url: URL) -> Bool
    func getBookmark(for url: URL) -> Bookmark?
    func markAsFavorite(_ bookmark: Bookmark)
    func addNewBookmark(for url: URL, title: String)
    func addNewFavorite(for url: URL, title: String)
}

extension LocalBookmarkManager: HistoryViewBookmarksHandling {
    func addNewBookmark(for url: URL, title: String) {
        addNewBookmark(for: url, title: title, isFavorite: false)
    }

    func addNewFavorite(for url: URL, title: String) {
        addNewBookmark(for: url, title: title, isFavorite: true)
    }

    private func addNewBookmark(for url: URL, title: String, isFavorite: Bool) {
        makeBookmark(for: url, title: title, isFavorite: isFavorite)
    }
}

final class HistoryViewActionsHandler: HistoryView.ActionsHandling {

    weak var dataProvider: HistoryViewDataProviding?
    private let bookmarkHandler: HistoryViewBookmarksHandling
    private var contextMenuResponse: DataModel.DeleteDialogResponse = .noAction
    private let deleteDialogPresenter: HistoryViewDeleteDialogPresenting
    private var deleteDialogTask: Task<DataModel.DeleteDialogResponse, Never>?

    init(
        dataProvider: HistoryViewDataProviding,
        deleteDialogPresenter: HistoryViewDeleteDialogPresenting = DefaultHistoryViewDeleteDialogPresenter(),
        bookmarkHandler: HistoryViewBookmarksHandling = LocalBookmarkManager.shared
    ) {
        self.dataProvider = dataProvider
        self.deleteDialogPresenter = deleteDialogPresenter
        self.bookmarkHandler = bookmarkHandler
    }

    func showDeleteDialog(for range: DataModel.HistoryRange) async -> DataModel.DeleteDialogResponse {
        guard let dataProvider else {
            return .noAction
        }

        let visitsCount = await dataProvider.countVisibleVisits(for: range)
        guard visitsCount > 0 else {
            return .noAction
        }

        switch await deleteDialogPresenter.showDialog(for: visitsCount) {
        case .burn:
            await dataProvider.burnVisits(for: range)
            return .delete
        case .delete:
            await dataProvider.deleteVisits(for: range)
            return .delete
        default:
            return .noAction
        }
    }

    func showDeleteDialog(for entries: [String]) async -> DataModel.DeleteDialogResponse {
        await showDeleteDialog(for: entries.compactMap(VisitIdentifier.init))
    }

    func showDeleteDialog(for searchTerm: String) async -> DataModel.DeleteDialogResponse {
        guard let dataProvider, !searchTerm.isEmpty else {
            return .noAction
        }

        let visitsCount = await dataProvider.countVisibleVisits(matching: searchTerm)

        switch await deleteDialogPresenter.showDialog(for: visitsCount) {
        case .burn:
            await dataProvider.burnVisits(matching: searchTerm)
            return .delete
        case .delete:
            await dataProvider.deleteVisits(matching: searchTerm)
            return .delete
        default:
            return .noAction
        }

    }

    @MainActor
    func showContextMenu(for entries: [String], using presenter: any ContextMenuPresenting) async -> DataModel.DeleteDialogResponse {
        contextMenuResponse = .noAction

        let identifiers = entries.compactMap(VisitIdentifier.init)
        guard !identifiers.isEmpty else {
            return .noAction
        }

        let urls = identifiers.map(\.url)
        let menu = NSMenu()

        menu.buildItems {
            NSMenuItem(
                title: urls.count == 1 ? UserText.openInNewTab : UserText.openAllInNewTabs,
                action: #selector(openInNewTab(_:)),
                target: self,
                representedObject: urls
            )
            .withAccessibilityIdentifier("HistoryView.openInNewTab")

            NSMenuItem(
                title: urls.count == 1 ? UserText.openInNewWindow : UserText.openAllTabsInNewWindow,
                action: #selector(openInNewWindow(_:)),
                target: self,
                representedObject: urls
            )
            .withAccessibilityIdentifier("HistoryView.openInNewWindow")

            NSMenuItem(
                title: urls.count == 1 ? UserText.openInNewFireWindow : UserText.openAllInNewFireWindow,
                action: #selector(openInNewFireWindow(_:)),
                target: self,
                representedObject: urls
            )
            .withAccessibilityIdentifier("HistoryView.openInNewFireWindow")

            NSMenuItem.separator()

            if urls.count == 1, let url = urls.first {
                NSMenuItem(title: UserText.showAllHistoryFromThisSite, action: #selector(showAllHistoryFromThisSite(_:)), target: self)
                    .withAccessibilityIdentifier("HistoryView.showAllHistoryFromThisSite")
                NSMenuItem.separator()
                NSMenuItem(title: UserText.copy, action: #selector(copy(_:)), target: self, representedObject: url)
                    .withAccessibilityIdentifier("HistoryView.copy")
                if !bookmarkHandler.isUrlBookmarked(url: url) {
                    NSMenuItem(title: UserText.addToBookmarks, action: #selector(addBookmarks(_:)), target: self, representedObject: [url])
                        .withAccessibilityIdentifier("HistoryView.addBookmark")
                }
                if !bookmarkHandler.isUrlFavorited(url: url) {
                    NSMenuItem(title: UserText.addToFavorites, action: #selector(addFavorite(_:)), target: self, representedObject: url)
                        .withAccessibilityIdentifier("HistoryView.addFavorite")
                }
            } else if urls.contains(where: { !bookmarkHandler.isUrlBookmarked(url: $0) }) {
                NSMenuItem(title: UserText.addAllToBookmarks, action: #selector(addBookmarks(_:)), target: self, representedObject: urls)
                    .withAccessibilityIdentifier("HistoryView.addBookmark")
            }

            NSMenuItem.separator()
            NSMenuItem(title: UserText.delete, action: #selector(delete(_:)), target: self, representedObject: identifiers)
                .withAccessibilityIdentifier("HistoryView.delete")
        }

        presenter.showContextMenu(menu)
        if let deleteDialogResponse = await deleteDialogTask?.value {
            deleteDialogTask = nil
            contextMenuResponse = deleteDialogResponse
        }
        return contextMenuResponse
    }

    @MainActor
    @objc private func openInNewTab(_ sender: NSMenuItem) {
        guard let urls = sender.representedObject as? [URL], let tabCollectionViewModel else {
            return
        }

        let tabs = urls.map { Tab(content: .url($0, source: .historyEntry), shouldLoadInBackground: true) }

        tabCollectionViewModel.append(tabs: tabs)
    }

    @MainActor
    @objc private func openInNewWindow(_ sender: NSMenuItem) {
        guard let urls = sender.representedObject as? [URL], let windowControllersManager else {
            return
        }

        let tabs = urls.map { Tab(content: .url($0, source: .historyEntry), shouldLoadInBackground: true) }

        let newTabCollection = TabCollection(tabs: tabs)
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: newTabCollection)
        windowControllersManager.openNewWindow(with: tabCollectionViewModel)
    }

    @MainActor
    @objc private func openInNewFireWindow(_ sender: NSMenuItem) {
        guard let urls = sender.representedObject as? [URL], let windowControllersManager else {
            return
        }

        let burnerMode = BurnerMode(isBurner: true)

        let tabs = urls.map { Tab(content: .url($0, source: .historyEntry), shouldLoadInBackground: true, burnerMode: burnerMode) }

        let newTabCollection = TabCollection(tabs: tabs)
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: newTabCollection, burnerMode: burnerMode)
        windowControllersManager.openNewWindow(with: tabCollectionViewModel, burnerMode: burnerMode)
    }

    @MainActor
    @objc private func copy(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else {
            return
        }
        NSPasteboard.general.copy(url)
    }

    @MainActor
    @objc private func addBookmarks(_ sender: NSMenuItem) {
        guard let dataProvider, let urls = sender.representedObject as? [URL] else {
            return
        }

        let titles = dataProvider.titles(for: urls)
        for url in urls {
            bookmarkHandler.addNewBookmark(for: url, title: titles[url] ?? url.absoluteString)
        }
    }

    @MainActor
    @objc private func addFavorite(_ sender: NSMenuItem) {
        guard let dataProvider, let url = sender.representedObject as? URL else {
            return
        }
        let titles = dataProvider.titles(for: [url])
        if let bookmark = bookmarkHandler.getBookmark(for: url) {
            bookmarkHandler.markAsFavorite(bookmark)
        } else {
            bookmarkHandler.addNewFavorite(for: url, title: titles[url] ?? url.absoluteString)
        }
    }

    @MainActor
    @objc private func showAllHistoryFromThisSite(_ sender: NSMenuItem) {
        contextMenuResponse = .domainSearch
    }

    @MainActor
    @objc private func delete(_ sender: NSMenuItem) {
        guard let identifiers = sender.representedObject as? [VisitIdentifier] else {
            return
        }

        deleteDialogTask = Task { @MainActor in
            await showDeleteDialog(for: identifiers)
        }
    }

    @MainActor
    private func showDeleteDialog(for identifiers: [VisitIdentifier]) async -> DataModel.DeleteDialogResponse {
        guard let dataProvider, identifiers.count > 0 else {
            return .noAction
        }

        guard identifiers.count > 1 else {
            await dataProvider.deleteVisits(for: identifiers)
            return .delete
        }

        let visitsCount = identifiers.count

        switch await deleteDialogPresenter.showDialog(for: visitsCount) {
        case .burn:
            await dataProvider.burnVisits(for: identifiers)
            return .delete
        case .delete:
            await dataProvider.deleteVisits(for: identifiers)
            return .delete
        default:
            return .noAction
        }
    }

    @MainActor
    func open(_ url: URL) {
        guard let tabCollectionViewModel else {
            return
        }

        if NSApplication.shared.isCommandPressed && NSApplication.shared.isOptionPressed {
            WindowsManager.openNewWindow(with: url, source: .bookmark, isBurner: tabCollectionViewModel.isBurner)
        } else if NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
            tabCollectionViewModel.insertOrAppendNewTab(.contentFromURL(url, source: .bookmark), selected: true)
        } else if NSApplication.shared.isCommandPressed {
            tabCollectionViewModel.insertOrAppendNewTab(.contentFromURL(url, source: .bookmark), selected: false)
        } else {
            tabCollectionViewModel.selectedTabViewModel?.tab.setContent(.contentFromURL(url, source: .historyEntry))
        }
    }

    @MainActor
    private var windowControllersManager: WindowControllersManager? {
        WindowControllersManager.shared
    }

    @MainActor
    private var tabCollectionViewModel: TabCollectionViewModel? {
        windowControllersManager?.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel
    }
}
