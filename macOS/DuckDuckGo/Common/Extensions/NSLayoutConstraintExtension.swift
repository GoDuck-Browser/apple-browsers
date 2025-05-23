//
//  NSLayoutConstraintExtension.swift
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

import AppKit
import Foundation

extension NSLayoutConstraint {

    func priority(_ priority: Float) -> Self {
        self.priority = .init(priority)
        return self
    }

    func priority(_ priority: Priority) -> Self {
        self.priority = priority
        return self
    }

    @discardableResult
    func autoDeactivatedWhenViewIsHidden(_ view: NSView) -> Self {
        let c = view.publisher(for: \.isHidden).sink { [self /* bind the constraint lifetime to the view */] isHidden in
            if self.isActive != !isHidden {
                self.isActive = !isHidden
            }
        }
        view.onDeinit {
            withExtendedLifetime(c) {}
        }
        return self
    }

}
