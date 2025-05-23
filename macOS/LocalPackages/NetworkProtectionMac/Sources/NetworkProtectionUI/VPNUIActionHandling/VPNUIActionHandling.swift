//
//  VPNUIActionHandling.swift
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
import NetworkProtection

public protocol VPNUIActionHandling {
    func moveAppToApplications() async
    func setExclusion(_ exclude: Bool, forDomain domain: String) async
    func shareFeedback() async
    func showPrivacyPro() async
    func showVPNLocations() async

    /// Called when the user clicks on the toggle to stop the VPN.
    ///
    /// This allows overriding VPN tunnel control.
    ///
    func willStopVPN() async -> Bool
}
