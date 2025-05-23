//
//  DBPAgentConfigurationURLProvider.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit
import Configuration

public struct DBPAgentConfigurationURLProvider: ConfigurationURLProviding {
    public func url(for configuration: Configuration) -> URL {
        guard configuration == .privacyConfiguration else { fatalError("\(configuration.rawValue) is not supported on this target") }

        return URL(string: "https://staticcdn.duckduckgo.com/trackerblocking/config/v4/macos-config.json")!
    }

    public init() {}
}
