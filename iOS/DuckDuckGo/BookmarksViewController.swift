//
//  BookmarksViewController.swift
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

import Common
import UIKit
import Core
import DDGSync
import MobileCoreServices
import UniformTypeIdentifiers
import Bookmarks
import CoreData
import Combine
import Persistence
import WidgetKit
import os.log
import SwiftUI

class BookmarksViewController: UIViewController, UITableViewDelegate {

    private enum Constants {
        static var saveToFiles = "com.apple.DocumentManagerUICore.SaveToFiles"
        static var bookmarksFileName = "DuckDuckGo Bookmarks.html"
        static var moreButtonImage = "More-Apple-24"
        static var addButtonImage = "Folder-Add-24"
        static var importBookmarkImage = "Import-16"
        static var exportBookmarkImage = "Export-Right-16"
    }

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var editButton: UIBarButtonItem!
    @IBOutlet weak var favoritesContainer: UIView!
    @IBOutlet weak var selectorControl: UISegmentedControl!

    // Need to retain these as we're going to add/remove them from the view hierarchy
    @IBOutlet var doneButton: UIBarButtonItem!
    @IBOutlet var emptyStateContainer: UIView!

    private let bookmarksDatabase: CoreDataDatabase
    private let favicons: Favicons
    private let syncService: DDGSyncing
    private let syncDataProviders: SyncDataProviders
    private let appSettings: AppSettings
    private var localUpdatesCancellable: AnyCancellable?
    private var syncUpdatesCancellable: AnyCancellable?
    private var favoritesDisplayModeCancellable: AnyCancellable?

    private lazy var addFolderBarButtonItem = UIBarButtonItem(customView: addFolderButton)
    private lazy var addFolderButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: Constants.addButtonImage), for: .normal)
        button.addTarget(self, action: #selector(onAddFolderPressed), for: .touchUpInside)
        return button
    }()

    private lazy var moreBarButtonItem = UIBarButtonItem(customView: moreButton)
    private lazy var moreButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: Constants.moreButtonImage), for: .normal)
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    private var bookmarksMenu: UIMenu {
        if #available(iOS 18.2, *) {
            return UIMenu(title: UserText.importExportBookmarksTitle,
                          children: [exportAction(), importAction()])
        } else {
            return UIMenu(title: UserText.importExportBookmarksTitle,
                          children: [exportAction(), importViaDocumentPickerAction()])
        }
    }

    private lazy var headerView: UIView = UIView()

    private lazy var emptyView: UIView = {
        let emptyView = BookmarksEmptyView(importViaSafariButtonAction: { [weak self] in
            self?.segueToDataImport()
            Pixel.fire(pixel: .bookmarksImportButtonTapped)
        }, importDocumentButtonAction: { [weak self] in
            self?.presentDocumentPicker()
        })

        let hostingController = UIHostingController(rootView: emptyView)
        var size = hostingController.sizeThatFits(in: UIScreen.main.bounds.size)
        size.height += 50
        hostingController.view.frame = CGRect(origin: .zero, size: size)
        hostingController.view.layoutIfNeeded()
        hostingController.view.backgroundColor = .clear

        self.tableView.tableFooterView?.frame.size.height = hostingController.view.frame.height

        return hostingController.view
    }()

    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = UserText.bookmarkSearchBarPlaceholder
        searchBar.delegate = self
        searchBar.sizeToFit()
        return searchBar
    }()

    private var searchController: UISearchController?

    private var isSearching: Bool = false {
        didSet {
            guard isSearching != oldValue else {
                return
            }
            refreshTableHeaderView()
        }
    }

    private lazy var searchBarBottomConstraint: NSLayoutConstraint = {
        searchBar.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
    }()

    private lazy var syncPromoViewTopConstraint: NSLayoutConstraint = {
        syncPromoViewHostingController.view.topAnchor.constraint(equalTo: searchBar.bottomAnchor)
    }()

    private lazy var syncPromoManager: SyncPromoManaging = SyncPromoManager(syncService: syncService)

    private lazy var syncPromoViewHostingController: UIHostingController<SyncPromoView> = {
        let headerView = SyncPromoView(viewModel: SyncPromoViewModel(touchpointType: .bookmarks, primaryButtonAction: { [weak self] in
            self?.segueToSync(source: "promotion_bookmarks")
            Pixel.fire(.syncPromoConfirmed, withAdditionalParameters: ["source": SyncPromoManager.Touchpoint.bookmarks.rawValue])
        }, dismissButtonAction: { [weak self] in
            self?.syncPromoManager.dismissPromoFor(.bookmarks)
            self?.refreshTableHeaderView()
        }))

        Pixel.fire(.syncPromoDisplayed, withAdditionalParameters: ["source": SyncPromoManager.Touchpoint.bookmarks.rawValue])

        let hostingController = UIHostingController(rootView: headerView)
        hostingController.view.backgroundColor = .clear
        return hostingController
    }()

    weak var delegate: BookmarksDelegate?

    fileprivate var viewModelCancellable: AnyCancellable?
    fileprivate let viewModel: BookmarkListInteracting

    fileprivate lazy var dataSource: BookmarksDataSource = {
        let dataSource = BookmarksDataSource(viewModel: viewModel)
        dataSource.onFaviconMissing = { [weak self] _ in
            guard let self else {
                return
            }
            self.faviconsFetcherOnboarding.presentOnboardingIfNeeded(from: self)
        }
        return dataSource
    }()

    var searchDataSource: SearchBookmarksDataSource

    var isNested: Bool {
        viewModel.currentFolder?.uuid != BookmarkEntity.Constants.rootFolderID
    }

    var favoritesController: FavoritesViewController?

    required init?(coder: NSCoder,
                   bookmarksDatabase: CoreDataDatabase,
                   bookmarksSearch: BookmarksStringSearch,
                   parentID: NSManagedObjectID? = nil,
                   favicons: Favicons = Favicons.shared,
                   syncService: DDGSyncing,
                   syncDataProviders: SyncDataProviders,
                   appSettings: AppSettings
    ) {
        self.bookmarksDatabase = bookmarksDatabase
        self.searchDataSource = SearchBookmarksDataSource(searchEngine: bookmarksSearch)
        self.viewModel = BookmarkListViewModel(
            bookmarksDatabase: bookmarksDatabase,
            parentID: parentID,
            favoritesDisplayMode: appSettings.favoritesDisplayMode,
            syncService: syncService
        )
        self.favicons = favicons
        self.syncService = syncService
        self.syncDataProviders = syncDataProviders
        self.appSettings = appSettings
        super.init(coder: coder)

        bindSyncService()
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    private func bindSyncService() {
        localUpdatesCancellable = viewModel.localUpdates
            .sink { [weak self] in
                self?.syncService.scheduler.notifyDataChanged()
            }

        syncUpdatesCancellable = syncDataProviders.bookmarksAdapter.syncDidCompletePublisher
            .sink { [weak self] _ in
                self?.viewModel.reloadData()
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            }
    }

    private func bindFavoritesDisplayMode() {
        favoritesDisplayModeCancellable = NotificationCenter.default.publisher(for: AppUserDefaults.Notifications.favoritesDisplayModeChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                self.viewModel.favoritesDisplayMode = self.appSettings.favoritesDisplayMode
                self.tableView.reloadData()
            }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModelCancellable = viewModel.externalUpdates.sink { [weak self] _ in
            self?.tableView.reloadData()
            self?.refreshAll()
        }
        bindFavoritesDisplayMode()

        syncService.scheduler.requestSyncImmediately()

        tableView.delegate = self

        registerForNotifications()
        configureSelector()
        configureTableView()
        configureBars()

        decorate()

        selectorControl.removeFromSuperview()
        if !isNested {
            let stack = UIStackView(arrangedSubviews: [selectorControl])
            stack.alignment = .center
            stack.axis = .vertical

            navigationController?.navigationBar.topItem?.titleView = stack

            onViewSelectorChanged(selectorControl)
        } else {
            navigationItem.title = viewModel.currentFolder?.title
        }

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tableView.reloadData()
    }

    @IBAction func onViewSelectorChanged(_ segment: UISegmentedControl) {
        switch selectorControl.selectedSegmentIndex {
        case 0:
            showBookmarksView()

        case 1:
            showFavoritesView()

        default: assertionFailure("Invalid selected segment index")
        }

        refreshFooterView()
    }

    private func refreshAll() {
        refreshEditButton()
        refreshFooterView()
        refreshMoreButton()
        refreshAddFolderButton()
    }

    private func showBookmarksView() {
        tableView.isHidden = false
        favoritesContainer.isHidden = true
        addFolderButton.isHidden = false
        moreButton.isHidden = false
        refreshAll()
    }

    private func showFavoritesView() {
        searchBar.resignFirstResponder()
        tableView.isHidden = true
        favoritesContainer.isHidden = false
        addFolderButton.isHidden = true
        moreButton.isHidden = true
        refreshAll()
    }

    func openEditFormForBookmark(_ bookmark: BookmarkEntity) {
        performSegue(withIdentifier: "AddOrEditBookmarkFolder", sender: bookmark.objectID)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.dataSource === searchDataSource {
            didSelectScoredBookmarkAtIndex(indexPath.row)
        } else {
            didSelectBookmarkAtIndex(indexPath.row)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    private func didSelectScoredBookmarkAtIndex(_ index: Int) {
        guard searchDataSource.results.indices.contains(index) else { return }
        dismiss()

        Pixel.fire(pixel: .bookmarkLaunchScored)
        delegate?.bookmarksDidSelect(url: searchDataSource.results[index].url)
    }

    private func didSelectBookmarkAtIndex(_ index: Int) {
        guard let bookmark = viewModel.bookmark(at: index) else { return }

        if isEditingBookmarks {
            performSegue(withIdentifier: "AddOrEditBookmarkFolder", sender: bookmark.objectID)
        } else if bookmark.isFolder {
            drillIntoFolder(bookmark)
        } else {
            select(bookmark: bookmark)
        }

    }

    private func drillIntoFolder(_ parent: BookmarkEntity) {
        let storyboard = UIStoryboard(name: "Bookmarks", bundle: nil)
        let viewController = storyboard.instantiateViewController(identifier: "BookmarksViewController", creator: { coder in
            let controller = BookmarksViewController(coder: coder,
                                                     bookmarksDatabase: self.bookmarksDatabase,
                                                     bookmarksSearch: self.searchDataSource.searchEngine,
                                                     parentID: parent.objectID,
                                                     syncService: self.syncService,
                                                     syncDataProviders: self.syncDataProviders,
                                                     appSettings: self.appSettings)
            controller?.delegate = self.delegate
            return controller
        })

        navigationController?.pushViewController(viewController, animated: true)
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let bookmark = bookmarkForSwipeAtIndexPath(indexPath),
                !bookmark.isFolder else {
            return nil
        }

        let cell = tableView.cellForRow(at: indexPath)
        cell?.tintColor = .black

        let title = bookmark.isFavorite(on: viewModel.favoritesDisplayMode.displayedFolder) ? UserText.actionRemoveFavorite : UserText.favorite
        let iconName = bookmark.isFavorite(on: viewModel.favoritesDisplayMode.displayedFolder) ? "Favorite-Remove-24" : "Favorite-24"

        let toggleFavoriteAction = UIContextualAction(style: .normal, title: title) { [weak self] (_, _, completionHandler) in
            completionHandler(true)
            self?.toggleFavoriteAfterSwipe(bookmark, indexPath)
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
        toggleFavoriteAction.image = UIImage(named: iconName)?.withTintColor(.black, renderingMode: .alwaysOriginal)
        toggleFavoriteAction.backgroundColor = UIColor(baseColor: .yellow60)
        return UISwipeActionsConfiguration(actions: [toggleFavoriteAction])
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let bookmark = bookmarkForSwipeAtIndexPath(indexPath) else {
            return nil
        }

        let deleteAction = UIContextualAction(style: .destructive, title:
                                                UserText.deleteBookmarkFolderAlertDeleteButton) { _, _, completion in
            self.deleteBookmarkAfterSwipe(bookmark, indexPath, completion)
        }
        deleteAction.image = UIImage(named: "Trash-24")
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    private func bookmarkForSwipeAtIndexPath(_ indexPath: IndexPath) -> BookmarkEntity? {
        if tableView.dataSource is BookmarksDataSource {
            return viewModel.bookmark(at: indexPath.row)
        } else if let dataSource = tableView.dataSource as? SearchBookmarksDataSource {
            return viewModel.bookmark(with: dataSource.results[indexPath.row].objectID)
        }
        return nil
    }

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onApplicationBecameActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    private func toggleFavoriteAfterSwipe(_ bookmark: BookmarkEntity, _ indexPath: IndexPath) {
        if !bookmark.isFavorite(on: viewModel.favoritesDisplayMode.displayedFolder) {
            Pixel.fire(pixel: .bookmarkAddFavoriteBySwipe)
        }

        self.viewModel.toggleFavorite(bookmark)
        WidgetCenter.shared.reloadAllTimelines()

        if let dataSource = tableView.dataSource as? SearchBookmarksDataSource {
            dataSource.toggleFavorite(at: indexPath.row)
        }

    }

    private func domainsInBookmarkTree(_ bookmark: BookmarkEntity) -> Set<String> {
        func addDomains(_ bookmark: BookmarkEntity, domains: inout Set<String>) {
            if let domain = bookmark.urlObject?.host {
                domains.insert(domain)
            } else {
                bookmark.childrenArray.forEach {
                    addDomains($0, domains: &domains)
                }
            }
        }

        var domains = Set<String>()
        addDomains(bookmark, domains: &domains)
        return domains
    }

    private func removeUnusedFaviconsForDomains(_ domains: Set<String>) {
        domains
            .filter { viewModel.countBookmarksForDomain($0) == 0 }
            .forEach {
                favicons.removeBookmarkFavicon(forDomain: $0)
            }
    }

    private func deleteBookmarkAfterSwipe(_ bookmark: BookmarkEntity,
                                          _ indexPath: IndexPath,
                                          _ completion: @escaping (Bool) -> Void) {
        func delete() {
            let oldCount = viewModel.bookmarks.count
            viewModel.softDeleteBookmark(bookmark)
            let newCount = viewModel.bookmarks.count

            // Make sure we are animating only single removal
            if newCount > 0 && newCount + 1 == oldCount {
                tableView.deleteRows(at: [indexPath], with: .fade)
            } else {
                tableView.reloadSections([indexPath.section], with: .none)
            }
            refreshAll()
        }

        func countAllChildrenInFolder(_ folder: BookmarkEntity) -> Int {
            return folder.childrenArray.reduce(0) { partialResult, entity in
                return partialResult + 1 + (entity.isFolder ? countAllChildrenInFolder(entity) : 0)
            }
        }

        func deleteFolder() {
            let domains = domainsInBookmarkTree(bookmark)
            removeUnusedFaviconsForDomains(domains)
            delete()
        }

        if let dataSource = tableView.dataSource as? SearchBookmarksDataSource {
            dataSource.results.remove(at: indexPath.row)
            delete()
            return
        }

        if bookmark.isFolder && !bookmark.childrenArray.isEmpty {
            let title = String(format: UserText.deleteBookmarkFolderAlertTitle, bookmark.title ?? "")
            let count = countAllChildrenInFolder(bookmark)
            let message = UserText.deleteBookmarkFolderAlertMessage(numberOfChildren: count)
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.addAction(title: UserText.deleteBookmarkFolderAlertDeleteButton, style: .destructive) {
                deleteFolder()
                completion(true)
            }
            alertController.addAction(title: UserText.actionCancel, style: .cancel) {
                completion(true)
            }
            present(alertController, animated: true)
        } else if bookmark.isFolder {
            delete()
            completion(true)
        } else {
            showBookmarkDeletedMessage(bookmark)
            delete()
            completion(true)
        }
    }

    private func configureSelector() {
        favoritesContainer.backgroundColor = tableView.backgroundColor
        selectorControl.setTitle(UserText.sectionTitleBookmarks, forSegmentAt: 0)
    }

    private func configureTableView() {
        if isNested {
            tableView.tableHeaderView = nil
        }

        tableView.dataSource = dataSource
        emptyStateContainer.addSubview(emptyView)
        emptyView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            emptyView.leadingAnchor.constraint(equalTo: emptyStateContainer.leadingAnchor),
            emptyView.trailingAnchor.constraint(equalTo: emptyStateContainer.trailingAnchor),
            emptyView.topAnchor.constraint(equalTo: emptyStateContainer.topAnchor),
            emptyView.bottomAnchor.constraint(lessThanOrEqualTo: emptyStateContainer.bottomAnchor),
            emptyView.centerXAnchor.constraint(equalTo: emptyStateContainer.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: emptyStateContainer.centerYAnchor, constant: -50)
        ])

        if viewModel.totalBookmarksCount == 0 {
            tableView.tableHeaderView?.removeFromSuperview()
        }

        refreshFooterView()
        refreshMoreButton()
    }

    @objc func onApplicationBecameActive(notification: NSNotification) {
        tableView.reloadData()
    }

    func configureBars() {
        self.navigationController?.setToolbarHidden(false, animated: true)
        toolbarItems?.insert(moreBarButtonItem, at: 0)

        let fixedSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixedSpace.width = 20
        toolbarItems?.insert(fixedSpace, at: 1)

        toolbarItems?.insert(addFolderBarButtonItem, at: 2)

        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil)
        toolbarItems?.insert(flexibleSpace, at: 3)

        refreshMoreButton()

        if isNested, let title = viewModel.currentFolder?.title {
            self.title = title
        }
        refreshEditButton()
    }

    private func refreshEditButton() {
        if isEditingBookmarks {
            changeEditButtonToDone()
            return
        }

        editButton.title = UserText.actionGenericEdit
        if !favoritesContainer.isHidden {
            editButton.isEnabled = favoritesController?.isEditing == true || (favoritesController?.hasFavorites ?? false)
            editButton.title = UserText.actionManageFavorites
        } else if (dataSource.isEmpty && !isEditingBookmarks) || dataSource === searchDataSource {
            disableEditButton()
        } else if !isEditingBookmarks {
            enableEditButton()
        }
    }
    
    private func refreshAddFolderButton() {
        if dataSource === searchDataSource {
            disableAddFolderButton()
        } else {
            enableAddFolderButton()
        }
    }

    private func refreshMoreButton() {
        if isNested || isEditingBookmarks || dataSource === searchDataSource  || viewModel.currentFolder?.isRoot == false {
            disableMoreButton()
        } else {
            enableMoreButton()
        }
    }
    
    private func refreshFooterView() {
        if !isNested &&
            dataSource.isEmpty &&
            dataSource !== searchDataSource &&
            selectorControl.selectedSegmentIndex == 0 {
            showEmptyState()
        } else {
            hideEmptyState()
        }
    }

    @IBAction func onAddFolderPressed(_ sender: Any) {
        performSegue(withIdentifier: "AddOrEditBookmarkFolder", sender: nil)
    }
    
    @IBAction func onEditPressed(_ sender: UIBarButtonItem) {
        if isEditingBookmarks {
            finishEditing()
        } else {
            startEditing()
        }
    }

    @IBAction func onDonePressed(_ sender: UIBarButtonItem) {
        dismiss()
    }

    @IBSegueAction func onCreateEditor(_ coder: NSCoder, sender: Any?, segueIdentifier: String?) -> AddOrEditBookmarkViewController? {
        if let id = sender as? NSManagedObjectID {
            guard let controller = AddOrEditBookmarkViewController(coder: coder,
                                                                   editingEntityID: id,
                                                                   bookmarksDatabase: bookmarksDatabase,
                                                                   syncService: syncService,
                                                                   appSettings: appSettings) else {
                assertionFailure("Failed to create controller")
                return nil
            }
            
            controller.delegate = self
            return controller
        } else {
            guard let controller = AddOrEditBookmarkViewController(coder: coder,
                                                                   parentFolderID: viewModel.currentFolder?.objectID,
                                                                   bookmarksDatabase: bookmarksDatabase,
                                                                   syncService: syncService,
                                                                   appSettings: appSettings) else {
                assertionFailure("Failed to create controller")
                return nil
            }
            
            return controller
        }
    }
    
    @IBSegueAction func onCreateFavoritesView(_ coder: NSCoder, sender: Any?, segueIdentifier: String?) -> FavoritesViewController {
        guard let controller = FavoritesViewController(
            coder: coder,
            bookmarksDatabase: bookmarksDatabase,
            syncService: syncService,
            syncDataProviders: syncDataProviders,
            appSettings: appSettings
        ) else {
            fatalError("Failed to create controller")
        }

        return controller
    }

    // MARK: Import bookmarks

    // when importing on iOS 18.2 and above
    func importAction() -> UIAction {
        return UIAction(title: UserText.importBookmarksActionTitle,
                        image: UIImage(named: Constants.importBookmarkImage)
        ) { [weak self] _ in
            self?.segueToDataImport()
            Pixel.fire(pixel: .bookmarksImportOverflowMenuTapped)
        }
    }

    // when importing < iOS 18.2
    func importViaDocumentPickerAction() -> UIAction {
        return UIAction(title: UserText.importBookmarksActionHtmlTitle,
                        image: UIImage(named: Constants.importBookmarkImage)
        ) { [weak self] _ in
            self?.presentDocumentPicker()
        }
    }

    func presentDocumentPicker() {
        finishEditing()

        let docTypes = [UTType.html]
        let docPicker = UIDocumentPickerViewController(forOpeningContentTypes: docTypes, asCopy: true)
        docPicker.delegate = self
        docPicker.allowsMultipleSelection = false
        present(docPicker, animated: true)
    }

    private func segueToDataImport() {
        finishEditing()

        let dataImportManager = DataImportManager(reporter: SecureVaultReporter(),
                                                  bookmarksDatabase: bookmarksDatabase,
                                                  favoritesDisplayMode: appSettings.favoritesDisplayMode,
                                                  tld: AppDependencyProvider.shared.storageCache.tld)
        let dataImportViewController = DataImportViewController(importManager: dataImportManager,
                                                                importScreen: DataImportViewModel.ImportScreen.bookmarks,
                                                                syncService: syncService)
        dataImportViewController.delegate = self
        navigationController?.setToolbarHidden(true, animated: true)
        navigationController?.pushViewController(dataImportViewController, animated: true)
    }

    func importBookmarks(fromHtml html: String) {
        Task {

            let result = await BookmarksImporter(coreDataStore: bookmarksDatabase,
                                                 favoritesDisplayMode: self.appSettings.favoritesDisplayMode,
                                                 htmlContent: html)
                .parseAndSave()

            switch result {
            case .success(let summary):
                WidgetCenter.shared.reloadAllTimelines()
                DispatchQueue.main.async {
                    Pixel.fire(pixel: .bookmarkImportSuccess,
                               withAdditionalParameters: [PixelParameters.bookmarkCount: "\(summary.successful)"])
                    ActionMessageView.present(message: UserText.importBookmarksSuccessMessage)
                }
            case .failure(let bookmarksImportError):
                Logger.bookmarks.error("Bookmarks import error \(bookmarksImportError.localizedDescription, privacy: .public)")
                Pixel.fire(pixel: .bookmarkImportFailure)
                DispatchQueue.main.async {
                    ActionMessageView.present(message: UserText.importBookmarksFailedMessage)
                }
            }
        }
    }

    func segueToSync(source: String? = nil) {
        if let mainVC = presentingViewController as? MainViewController {
            dismiss(animated: true) {
                mainVC.segueToSettingsSync(with: source)
            }
        }
    }

    // MARK: Export bookmarks

    func exportAction() -> UIAction {
        return UIAction(title: {
            if #available(iOS 18.2, *) {
                return UserText.exportBookmarksActionTitle
            } else {
                return UserText.exportBookmarksActionHtmlTitle
            }
        }(),
                        image: UIImage(named: Constants.exportBookmarkImage),
                        attributes: dataSource.isEmpty ? .disabled : []) { [weak self] _ in
            self?.exportHtmlFile()
        }
    }

    func exportHtmlFile() {
        // create file to export
        let tempFileUrl = FileManager.default.temporaryDirectory.appendingPathComponent(Constants.bookmarksFileName)
        do {
            try BookmarksExporter(coreDataStore: bookmarksDatabase, favoritesDisplayMode: viewModel.favoritesDisplayMode)
                .exportBookmarksTo(url: tempFileUrl)
        } catch {
            Logger.general.error("bookmarks failed to export: \(error.localizedDescription, privacy: .public)")
            ActionMessageView.present(message: UserText.exportBookmarksFailedMessage)
            return
        }

        // create activityViewController with exported file
        let activity = UIActivityViewController(activityItems: [tempFileUrl], applicationActivities: nil)
        activity.completionWithItemsHandler = {[weak self] (activityType: UIActivity.ActivityType?, completed: Bool, _: [Any]?, error: Error?) in
            guard error == nil else {
                // this trips if user cancelled Save to Files but they are still in the UIActivityViewController so
                // can still choose to share to another app so in this case we don't want to delete the bookmarks file yet
                if let error = error as NSError?, error.code == NSUserCancelledError {
                    return
                }

                Pixel.fire(pixel: .bookmarkExportFailure)
                self?.presentActionMessageView(withMessage: UserText.exportBookmarksFailedMessage)
                self?.cleanupTempFile(tempFileUrl)
                return
            }

            if completed && activityType != nil {
                if let activityTypeStr = activityType?.rawValue, activityTypeStr == Constants.saveToFiles {
                    self?.presentActionMessageView(withMessage: UserText.exportBookmarksFilesSuccessMessage)
                } else {
                    self?.presentActionMessageView(withMessage: UserText.exportBookmarksShareSuccessMessage)
                }
                Pixel.fire(pixel: .bookmarkExportSuccess)
            }

            self?.cleanupTempFile(tempFileUrl)
        }

        if let popover = activity.popoverPresentationController {
            popover.sourceView = moreBarButtonItem.customView
        }
        present(activity, animated: true, completion: nil)
    }

    func cleanupTempFile(_ tempFileUrl: URL) {
        try? FileManager.default.removeItem(at: tempFileUrl)
    }

    func presentActionMessageView(withMessage message: String) {
        DispatchQueue.main.async {
            ActionMessageView.present(message: message)
        }
    }

    // when swipe-to-delete control is shown tableView.isEditing is true
    private var isEditingBookmarks: Bool = false
    private func startEditing() {
        assert(!isEditingBookmarks)

        // necessary in case a cell is swiped (which would mean isEditing is already true, and setting it again wouldn't do anything)
        tableView.isEditing = false
        
        tableView.setEditing(true, animated: true)
        favoritesController?.isEditing = true

        self.isEditingBookmarks = true
        changeEditButtonToDone()
        refreshMoreButton()
        refreshFooterView()
    }

    private func finishEditing() {
        favoritesController?.isEditing = false

        guard tableView.isEditing else {
            return
        }

        tableView.setEditing(false, animated: true)
        self.isEditingBookmarks = false
        refreshEditButton()
        enableDoneButton()
        refreshMoreButton()
        refreshFooterView()
    }

    private func enableEditButton() {
        editButton.title = UserText.navigationTitleEdit
        editButton.isEnabled = true
    }

    private func disableEditButton() {
        editButton.title = UserText.navigationTitleEdit
        editButton.isEnabled = false
    }
    
    private func enableAddFolderButton() {
        addFolderBarButtonItem.title = UserText.addbookmarkFolderButton
        addFolderBarButtonItem.isEnabled = true
    }

    private func disableAddFolderButton() {
        addFolderBarButtonItem.isEnabled = false
    }

    private func changeEditButtonToDone() {
        editButton.title = UserText.navigationTitleDone
        doneButton.title = ""

        navigationItem.rightBarButtonItem = nil
        doneButton.isEnabled = false
    }

    private func enableDoneButton() {
        doneButton.title = UserText.navigationTitleDone
        navigationItem.rightBarButtonItem = doneButton
        doneButton.isEnabled = true
    }

    private func enableMoreButton() {
        moreButton.menu = bookmarksMenu
        moreButton.isEnabled = true
    }

    private func disableMoreButton() {
        moreButton.isEnabled = false
    }

    private func showEmptyState() {
        emptyStateContainer.isHidden = false
        tableView.tableHeaderView = nil
    }

    private func hideEmptyState() {
        emptyStateContainer.isHidden = true
        configureSearchBarHeaderView()
        refreshTableHeaderView()
    }

    private func configureSearchBarHeaderView() {
        guard !headerView.subviews.contains(searchBar) else {
            return
        }

        headerView.addSubview(searchBar)
        searchBar.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
                                        searchBar.topAnchor.constraint(equalTo: headerView.topAnchor),
                                        searchBar.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
                                        searchBar.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
                                        searchBarBottomConstraint
                                    ])

        searchBar.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)

        headerView.frame = CGRect(x: 0, y: 0, width: tableView.frame.width, height: searchBar.intrinsicContentSize.height)

        tableView.tableHeaderView = headerView
    }

    private func showSyncPromo() -> Bool {
        return !tableView.isEditing
               && !isSearching
               && !isNested
               && syncPromoManager.shouldPresentPromoFor(.bookmarks, count: viewModel.totalBookmarksCount)
    }

    private func refreshTableHeaderView() {
        if showSyncPromo() {
            guard !headerView.subviews.contains(syncPromoViewHostingController.view) else {
                return
            }

            syncPromoViewHostingController.view.translatesAutoresizingMaskIntoConstraints = false

            // This is needed to ensure the toolbar displays correctly on iOS 15
            if #available(iOS 16.0, *) {
                addChild(syncPromoViewHostingController)
            }

            headerView.addSubview(syncPromoViewHostingController.view)

            if #available(iOS 16.0, *) {
                syncPromoViewHostingController.didMove(toParent: self)
            }

            NSLayoutConstraint.deactivate([
                searchBarBottomConstraint
            ])

            NSLayoutConstraint.activate([
                syncPromoViewTopConstraint,
                syncPromoViewHostingController.view.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
                syncPromoViewHostingController.view.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
                syncPromoViewHostingController.view.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
            ])

            syncPromoViewHostingController.view.setNeedsLayout()
            syncPromoViewHostingController.view.layoutIfNeeded()

            let horizontalMargins = tableView.layoutMargins.left + tableView.layoutMargins.right + 40
            let syncPromoViewHeight = syncPromoViewHostingController.view.sizeThatFits(CGSize(width: tableView.bounds.width - horizontalMargins, height: CGFloat.greatestFiniteMagnitude)).height
            let totalHeight = searchBar.intrinsicContentSize.height + syncPromoViewHeight
            headerView.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: totalHeight)

            tableView.tableHeaderView = headerView
        } else if !headerView.subviews.contains(searchBar) || headerView.subviews.count != 1 {

            if syncPromoViewHostingController.view != nil {
                syncPromoViewHostingController.view?.removeFromSuperview()
            }

            syncPromoViewTopConstraint.isActive = false
            searchBarBottomConstraint.isActive = true

            headerView.frame = CGRect(x: 0, y: 0, width: tableView.frame.width, height: searchBar.intrinsicContentSize.height)

            tableView.tableHeaderView = headerView
            searchBar.layoutIfNeeded()
            tableView.layoutIfNeeded()
        }
    }

    private func prepareForSearching() {
        finishEditing()
        disableEditButton()
        disableAddFolderButton()
        isSearching = true
    }

    private func finishSearching() {
        tableView.dataSource = dataSource
        tableView.reloadData()

        enableEditButton()
        enableAddFolderButton()
        isSearching = false
    }

    fileprivate func select(bookmark: BookmarkEntity) {
        guard let url = bookmark.urlObject else { return }
        dismiss()
        Pixel.fire(pixel: .bookmarkLaunchList)
        DailyPixel.fire(pixel: .bookmarkLaunchedDaily)
        delegate?.bookmarksDidSelect(url: url)
    }

    private func dismiss() {
        dismiss(animated: true, completion: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? FavoritesViewController {
            viewController.delegate = self
            favoritesController = viewController
        }
    }

    private(set) lazy var faviconsFetcherOnboarding: FaviconsFetcherOnboarding =
        .init(syncService: syncService, syncBookmarksAdapter: syncDataProviders.bookmarksAdapter)
}

extension BookmarksViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        guard !searchText.isEmpty else {
            if tableView.dataSource !== dataSource {
                finishSearching()
            }
            return
        }

        if dataSource !== searchDataSource {
            prepareForSearching()
            tableView.dataSource = searchDataSource
        }

        searchDataSource.performSearch(searchText)
        tableView.reloadData()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        finishSearching()
    }
}

extension BookmarksViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        finishEditing()
    }
}

extension BookmarksViewController {

    private func decorate() {
        let theme = ThemeManager.shared.currentTheme
        decorateNavigationBar(with: theme)
        decorateToolbar(with: theme)

        searchController?.searchBar.searchTextField.textColor = theme.searchBarTextColor

        tableView.backgroundColor = theme.backgroundColor
        tableView.separatorColor = theme.tableCellSeparatorColor

        navigationController?.view.backgroundColor = tableView.backgroundColor

        tableView.reloadData()
    }
}

extension BookmarksViewController: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let data = try? Data(contentsOf: url), let contents = String(data: data, encoding: .utf8) else {
            ActionMessageView.present(message: UserText.importBookmarksFailedMessage)
            return
        }
        importBookmarks(fromHtml: contents)
    }
}

extension BookmarksViewController: FavoritesViewControllerDelegate {

    func favoritesViewController(_ controller: FavoritesViewController, didSelectFavorite favorite: BookmarkEntity) {
        select(bookmark: favorite)
    }

    func favoritesViewController(_ controller: FavoritesViewController, didRequestEditFavorite favorite: BookmarkEntity) {
        performSegue(withIdentifier: "AddOrEditBookmarkFolder", sender: favorite.objectID)
    }

}

extension BookmarksViewController: AddOrEditBookmarkViewControllerDelegate {

    func finishedEditing(_: AddOrEditBookmarkViewController, entityID: NSManagedObjectID) {
        // no-op
    }

    func deleteBookmark(_: AddOrEditBookmarkViewController, entityID: NSManagedObjectID) {
        guard let bookmark = viewModel.bookmark(with: entityID) else {
            assertionFailure()
            return
        }
        Pixel.fire(pixel: .bookmarkDeletedFromBookmark)
        showBookmarkDeletedMessage(bookmark)
        viewModel.softDeleteBookmark(bookmark)
        refreshFooterView()
        tableView.reloadData()
    }

    func showBookmarkDeletedMessage(_ bookmark: BookmarkEntity) {
        guard let parent = bookmark.parent,
              let index = parent.childrenArray.firstIndex(of: bookmark),
              let title = bookmark.title,
              let url = bookmark.url else {
            assertionFailure()
            return
        }

        // capture the optional details
        var favoritesFoldersAndIndexes: [BookmarkEntity: Int] = [:]
        for favoritesFolder in bookmark.favoriteFoldersSet {
            favoritesFoldersAndIndexes[favoritesFolder] = favoritesFolder.favoritesArray.firstIndex(of: bookmark) ?? 0
        }

        // capture this locally because this VC might have been closed when undo gets pressed
        let localViewModel = self.viewModel
        let message = UserText.bookmarkDeleted
        ActionMessageView.present(message: message, actionTitle: UserText.actionGenericUndo) { [weak self] in
            // re-create it
            localViewModel.createBookmark(title: title,
                                          url: url,
                                          folder: parent,
                                          folderIndex: index,
                                          favoritesFoldersAndIndexes: favoritesFoldersAndIndexes)

            self?.tableView.reloadData()
            self?.refreshAll()
        } onDidDismiss: {
            if let domain = bookmark.urlObject?.host {
                NotificationCenter.default.post(name: FireproofFaviconUpdater.deleteFireproofFaviconNotification,
                                                object: nil,
                                                userInfo: [FireproofFaviconUpdater.UserInfoKeys.faviconDomain: domain])
            }
        }
    }

}

extension BookmarksViewController: DataImportViewControllerDelegate {
    func dataImportViewControllerDidFinish(_ controller: DataImportViewController) {
        viewModel.reloadData()
    }
}
