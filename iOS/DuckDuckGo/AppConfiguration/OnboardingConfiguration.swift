//
//  OnboardingConfiguration.swift
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
import Core

final class OnboardingConfiguration {

    lazy var daxDialogs = DaxDialogs.shared

    func migrateToNewOnboarding() {
        // Hide Dax Dialogs if users already completed old onboarding.
        DaxDialogsOnboardingMigrator().migrateFromOldToNewOboarding()
    }

    // assign it here, because "did become active" is already too late and "viewWillAppear"
    // has already been called on the HomeViewController so won't show the home row CTA
    func adjustDialogsForUITesting() {
        let launchOptionsHandler = LaunchOptionsHandler()

        // MARK: perform first time launch logic here
        // If it's running UI Tests check if the onboarding should be in a completed state.
        if launchOptionsHandler.onboardingStatus.isOverriddenCompleted {
            daxDialogs.dismiss()
        } else {
            daxDialogs.primeForUse()
        }
    }

}
