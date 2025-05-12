//
//  EnlargedHitAreaButton.swift
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

import UIKit

final class EnlargedHitAreaButton: UIButton {

    /// Adds this amount of extra hit test space in each direction.
    var additionalHitTestSize = 0.0

    var hitTestEdgeInsets: UIEdgeInsets {
        .init(top: -additionalHitTestSize, left: -additionalHitTestSize, bottom: -additionalHitTestSize, right: -additionalHitTestSize)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let relativeFrame = self.bounds
        let hitFrame = relativeFrame.inset(by: hitTestEdgeInsets)
        return hitFrame.contains(point)
    }

}
