//
//  AllowedDomains.swift
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

final class DefaultAllowedDomainsViewModel: ExcludedDomainsViewModel {
    private let notificationCenter = NotificationCenter.default
    var domains: [String]

    init() {
        self.domains = [String]()
    }

    func add(domain: String) {
        guard !domains.contains(domain) else {
            return
        }

        domains.append(domain)

        notificationCenter.post(name: .focusModelSiteChanged, object: nil)
    }

    func remove(domain: String) {
        domains.removeAll(where: { $0 == domain })

        notificationCenter.post(name: .focusModelSiteChanged, object: nil)
    }

    func askUserToReportIssues(withDomain domain: String, in window: NSWindow?) async {
        // No-op
    }
}
