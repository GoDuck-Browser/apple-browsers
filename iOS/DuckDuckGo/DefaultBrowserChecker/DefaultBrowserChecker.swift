//
//  DefaultBrowserChecker.swift
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
import os.log

@available(iOS 18.2, *)
struct DefaultBrowserChecker {
    let logger = Logger(subsystem: "DDG", category: "SAD")


    func isDefaultBrowser() -> Bool {
        do {
            logger.info("REQUESTING IS DEFAULT BROWSER")
            let result = try UIApplication.shared.isDefault(.webBrowser)
            logger.info("IS DEFAULT BROWSER RESULT: \(result)")
            return result
        } catch let error as NSError where error.domain == UIApplication.CategoryDefaultError.errorDomain {
            logger.error("ERROR: \(error.localizedDescription)")
            error.userInfo.forEach { key, value in
                logger.error("ERROR ENTRY - \(key): \(String(describing: value))")
            }
            return false
        }
        catch {
            logger.error("GENERIC ERROR \(error.localizedDescription)")
            return false
        }
    }

}
