//
//  HomeMessageViewModel.swift
//  DuckDuckGo
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import RemoteMessaging
import UIKit

struct HomeMessageViewModel {

    enum ButtonAction {
        case close
        case action(isShare: Bool) // a generic action that is specific to the type of message
        case primaryAction(isShare: Bool)
        case secondaryAction(isShare: Bool)
    }

    let messageId: String
    let sendPixels: Bool
    let modelType: RemoteMessageModelType
    let navigator: MessageNavigator

    var image: String? {
        switch modelType {
        case .small:
            return nil
        case .medium(_, _, let placeholder):
            return placeholder.rawValue
        case .bigSingleAction(_, _, let placeholder, _, _):
            return placeholder.rawValue
        case .bigTwoAction(_, _, let placeholder, _, _, _, _):
            return placeholder.rawValue
        case .promoSingleAction(_, _, let placeholder, _, _):
            return placeholder.rawValue
        }
    }
    
    var title: String {
        switch modelType {
        case .small(let titleText, _):
            return titleText
        case .medium(let titleText, _, _):
            return titleText
        case .bigSingleAction(let titleText, _, _, _, _):
            return titleText
        case .bigTwoAction(let titleText, _, _, _, _, _, _):
            return titleText
        case .promoSingleAction(let titleText, _, _, _, _):
            return titleText
        }
    }

    var subtitle: String {
        let subtitle = {
            switch modelType {
            case .small(_, let descriptionText):
                return descriptionText
            case .medium(_, let descriptionText, _):
                return descriptionText
            case .bigSingleAction(_, let descriptionText, _, _, _):
                return descriptionText
            case .bigTwoAction(_, let descriptionText, _, _, _, _, _):
                return descriptionText
            case .promoSingleAction(_, let descriptionText, _, _, _):
                return descriptionText
            }
        }()
        return subtitle
            .replacingOccurrences(of: "<b>", with: "**")
            .replacingOccurrences(of: "</b>", with: "**")
    }

    var buttons: [HomeMessageButtonViewModel] {
        switch modelType {
        case .small:
            return []
        case .medium:
            return []
        case .bigSingleAction(_, _, _, let primaryActionText, let primaryAction):
            return [
                HomeMessageButtonViewModel(title: primaryActionText,
                                           actionStyle: primaryAction.actionStyle(),
                                           action: mapActionToViewModel(remoteAction: primaryAction, buttonAction:
                                                .primaryAction(isShare: primaryAction.isShare), onDidClose: onDidClose))
            ]
        case .bigTwoAction(_, _, _, let primaryActionText, let primaryAction, let secondaryActionText, let secondaryAction):
            return [
                HomeMessageButtonViewModel(title: secondaryActionText,
                                           actionStyle: secondaryAction.actionStyle(isSecondaryAction: true),
                                           action: mapActionToViewModel(remoteAction: secondaryAction, buttonAction:
                                                .secondaryAction(isShare: secondaryAction.isShare), onDidClose: onDidClose)),

                HomeMessageButtonViewModel(title: primaryActionText,
                                           actionStyle: primaryAction.actionStyle(),
                                           action: mapActionToViewModel(remoteAction: primaryAction, buttonAction:
                                           .primaryAction(isShare: primaryAction.isShare), onDidClose: onDidClose))
            ]
        case .promoSingleAction(_, _, _, let actionText, let action):
            return [
                HomeMessageButtonViewModel(title: actionText,
                                           actionStyle: action.actionStyle(),
                                           action: mapActionToViewModel(remoteAction: action, buttonAction:
                                                .action(isShare: action.isShare), onDidClose: onDidClose))]
        }
    }
    
    let onDidClose: (ButtonAction?) async -> Void
    let onDidAppear: () -> Void
    let onAttachAdditionalParameters: ((_ useCase: PrivacyProDataReportingUseCase, _ params: [String: String]) -> [String: String])?

    func mapActionToViewModel(remoteAction: RemoteAction,
                              buttonAction: HomeMessageViewModel.ButtonAction,
                              onDidClose: @escaping (HomeMessageViewModel.ButtonAction?) async -> Void) -> () async -> Void {

        switch remoteAction {
        case .share:
            return { @MainActor in
                await onDidClose(buttonAction)
            }
        case .url(let value):
            return { @MainActor in
                LaunchTabNotification.postLaunchTabNotification(urlString: value)
                await onDidClose(buttonAction)
            }
        case .survey(let value):
            return { @MainActor in
                LaunchTabNotification.postLaunchTabNotification(urlString: value)
                await onDidClose(buttonAction)
            }
        case .appStore:
            return { @MainActor in
                let url = URL.appStore
                if UIApplication.shared.canOpenURL(url as URL) {
                    UIApplication.shared.open(url)
                }
                await onDidClose(buttonAction)
            }
        case .dismiss:
            return { @MainActor in
                await onDidClose(buttonAction)
            }

        case .navigation(let target):
            return { @MainActor in
                navigator.navigateTo(target)
                await onDidClose(buttonAction)
            }
        }
    }
}

struct HomeMessageButtonViewModel {
    enum ActionStyle {
        case `default`
        case share(value: String, title: String?)
        case cancel
    }
    
    let title: String
    var actionStyle: ActionStyle = .default
    let action: () async -> Void

}

private extension RemoteAction {
    var isShare: Bool {
        if case .share = self.actionStyle() {
            return true
        }
        return false
    }
}
