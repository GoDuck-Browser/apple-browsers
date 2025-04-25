//
//  AddressBarViewController.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import Combine
import Lottie
import Common
import AIChat

final class AddressBarViewController: NSViewController {

    enum Mode: Equatable {
        enum EditingMode {
            case text
            case url
            case openTabSuggestion
        }

        case editing(EditingMode)
        case browsing

        var isEditing: Bool {
            return self != .browsing
        }
    }

    private enum Constants {
        static let switchToTabMinXPadding: CGFloat = 34
        static let defaultActiveTextFieldMinX: CGFloat = 40

        static let maxClickReleaseDistanceToResignFirstResponder: CGFloat = 4
    }

    @IBOutlet var addressBarTextField: AddressBarTextField!
    @IBOutlet var passiveTextField: NSTextField!
    @IBOutlet var inactiveBackgroundView: NSView!
    @IBOutlet var activeBackgroundView: ColorView!
    @IBOutlet var activeOuterBorderView: ColorView!
    @IBOutlet var activeBackgroundViewWithSuggestions: ColorView!
    @IBOutlet var innerBorderView: ColorView!
    @IBOutlet var progressIndicator: LoadingProgressView!
    @IBOutlet var buttonsContainerView: NSView!
    @IBOutlet var switchToTabBox: ColorView!
    @IBOutlet var switchToTabLabel: NSTextField!
    @IBOutlet var shadowView: ShadowView!

    @IBOutlet var switchToTabBoxMinXConstraint: NSLayoutConstraint!
    @IBOutlet var passiveTextFieldMinXConstraint: NSLayoutConstraint!
    @IBOutlet var activeTextFieldMinXConstraint: NSLayoutConstraint!
    @IBOutlet var addressBarPassiveTextCenterXConstraint: NSLayoutConstraint!
    @IBOutlet var addressBarTextTrailingConstraint: NSLayoutConstraint!

    private let popovers: NavigationBarPopovers?
    private(set) var addressBarButtonsViewController: AddressBarButtonsViewController?

    private let tabCollectionViewModel: TabCollectionViewModel
    private var tabViewModel: TabViewModel?
    private let suggestionContainerViewModel: SuggestionContainerViewModel
    private let isBurner: Bool
    private let onboardingPixelReporter: OnboardingAddressBarReporting

    private var aiChatSettings: AIChatPreferencesStorage

    private var mode: Mode = .editing(.text) {
        didSet {
            addressBarButtonsViewController?.controllerMode = mode
        }
    }

    private var isFirstResponder = false {
        didSet {
            updateView()
            updateSwitchToTabBoxAppearance()
            self.addressBarButtonsViewController?.isTextFieldEditorFirstResponder = isFirstResponder
            self.clickPoint = nil // reset click point if the address bar activated during click
        }
    }

    private var isHomePage = false {
        didSet {
            updateView()
            suggestionContainerViewModel.isHomePage = isHomePage
        }
    }

    private var accentColor: NSColor {
        return isBurner ? NSColor.burnerAccent : NSColor.controlAccentColor
    }

    private var cancellables = Set<AnyCancellable>()
    private var tabViewModelCancellables = Set<AnyCancellable>()

    /// save mouse-down position to handle same-place clicks outside of the Address Bar to remove first responder
    private var clickPoint: NSPoint?

    // MARK: - View Lifecycle

    required init?(coder: NSCoder) {
        fatalError("AddressBarViewController: Bad initializer")
    }

    init?(coder: NSCoder,
          tabCollectionViewModel: TabCollectionViewModel,
          burnerMode: BurnerMode,
          popovers: NavigationBarPopovers?,
          onboardingPixelReporter: OnboardingAddressBarReporting = OnboardingPixelReporter(),
          aiChatSettings: AIChatPreferencesStorage = DefaultAIChatPreferencesStorage()) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.popovers = popovers
        self.suggestionContainerViewModel = SuggestionContainerViewModel(
            isHomePage: tabViewModel?.tab.content == .newtab,
            isBurner: burnerMode.isBurner,
            suggestionContainer: SuggestionContainer(burnerMode: burnerMode, isUrlIgnored: { _ in false }))
        self.isBurner = burnerMode.isBurner
        self.onboardingPixelReporter = onboardingPixelReporter
        self.aiChatSettings = aiChatSettings

        super.init(coder: coder)
    }

    @IBSegueAction func createAddressBarButtonsViewController(_ coder: NSCoder) -> AddressBarButtonsViewController? {
        let controller = AddressBarButtonsViewController(coder: coder,
                                                         tabCollectionViewModel: tabCollectionViewModel,
                                                         popovers: popovers,
                                                         aiChatTabOpener: NSApp.delegateTyped.aiChatTabOpener,
                                                         aiChatMenuConfig: AIChatMenuConfiguration(storage: aiChatSettings))

        self.addressBarButtonsViewController = controller
        controller?.delegate = self
        return addressBarButtonsViewController
    }

    override func viewDidLoad() {
        view.wantsLayer = true
        view.layer?.masksToBounds = false

        addressBarTextField.placeholderString = UserText.addressBarPlaceholder
        addressBarTextField.setAccessibilityIdentifier("AddressBarViewController.addressBarTextField")

        switchToTabBox.isHidden = true
        switchToTabLabel.attributedStringValue = SuggestionTableCellView.switchToTabAttributedString

        updateView()
        // only activate active text field leading constraint on its appearance to avoid constraint conflicts
        activeTextFieldMinXConstraint.isActive = false
        addressBarTextField.tabCollectionViewModel = tabCollectionViewModel
        addressBarTextField.onboardingDelegate = onboardingPixelReporter
    }

    override func viewWillAppear() {
        guard let window = view.window else {
            assertionFailure("AddressBarViewController.viewWillAppear: view.window is nil")
            return
        }
        if window.isPopUpWindow == true {
            addressBarTextField.isHidden = true
            inactiveBackgroundView.isHidden = true
            activeBackgroundViewWithSuggestions.isHidden = true
            activeOuterBorderView.isHidden = true
            activeBackgroundView.isHidden = true
            shadowView.isHidden = true
        } else {
            addressBarTextField.suggestionContainerViewModel = suggestionContainerViewModel

            subscribeToAppearanceChanges()
            subscribeToFireproofDomainsChanges()
            addTrackingArea()
            subscribeToMouseEvents()
            subscribeToFirstResponder()
        }
        subscribeToSelectedTabViewModel()
        subscribeToAddressBarValue()
        subscribeToButtonsWidth()
        subscribeForShadowViewUpdates()
    }

    override func viewWillDisappear() {
        cancellables.removeAll()
    }

    override func viewDidLayout() {
        addressBarTextField.viewDidLayout()
    }

    // MARK: - Subscriptions

    private func subscribeToAppearanceChanges() {
        guard let window = view.window else {
            assertionFailure("AddressBarViewController.subscribeToAppearanceChanges: view.window is nil")
            return
        }
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification, object: window)
            .sink { [weak self] _ in
                self?.refreshAddressBarAppearance(nil)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification, object: window)
            .sink { [weak self] _ in
                self?.refreshAddressBarAppearance(nil)
            }
            .store(in: &cancellables)

        NSApp.publisher(for: \.effectiveAppearance)
            .sink { [weak self] _ in
                self?.refreshAddressBarAppearance(nil)
            }
            .store(in: &cancellables)
    }

    private func subscribeToFireproofDomainsChanges() {
        NotificationCenter.default.publisher(for: FireproofDomains.Constants.allowedDomainsChangedNotification)
            .sink { [weak self] _ in
                self?.refreshAddressBarAppearance(nil)
            }
            .store(in: &cancellables)
    }

    private func subscribeToSelectedTabViewModel() {
        tabCollectionViewModel.$selectedTabViewModel
            .sink { [weak self] tabViewModel in
                guard let self else { return }

                self.tabViewModel = tabViewModel
                tabViewModelCancellables.removeAll()

                subscribeToTabContent()
                subscribeToPassiveAddressBarString()
                subscribeToProgressEvents()

                // don't resign first responder on tab switching
                clickPoint = nil
            }
            .store(in: &cancellables)
    }

    private func subscribeToAddressBarValue() {
        addressBarTextField.$value
            .sink { [weak self] value in
                guard let self else { return }

                updateMode(value: value)
                addressBarButtonsViewController?.textFieldValue = value
                updateView()
                updateSwitchToTabBoxAppearance()
            }
            .store(in: &cancellables)
    }

    private func subscribeToTabContent() {
        tabViewModel?.tab.$content
            .map { $0 == .newtab }
            .assign(to: \.isHomePage, onWeaklyHeld: self)
            .store(in: &tabViewModelCancellables)
    }

    private func subscribeToPassiveAddressBarString() {
        guard let tabViewModel else {
            passiveTextField.stringValue = ""
            return
        }
        tabViewModel.$passiveAddressBarAttributedString
            .receive(on: DispatchQueue.main)
            .assign(to: \.attributedStringValue, onWeaklyHeld: passiveTextField)
            .store(in: &tabViewModelCancellables)
    }

    private func subscribeToProgressEvents() {
        guard let tabViewModel else {
            progressIndicator.hide(animated: false)
            return
        }

        func shouldShowLoadingIndicator(for tabViewModel: TabViewModel, isLoading: Bool, error: Error?) -> Bool {
            if isLoading,
               let url = tabViewModel.tab.content.urlForWebView,
               url.navigationalScheme?.isHypertextScheme == true,
               !url.isDuckDuckGoSearch, !url.isDuckPlayer,
               error == nil {
                return true
            } else {
                return false
            }
        }

        if shouldShowLoadingIndicator(for: tabViewModel, isLoading: tabViewModel.isLoading, error: tabViewModel.tab.error) {
            progressIndicator.show(progress: tabViewModel.progress, startTime: tabViewModel.loadingStartTime)
        } else {
            progressIndicator.hide(animated: false)
        }

        tabViewModel.$progress
            .sink { [weak self] value in
                guard tabViewModel.isLoading,
                      let progressIndicator = self?.progressIndicator,
                      progressIndicator.isProgressShown
                else { return }

                progressIndicator.increaseProgress(to: value)
            }
            .store(in: &tabViewModelCancellables)

        tabViewModel.$isLoading.combineLatest(tabViewModel.tab.$error)
            .debounce(for: 0.1, scheduler: RunLoop.main)
            .sink { [weak self] isLoading, error in
                guard let progressIndicator = self?.progressIndicator else { return }

                if shouldShowLoadingIndicator(for: tabViewModel, isLoading: isLoading, error: error) {
                    progressIndicator.show(progress: tabViewModel.progress, startTime: tabViewModel.loadingStartTime)

                } else if progressIndicator.isProgressShown {
                    progressIndicator.finishAndHide()
                }
            }
            .store(in: &tabViewModelCancellables)
    }

    private func subscribeToButtonsWidth() {
        addressBarButtonsViewController!.$buttonsWidth
            .sink { [weak self] value in
                self?.layoutTextFields(withMinX: value)
            }
            .store(in: &cancellables)
    }

    private func subscribeForShadowViewUpdates() {
        addressBarTextField.isSuggestionWindowVisiblePublisher
            .sink { [weak self] isSuggestionsWindowVisible in
                self?.updateShadowView(isSuggestionsWindowVisible)
                if isSuggestionsWindowVisible {
                    self?.layoutShadowView()
                }
            }
            .store(in: &cancellables)

        view.superview?.publisher(for: \.frame)
            .sink { [weak self] _ in
                self?.layoutShadowView()
            }
            .store(in: &cancellables)
    }

    private func addTrackingArea() {
        let trackingArea = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect], owner: self, userInfo: nil)
        self.view.addTrackingArea(trackingArea)
    }

    private func subscribeToMouseEvents() {
        NSEvent.addLocalCancellableMonitor(forEventsMatching: .leftMouseDown) { [weak self] event in
            guard let self else { return event }
            return self.mouseDown(with: event)
        }.store(in: &cancellables)
        NSEvent.addLocalCancellableMonitor(forEventsMatching: .leftMouseUp) { [weak self] event in
            guard let self else { return event }
            return self.mouseUp(with: event)
        }.store(in: &cancellables)
        NSEvent.addLocalCancellableMonitor(forEventsMatching: .rightMouseDown) { [weak self] event in
            guard let self else { return event }
            return self.rightMouseDown(with: event)
        }.store(in: &cancellables)
    }

    private func subscribeToFirstResponder() {
        guard let window = view.window else {
            assertionFailure("AddressBarViewController.subscribeToFirstResponder: view.window is nil")
            return
        }
        NotificationCenter.default.publisher(for: MainWindow.firstResponderDidChangeNotification, object: window)
            .sink { [weak self] in
                self?.firstResponderDidChange($0)
            }
            .store(in: &cancellables)
    }

    // MARK: - Layout

    private func updateView() {
        let isPassiveTextFieldHidden = isFirstResponder || mode.isEditing
        addressBarTextField.alphaValue = isPassiveTextFieldHidden ? 1 : 0
        passiveTextField.alphaValue = isPassiveTextFieldHidden ? 0 : 1

        updateShadowViewPresence(isFirstResponder)
        inactiveBackgroundView.alphaValue = isFirstResponder ? 0 : 1
        activeBackgroundView.alphaValue = isFirstResponder ? 1 : 0

        let isKey = self.view.window?.isKeyWindow == true

        activeOuterBorderView.alphaValue = isKey && isFirstResponder && isHomePage ? 1 : 0
        activeOuterBorderView.backgroundColor = accentColor.withAlphaComponent(0.2)
        activeBackgroundView.borderColor = accentColor.withAlphaComponent(0.8)

        addressBarTextField.placeholderString = tabViewModel?.tab.content == .newtab ? UserText.addressBarPlaceholder : ""
    }

    private func updateSwitchToTabBoxAppearance() {
        guard case .editing(.openTabSuggestion) = mode,
              addressBarTextField.isVisible, let editor = addressBarTextField.editor else {
            switchToTabBox.isHidden = true
            switchToTabBox.alphaValue = 0
            return
        }

        if !switchToTabBox.isVisible {
            switchToTabBox.isShown = true
            switchToTabBox.alphaValue = 0
        }
        // update box position on the next pass after text editor layout is updated
        DispatchQueue.main.async {
            self.switchToTabBox.alphaValue = 1
            self.switchToTabBoxMinXConstraint.constant = editor.textSize.width + Constants.switchToTabMinXPadding
        }
    }

    private func updateShadowViewPresence(_ isFirstResponder: Bool) {
        guard isFirstResponder, view.window?.isPopUpWindow == false else {
            shadowView.removeFromSuperview()
            return
        }
        if shadowView.superview == nil {
            updateShadowView(addressBarTextField.isSuggestionWindowVisible)
            view.window?.contentView?.addSubview(shadowView)
            layoutShadowView()
        }
    }

    private func updateShadowView(_ isSuggestionsWindowVisible: Bool) {
        shadowView.shadowSides = isSuggestionsWindowVisible ? [.left, .top, .right] : []
        shadowView.shadowColor = isSuggestionsWindowVisible ? .suggestionsShadow : .clear
        shadowView.shadowRadius = isSuggestionsWindowVisible ? 8.0 : 0.0

        activeOuterBorderView.isHidden = isSuggestionsWindowVisible || view.window?.isKeyWindow != true
        activeBackgroundView.isHidden = isSuggestionsWindowVisible
        activeBackgroundViewWithSuggestions.isHidden = !isSuggestionsWindowVisible
    }

    private func layoutShadowView() {
        guard let superview = shadowView.superview else { return }

        let winFrame = self.view.convert(self.view.bounds, to: nil)
        let frame = superview.convert(winFrame, from: nil)
        shadowView.frame = frame
    }

    private func updateMode(value: AddressBarTextField.Value? = nil) {
        switch value ?? self.addressBarTextField.value {
        case .text: self.mode = .editing(.text)
        case .url(urlString: _, url: _, userTyped: let userTyped): self.mode = userTyped ? .editing(.url) : .browsing
        case .suggestion(let suggestionViewModel):
            switch suggestionViewModel.suggestion {
            case .phrase, .unknown:
                self.mode = .editing(.text)
            case .website, .bookmark, .historyEntry, .internalPage:
                self.mode = .editing(.url)
            case .openTab:
                self.mode = .editing(.openTabSuggestion)
            }
        }
    }

    @objc private func refreshAddressBarAppearance(_ sender: Any?) {
        self.updateMode()
        self.addressBarButtonsViewController?.updateButtons()

        guard let window = view.window, AppVersion.runType != .unitTests else { return }

        NSAppearance.withAppAppearance {
            if window.isKeyWindow {
                activeBackgroundView.borderWidth = 2.0
                activeBackgroundView.borderColor = accentColor.withAlphaComponent(0.6)
                activeBackgroundView.backgroundColor = NSColor.addressBarBackground
                switchToTabBox.backgroundColor = NSColor.navigationBarBackground.blended(with: .addressBarBackground)

                activeOuterBorderView.isHidden = !isHomePage
            } else {
                activeBackgroundView.borderWidth = 0
                activeBackgroundView.borderColor = nil
                activeBackgroundView.backgroundColor = NSColor.inactiveSearchBarBackground
                switchToTabBox.backgroundColor = NSColor.navigationBarBackground.blended(with: .inactiveSearchBarBackground)

                activeOuterBorderView.isHidden = true
            }
        }
    }

    private func layoutTextFields(withMinX minX: CGFloat) {
        self.passiveTextFieldMinXConstraint.constant = minX
        // adjust min-x to passive text field when “Search or enter” placeholder is displayed (to prevent placeholder overlapping buttons)
        self.activeTextFieldMinXConstraint.constant = (!self.isFirstResponder || self.mode.isEditing)
        ? minX : Constants.defaultActiveTextFieldMinX
    }

    private func firstResponderDidChange(_ notification: Notification) {
        if view.window?.firstResponder === addressBarTextField.currentEditor() {
            if !isFirstResponder {
                isFirstResponder = true
            }
            activeTextFieldMinXConstraint.isActive = true
        } else if isFirstResponder {
            isFirstResponder = false
        }
    }

    // MARK: - Event handling

    func escapeKeyDown() -> Bool {
        guard isFirstResponder else { return false }

        if mode.isEditing {
            addressBarTextField.escapeKeyDown()
            return true
        }

        view.window?.makeFirstResponder(nil)

        return true
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.iBeam.set()
        super.mouseEntered(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        guard event.window === self.view.window else { return }

        let point = self.view.convert(event.locationInWindow, from: nil)
        let view = self.view.hitTest(point)

        if view?.shouldShowArrowCursor == true {
            NSCursor.arrow.set()
        } else {
            NSCursor.iBeam.set()
        }

        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        super.mouseExited(with: event)
    }

    func mouseDown(with event: NSEvent) -> NSEvent? {
        self.clickPoint = nil
        guard let window = self.view.window, event.window === window, window.sheets.isEmpty else { return event }

        if let point = self.view.mouseLocationInsideBounds(event.locationInWindow) {
            guard self.view.window?.firstResponder !== addressBarTextField.currentEditor(),
                  self.view.hitTest(point)?.shouldShowArrowCursor == false
            else { return event }

            // bookmark button visibility is usually determined by hover state, but we def need to hide it right now
            self.addressBarButtonsViewController?.bookmarkButton.isHidden = true

            // first activate app and window if needed, then make it first responder
            if self.view.window?.isMainWindow == true {
                self.addressBarTextField.makeMeFirstResponder()
                return nil
            } else {
                DispatchQueue.main.async {
                    self.addressBarTextField.makeMeFirstResponder()
                }
            }

        } else if window.isMainWindow {
            self.clickPoint = window.convertPoint(toScreen: event.locationInWindow)
        }
        return event
    }

    func rightMouseDown(with event: NSEvent) -> NSEvent? {
        guard event.window === self.view.window else { return event }
        // Convert the point to view system
        let pointInView = view.convert(event.locationInWindow, from: nil)

        // If the view where the touch occurred is outside the AddressBar forward the event
        guard let viewWithinAddressBar = view.hitTest(pointInView) else { return event }

        // If we have an AddressBarMenuButton, forward the event
        guard !(viewWithinAddressBar is AddressBarMenuButton) else { return event }

        // If the farthest view of the point location is a NSButton or LottieAnimationView don't show contextual menu
        guard viewWithinAddressBar.shouldShowArrowCursor == false else { return nil }

        // The event location is not a button so we can forward the event to the textfield
        addressBarTextField.rightMouseDown(with: event)
        return nil
    }

    func mouseUp(with event: NSEvent) -> NSEvent? {
        // click (same position down+up) outside of the field: resign first responder
        guard let window = self.view.window, event.window === window,
              window.firstResponder === addressBarTextField.currentEditor(),
              let clickPoint,
              clickPoint.distance(to: window.convertPoint(toScreen: event.locationInWindow)) <= Constants.maxClickReleaseDistanceToResignFirstResponder else {
            return event
        }

        self.view.window?.makeFirstResponder(nil)

        return event
    }

}

extension AddressBarViewController: AddressBarButtonsViewControllerDelegate {
    func addressBarButtonsViewControllerHideAIChatButtonClicked(_ addressBarButtonsViewController: AddressBarButtonsViewController) {
        aiChatSettings.showShortcutInAddressBar = false
    }

    func addressBarButtonsViewController(_ controller: AddressBarButtonsViewController, didUpdateAIChatButtonVisibility isVisible: Bool) {
        addressBarTextTrailingConstraint.constant = isVisible ? 80 : 45
        addressBarPassiveTextCenterXConstraint.constant = isVisible ? -20 : 0
    }

    func addressBarButtonsViewControllerClearButtonClicked(_ addressBarButtonsViewController: AddressBarButtonsViewController) {
        addressBarTextField.clearValue()
    }
}

fileprivate extension NSView {

    var shouldShowArrowCursor: Bool {
        self is NSButton || self is LottieAnimationView
    }

}
