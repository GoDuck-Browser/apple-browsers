//
//  Background.swift
//  DuckDuckGo
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

import UIKit
import Core

/// Represents the state where the app is in the background and not visible to the user.
/// - Usage:
///   - This state is typically associated with the `applicationDidEnterBackground(_:)` method.
///   - The app transitions to this state when it is no longer in the foreground, either due to the user
///     minimizing the app, switching to another app, or locking the device.
struct Background: BackgroundHandling {

    private let lastBackgroundDate: Date = Date()
    private let appDependencies: AppDependencies
    private let didTransitionFromLaunching: Bool
    private var services: AppServices { appDependencies.services }

    init(stateContext: Launching.StateContext) {
        appDependencies = stateContext.appDependencies
        didTransitionFromLaunching = true
    }

    init(stateContext: Foreground.StateContext) {
        appDependencies = stateContext.appDependencies
        didTransitionFromLaunching = false
    }

    // MARK: - Handle applicationDidEnterBackground(_:) logic here
    func onTransition() {
        Logger.lifecycle.info("\(type(of: self)): \(#function)")

        services.dbpService.onBackground()
        services.vpnService.suspend()
        services.authenticationService.suspend()
        services.autoClearService.suspend()
        services.autofillService.suspend()
        services.syncService.suspend()
        services.reportingService.suspend()

        appDependencies.mainCoordinator.onBackground()
    }

}

// MARK: - Handle application resumption (applicationWillEnterForeground(_:)) logic here
extension Background {

    /// Called when the app is attempting to enter the foreground from the background.
    /// If the app uses the system Face ID lock feature and the user does not authenticate, it will return to the background, triggering `didReturn()`.
    /// Use `didReturn()` to revert any actions performed in `willLeave()`, e.g. suspend services that were resumed (if applicable).
    ///
    /// **Important note**
    /// By default, resume any services in the `onTransition()` method of the `Foreground` state.
    /// Use this method to resume **UI related tasks** that need to be completed promptly, preventing UI glitches when the user first sees the app.
    /// This ensures that the app remains smooth as it enters the foreground.
    func willLeave() {
        Logger.lifecycle.info("\(type(of: self)): \(#function)")
        ThemeManager.shared.updateUserInterfaceStyle()
        services.autoClearService.resume()
    }

    /// Called when the app transitions from launching or foreground to background
    /// or when the app fails to wake up from the background (due to system Face ID lock).
    /// This is the counterpart to `willLeave()`.
    ///
    /// Use this method to revert any actions performed in `willLeave` (if applicable).
    func didReturn() {
        Logger.lifecycle.info("\(type(of: self)): \(#function)")
    }

}

extension Background {

    struct StateContext {

        let lastBackgroundDate: Date
        let appDependencies: AppDependencies
        let didTransitionFromLaunching: Bool

    }

    func makeForegroundState(actionToHandle: AppAction?) -> any ForegroundHandling {
        Foreground(stateContext: StateContext(lastBackgroundDate: lastBackgroundDate,
                                              appDependencies: appDependencies,
                                              didTransitionFromLaunching: didTransitionFromLaunching),
                   actionToHandle: actionToHandle)
    }

}
