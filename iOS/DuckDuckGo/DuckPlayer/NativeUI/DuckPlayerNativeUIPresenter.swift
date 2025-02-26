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
    
    /// The container view model for the entry pill
    private var containerViewModel: DuckPlayerContainer.ViewModel?
    
    /// The hosting controller for the container
    private var containerViewController: UIHostingController<DuckPlayerContainer.Container<DuckPlayerEntryPillView>>?
    
    /// The host view controller where UI components will be presented
    private weak var hostView: TabViewController?
    
    /// The DuckPlayer instance
    private weak var duckPlayer: DuckPlayerControlling?
    
    /// The view model for the player
    private var playerViewModel: DuckPlayerViewModel?
    
    /// A publisher to notify when a video playback request is needed
    let videoPlaybackRequest = PassthroughSubject<String, Never>()
    private var playerCancellables = Set<AnyCancellable>()
    private var containerCancellables = Set<AnyCancellable>()

    /// Application Settings
    private var appSettings: AppSettings

    /// Current height of the OmniBar
    private var omniBarHeight: CGFloat = 0
    
    /// Bottom constraint for the container view
    private var bottomConstraint: NSLayoutConstraint?

    // MARK: - Public Methods
    ///
    /// - Parameter appSettings: The application settings
    init(appSettings: AppSettings = AppDependencyProvider.shared.appSettings) {
        self.appSettings = appSettings
        setupNotificationObservers()
    }

    func setupNotificationObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleOmnibarDidLayout),
                                               name: OmniBar.didLayoutNotification,
                                               object: nil)
    }

    @objc private func handleOmnibarDidLayout(_ notification: Notification) {
        guard let omniBar = notification.object as? OmniBar else { return }
        omniBarHeight = omniBar.frame.height
        updateConstraints()
    }

    private func updateConstraints() {
        guard let bottomConstraint = bottomConstraint else { return }
        bottomConstraint.constant = appSettings.currentAddressBarPosition == .bottom ? -omniBarHeight : 0
    }

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
        
        // If we already have a container view model, just show it again
        if let existingViewModel = containerViewModel {
            existingViewModel.show()
            return
        }
                
        self.hostView = hostViewController
        guard let hostView = self.hostView else { return }
        
        // Create and configure the container view model
        let containerViewModel = DuckPlayerContainer.ViewModel()
        self.containerViewModel = containerViewModel
        
        // Create the pill view model
        let pillViewModel = DuckPlayerEntryPillViewModel() { [weak self] in
            self?.videoPlaybackRequest.send(videoID)
        }
        
        // Create the container view with the pill view
        let containerView = DuckPlayerContainer.Container(
            viewModel: containerViewModel,
            hasBackground: false
        ) { _ in
            DuckPlayerEntryPillView(viewModel: pillViewModel)
        }
        
        // Set up hosting controller
        let hostingController = UIHostingController(rootView: containerView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Add to host view
        hostView.view.addSubview(hostingController.view)
        
        // Calculate bottom constraints based on URL Bar position
        // If at the bottom, the Container should be placed above it
        bottomConstraint = appSettings.currentAddressBarPosition == .bottom ? 
                    hostingController.view.bottomAnchor.constraint(equalTo: hostView.view.bottomAnchor, constant: -omniBarHeight) : 
                    hostingController.view.bottomAnchor.constraint(equalTo: hostView.view.bottomAnchor)

        NSLayoutConstraint.activate([   
            hostingController.view.leadingAnchor.constraint(equalTo: hostView.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: hostView.view.trailingAnchor),
            bottomConstraint!           
        ])
                
        // Store reference to the hosting controller
        containerViewController = hostingController
        
        // Add delay before showing the pill
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak containerViewModel] in
            containerViewModel?.show()
        }
    }
    
    /// Dismisses the currently presented entry pill
    @MainActor
    func dismissPill() {
        // Hide the view first
        containerViewModel?.dismiss()
        
        // Remove the view after the animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in                               
            self?.containerViewController?.view.removeFromSuperview()
            self?.containerViewController = nil            
            self?.containerViewModel = nil
            self?.containerCancellables.removeAll()
        }
    }
    
    /// Hides the bottom sheet when browser chrome is hidden
    @MainActor
    func hideBottomSheetForHiddenChrome() {
        containerViewModel?.dismiss()
    }
    
    /// Shows the bottom sheet when browser chrome is visible
    @MainActor
    func showBottomSheetForVisibleChrome() {
        containerViewModel?.show()
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

    deinit {
        playerCancellables.removeAll()
        containerCancellables.removeAll()
        NotificationCenter.default.removeObserver(self)
    }
}
