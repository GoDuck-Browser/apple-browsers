//
//  DuckPlayerNativeUIPresenter.swift
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

import Foundation
import UIKit
import SwiftUI
import Combine

/// A presenter class responsible for managing the native UI components of DuckPlayer.
/// This includes presenting entry pills and handling their lifecycle.
final class DuckPlayerNativeUIPresenter {
    
    // MARK: - Properties
    
    /// The view model for the bottom sheet
    private var bottomSheetViewModel: DuckPlayerEntryPillViewModel?
    
    /// The hosting controller for the bottom sheet
    private var bottomSheetHostingController: UIHostingController<DuckPlayerEntryPillView>?
    
    /// The host view controller where UI components will be presented
    private weak var hostView: TabViewController?
    
    /// The DuckPlayer instance
    private weak var duckPlayer: DuckPlayerControlling?
    
    private var playerViewModel: DuckPlayerViewModel?
    
    let videoPlaybackRequest = PassthroughSubject<String, Never>()
    private var playerCancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    /// Sets the host view controller for presenting UI components
    ///
    /// - Parameter hostViewController: The view controller that will host the UI components
    func setHostViewController(_ hostViewController: UIViewController) {
        self.hostView = hostViewController as? TabViewController
    }
    
    /// Presents a bottom sheet asking the user how they want to open the video
    ///
    /// - Parameter videoID: The YouTube video ID to be played
    @MainActor
    func presentEntryPill(for videoID: String, in hostViewController: TabViewController) {
        self.hostView = hostViewController
        guard let hostView = self.hostView else { return }
        
        let viewModel = DuckPlayerEntryPillViewModel(videoID: videoID) { [weak self] in
            self?.videoPlaybackRequest.send(videoID)
        }
        
        let view = DuckPlayerEntryPillView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: view)
        
        hostingController.view.backgroundColor = UIColor.clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        hostView.view.addSubview(hostingController.view)
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        let fittingSize = hostingController.view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: hostView.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: hostView.view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: hostView.view.bottomAnchor),
            hostingController.view.heightAnchor.constraint(equalToConstant: fittingSize.height)
        ])
        
        bottomSheetViewModel = viewModel
        bottomSheetHostingController = hostingController
        
        viewModel.show()
    }
    
    /// Dismisses the currently presented entry pill
    @MainActor
    func dismissPill() {
        bottomSheetHostingController?.view.removeFromSuperview()
        bottomSheetHostingController = nil
        bottomSheetViewModel = nil
    }
    
    /// Hides the bottom sheet when browser chrome is hidden
    @MainActor
    func hideBottomSheetForHiddenChrome() {
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.bottomSheetHostingController?.view.alpha = 0
        }
    }
    
    /// Shows the bottom sheet when browser chrome is visible
    @MainActor
    func showBottomSheetForVisibleChrome() {
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.bottomSheetHostingController?.view.alpha = 1
        }
    }
    
    @MainActor
    func presentDuckPlayer(videoID: String, source: DuckPlayer.VideoNavigationSource, in hostViewController: TabViewController) -> (navigation: PassthroughSubject<URL, Never>, settings: PassthroughSubject<Void, Never>) {
        let navigationRequest = PassthroughSubject<URL, Never>()
        let settingsRequest = PassthroughSubject<Void, Never>()
        
        let viewModel = DuckPlayerViewModel(videoID: videoID)
        self.playerViewModel = viewModel // Keep strong reference
        
        let webView = DuckPlayerWebView(viewModel: viewModel)
        let duckPlayerView = DuckPlayerView(viewModel: viewModel, webView: webView)
        
        let hostingController = UIHostingController(rootView: duckPlayerView)
        hostingController.modalPresentationStyle = .formSheet
        hostingController.isModalInPresentation = false
        
        viewModel.youtubeNavigationRequestPublisher
            .sink { [weak hostingController] videoID in
                if source != .youtube {
                    let url: URL = .youtube(videoID)
                    navigationRequest.send(url)
                }
                hostingController?.dismiss(animated: true)
            }
            .store(in: &playerCancellables)
        
        viewModel.settingsRequestPublisher
            .sink { settingsRequest.send() }
            .store(in: &playerCancellables)
        
        hostViewController.present(hostingController, animated: true)
        return (navigationRequest, settingsRequest)
    }
}
