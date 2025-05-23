//
//  DataBrokerDatabaseBrowserViewController.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import SwiftUI
import DataBrokerProtectionCore

public final class DataBrokerDatabaseBrowserViewController: NSViewController {
    private let localBrokerService: LocalBrokerJSONServiceProvider

    public init(localBrokerService: LocalBrokerJSONServiceProvider) {
        self.localBrokerService = localBrokerService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("\(type(of: self)): Bad initializer")
    }

    public override func loadView() {
        let viewModel = DataBrokerDatabaseBrowserViewModel(localBrokerService: localBrokerService)
        let contentView = DataBrokerDatabaseBrowserView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.autoresizingMask = [.width, .height]
        self.view = hostingController.view
    }
}
