//
//  ThemeManager.swift
//  DuckDuckGo
//
//  Copyright © 2018 DuckDuckGo. All rights reserved.
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
import DesignResourcesKit
import BrowserServicesKit

class ThemeManager {
    enum ImageSet {
        case light
        case dark
        
        var trait: UITraitCollection {
            switch self {
            case .light:
                return UITraitCollection(userInterfaceStyle: .light)
            case .dark:
                return UITraitCollection(userInterfaceStyle: .dark)
            }
        }
    }
    
    public static let shared = ThemeManager()

    private var appSettings: AppSettings
    private let featureFlagger: FeatureFlagger

    private(set) var currentTheme: Theme = DefaultTheme()

    init(settings: AppSettings = AppUserDefaults(), featureFlagger: FeatureFlagger = AppDependencyProvider.shared.featureFlagger) {
        appSettings = settings
        self.featureFlagger = featureFlagger

        updateColorScheme()
    }

    public func updateColorScheme() {
        if !ExperimentalThemingManager(featureFlagger: featureFlagger).isExperimentalThemingEnabled {
            DesignSystemPalette.current = .default
        } else {
            DesignSystemPalette.current = .experimental
        }
    }

    public func setThemeStyle(_ style: ThemeStyle) {
        appSettings.currentThemeStyle = style
        updateUserInterfaceStyle()
    }

    func updateUserInterfaceStyle(window: UIWindow? = UIApplication.shared.firstKeyWindow) {
        switch appSettings.currentThemeStyle {

        case .dark:
            window?.overrideUserInterfaceStyle = .dark

        case .light:
            window?.overrideUserInterfaceStyle = .light

        default:
            window?.overrideUserInterfaceStyle = .unspecified

        }
    }

    var currentInterfaceStyle: UIUserInterfaceStyle {
        UIApplication.shared.firstKeyWindow?.traitCollection.userInterfaceStyle ?? .light
    }
}
