//
//  ExpandableButton.swift
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


import Cocoa
import SwiftUI

class ExpandableButton: NSView {
    enum State {
        case expanded
        case collapsed
    }
    private var hostingView: NSHostingView<ExpandableButtonView>?

    var state: State = .collapsed {
        willSet {
            if state != newValue {
                viewModel.isExpanded = newValue == .expanded
            }
        }
    }

    private var viewModel: ExpandableButtonViewModel

    init(icon: String,
         text: String,
         shortcutSymbols: [String]?,
         buttonPressed: @escaping () -> Void) {

        viewModel = ExpandableButtonViewModel(icon: icon,
                                              shortcutSymbols: shortcutSymbols,
                                              text: text,
                                              buttonPressed: buttonPressed)

        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        viewModel = ExpandableButtonViewModel(icon: "",
                                              text: "",
                                              buttonPressed: { })

        super.init(coder: coder)
    }

    private func setup() {
        let rootView = ExpandableButtonView(viewModel: self.viewModel)

        hostingView = NSHostingView(rootView: rootView)
        if let hostingView = hostingView {
            addSubview(hostingView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
    }
}

final class ExpandableButtonViewModel: ObservableObject {
    let animationDuration: CGFloat = 0.17
    @Published var isExpanded = false
    let icon: String
    let shortcutSymbols: [String]?
    let text: String
    var buttonPressed: () -> Void

    internal init(isExpanded: Bool = false,
                  icon: String, shortcutSymbols: [String]? = nil,
                  text: String,
                  buttonPressed: @escaping () -> Void) {
        self.isExpanded = isExpanded
        self.icon = icon
        self.shortcutSymbols = shortcutSymbols
        self.buttonPressed = buttonPressed
        self.text = text
    }
}
