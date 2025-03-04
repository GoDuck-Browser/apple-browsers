//
//  HistoryViewPixel.swift
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
import HistoryView
import PixelKit

/**
 * This enum keeps pixels related to HTML History View.
 */
enum HistoryViewPixel: PixelKitEventV2 {

    // MARK: - Permanent Pixels
    /**
     * Event Trigger: History View is displayed to user.
     *
     * > Note: This is a daily pixel.
     *
     * > Related links:
     * [Privacy Triage TBD]()
     * [Detailed Pixels description](https://app.asana.com/0/0/1209364382402737/f)
     *
     * Anomaly Investigation:
     * - Anomaly in this pixel may mean an increase/drop in app use.
     */
    case historyPageShown(HistoryPageSource)
    case filterSet(FilterKind)
    case filterCleared
    case itemOpened
    case delete
    case singleItemDeleted
    case multipleItemsDeleted(DeletedBatchKind, burn: Bool)

    // MARK: - Temporary Pixels
    case onboardingDialogShown
    case onboardingDialogDismissed
    case onboardingDialogAccepted

    // MARK: -

    enum HistoryPageSource: String {
        case topMenu = "top-menu", sideMenu = "side-menu", introDialog = "intro-dialog"
    }

    enum FilterKind: String {
        case range, searchTerm = "search-term", domain

        init(_ queryKind: DataModel.HistoryQueryKind) {
            switch queryKind {
            case .rangeFilter:
                self = .range
            case .domainFilter:
                self = .domain
            case .searchTerm:
                self = .searchTerm
            }
        }
    }

    enum DeletedBatchKind: String {
        case all, range, searchTerm = "search-term", domain, multiSelect = "multi-select"

        init(_ queryKind: DataModel.HistoryQueryKind) {
            switch queryKind {
            case .rangeFilter(.all):
                self = .all
            case .rangeFilter:
                self = .range
            case .domainFilter:
                self = .domain
            case .searchTerm:
                self = .searchTerm
            }
        }
    }

    // MARK: - Debug

    /**
     * Event Trigger: History View reports a JavaScript exception.
     *
     * > Note: This is a daily + standard pixel.
     *
     * > Related links:
     * [Privacy Triage TBD]()
     * [Detailed Pixels description](https://app.asana.com/0/0/1209364382402737/f)
     *
     * Anomaly Investigation:
     * - Anomaly in this pixel may mean a critical breakage in the History View.
     */
    case historyPageExceptionReported(message: String)

    var name: String {
        switch self {
        case .historyPageShown: return "history-page_shown"
        case .historyPageExceptionReported: return "history-page_exception-reported"
        case .filterSet: return "history-page_filter-set"
        case .filterCleared: return "history-page_filter-cleared"
        case .itemOpened: return "history-page_item-opened"
        case .delete: return "history-page_any-delete"
        case .singleItemDeleted: return "history-page_item-deleted"
        case .multipleItemsDeleted: return "history-page_items-deleted"
        case .onboardingDialogShown: return "history-page_intro_dialog_shown"
        case .onboardingDialogDismissed: return "history-page_intro_dialog_not_now"
        case .onboardingDialogAccepted: return "history-page_intro_dialog_view_history"
        }
    }

    var parameters: [String: String]? {
        switch self {
        case .historyPageShown(let source):
            return [Parameters.source: source.rawValue]
        case .historyPageExceptionReported(let message):
            return [Parameters.message: message]
        case .filterSet(let filter):
            return [Parameters.filter: filter.rawValue]
        case .filterCleared:
            return nil
        case .itemOpened:
            return nil
        case .delete:
            return nil
        case .singleItemDeleted:
            return nil
        case .multipleItemsDeleted(let batchKind, let burn):
            return [Parameters.filter: batchKind.rawValue, Parameters.deleteType: burn ? "burn" : "delete"]
        case .onboardingDialogShown:
            return nil
        case .onboardingDialogDismissed:
            return nil
        case .onboardingDialogAccepted:
            return nil
        }
    }

    var error: (any Error)? {
        nil
    }

    enum Parameters {
        static let filter = "filter"
        static let deleteType = "type"
        static let message = "message"
        static let source = "source"
    }
}
