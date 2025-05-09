//
//  FindInPageViewController.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import Carbon.HIToolbox
import Combine

@objc protocol FindInPageDelegate: AnyObject {

    func findInPageNext(_ sender: Any)
    func findInPagePrevious(_ sender: Any)
    func findInPageDone(_ sender: Any)

}

final class FindInPageViewController: NSViewController {

    weak var delegate: FindInPageDelegate?

    @Published var model: FindInPageModel?

    @IBOutlet weak var closeButton: NSButton!
    @IBOutlet weak var textField: NSTextField!
    @IBOutlet weak var focusRingView: FocusRingView!
    @IBOutlet weak var statusField: NSTextField!
    @IBOutlet weak var nextButton: NSButton!
    @IBOutlet weak var previousButton: NSButton!

    private var modelCancellables = Set<AnyCancellable>()
    private var cancellables = Set<AnyCancellable>()

    static func create() -> FindInPageViewController {
        (NSStoryboard(name: "FindInPage", bundle: nil).instantiateInitialController() as? FindInPageViewController)!
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        focusRingView.strokedBackgroundColor = .findInPageFocusedBackground
        textField.placeholderString = UserText.findInPageTextFieldPlaceholder
        textField.delegate = self

        closeButton.toolTip = UserText.findInPageCloseTooltip
        nextButton.toolTip = UserText.findInPageNextTooltip
        previousButton.toolTip = UserText.findInPagePreviousTooltip

        nextButton.setAccessibilityIdentifier("FindInPageController.nextButton")
        closeButton.setAccessibilityIdentifier("FindInPageController.closeButton")
        previousButton.setAccessibilityIdentifier("FindInPageController.previousButton")
        textField.setAccessibilityIdentifier("FindInPageController.textField")
        textField.setAccessibilityRole(.textField)
        statusField.setAccessibilityIdentifier("FindInPageController.statusField")
        statusField.setAccessibilityRole(.textField)
    }

    override func viewWillAppear() {
        subscribeToModel()
        subscribeToFirstResponder()
    }

    override func viewWillDisappear() {
        modelCancellables.removeAll()
        cancellables.removeAll()
    }

    @IBAction func findInPageNext(_ sender: Any?) {
        delegate?.findInPageNext(self)
    }

    @IBAction func findInPagePrevious(_ sender: Any?) {
        delegate?.findInPagePrevious(self)
    }

    @IBAction func findInPageDone(_ sender: Any?) {
        delegate?.findInPageDone(self)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Handle pressing enter here rather than didEndEditing otherwise it moving to the next match doesn't work.
        guard NSApp.isReturnOrEnterPressed,
           var modifiers = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask)
        else {
            return false
        }
        modifiers.remove(.capsLock)
        switch modifiers {
        case .shift:
            delegate?.findInPagePrevious(self)
            return true
        case []:
            delegate?.findInPageNext(self)
            return true
        default:
            return false
        }
    }

    func makeMeFirstResponder() {
        if textField.isFirstResponder {
            // select all on Cmd+F while editing
            textField.currentEditor()?.selectAll(nil)
        } else {
            textField.makeMeFirstResponder()
        }
    }

    private func subscribeToModel() {
        $model.receive(on: DispatchQueue.main).sink { [weak self] model in
            self?.subscribeToModelChanges(model: model)
        }.store(in: &cancellables)
    }

    private func subscribeToModelChanges(model: FindInPageModel?) {
        modelCancellables.removeAll()

        guard let model else { return }
        updateFieldStates(model: model)

        model.$text.receive(on: DispatchQueue.main).sink { [weak self] text in
            self?.textField.stringValue = text
        }.store(in: &modelCancellables)

        model.$matchesFound.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.rebuildStatus()
            self?.updateFieldStates()
        }.store(in: &modelCancellables)

        model.$currentSelection.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.rebuildStatus()
        }.store(in: &modelCancellables)
    }

    private func rebuildStatus() {
        guard let model else { return }
        statusField.stringValue = {
            guard let matchesFound = model.matchesFound,
                  let currentSelection = model.currentSelection else { return "" }
            return String(format: UserText.findInPage, currentSelection, matchesFound)
        }()
    }

    private func updateView(firstResponder: Bool) {
        focusRingView.updateView(stroke: firstResponder)
    }

    private func updateFieldStates(model: FindInPageModel? = nil) {
        guard let model = model ?? self.model else { return }

        statusField.isHidden = model.text.isEmpty
        // enable next/prev buttons by default if current status is unknown (fallback to public find API)
        nextButton.isEnabled = model.matchesFound.map { $0 > 0 } ?? !model.text.isEmpty
        previousButton.isEnabled = model.matchesFound.map { $0 > 0 } ?? !model.text.isEmpty
    }

    private func subscribeToFirstResponder() {
        guard let window = view.window else {
            assertionFailure("FindInPageViewController.subscribeToFirstResponder: view.window is nil")
            return
        }

        NotificationCenter.default
            .publisher(for: MainWindow.firstResponderDidChangeNotification, object: window)
            .sink { [weak self] in
                self?.firstResponderDidChange($0)
            }
            .store(in: &cancellables)
    }

    private func firstResponderDidChange(_ notification: Notification) {
        if view.window?.firstResponder == textField.currentEditor() {
            updateView(firstResponder: true)
        } else {
            updateView(firstResponder: false)
        }
    }

}

extension FindInPageViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        model?.find(textField.stringValue)
    }

}
