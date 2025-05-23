//
//  OmniBarDelegate.swift
//  DuckDuckGo
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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
import Suggestions

enum OmniBarEditingEndResult {
    case suspended
    case dismissed
}

protocol OmniBarDelegate: AnyObject {

    func onOmniQueryUpdated(_ query: String)
    
    func onOmniQuerySubmitted(_ query: String)

    func onOmniSuggestionSelected(_ suggestion: Suggestion)
    
    func onEditingEnd() -> OmniBarEditingEndResult

    func onPrivacyIconPressed(isHighlighted: Bool)
    
    func onMenuPressed()

    func onBookmarksPressed()
    
    func onSettingsPressed()

    func onSettingsLongPressed()

    func onClearPressed()

    func onAbortPressed()

    func onCancelPressed()
    
    func onEnterPressed()

    func onRefreshPressed()

    func onSharePressed()

    func onBackPressed()
    
    func onForwardPressed()
    
    func onAccessoryPressed(accessoryType: OmniBarAccessoryType)

    func onAccessoryLongPressed(accessoryType: OmniBarAccessoryType)

    func onTextFieldWillBeginEditing(_ omniBar: OmniBarView, tapped: Bool)

    // Returns whether field should select the text or not
    func onTextFieldDidBeginEditing(_ omniBar: OmniBarView) -> Bool

    func selectedSuggestion() -> Suggestion?
    
    func onVoiceSearchPressed()

    func onDidBeginEditing()

    func onDidEndEditing()

}

extension OmniBarDelegate {
    
    func onOmniQueryUpdated(_ query: String) {
        
    }
    
    func onOmniQuerySubmitted(_ query: String) {
        
    }
    
    func onPrivacyIconPressed(isHighlighted: Bool) {

    }
    
    func onMenuPressed() {
        
    }

    func onAccessoryLongPressed(accessoryType: OmniBarAccessoryType) {

    }

    func onBookmarksPressed() {
        
    }
    
    func onSettingsPressed() {
        
    }

    func onSettingsLongPressed() {

    }

    func onCancelPressed() {
        
    }
    
    func onTextFieldWillBeginEditing(_ omniBar: DefaultOmniBarView) {
        
    }

    func onTextFieldDidBeginEditing(_ omniBar: DefaultOmniBarView) {
        
    }
    
    func onRefreshPressed() {
    
    }

    func onAccessoryPressed(accessoryType: OmniBarAccessoryType) {
    }

    func onBackPressed() {
    }
    
    func onForwardPressed() {
    }
    
}
