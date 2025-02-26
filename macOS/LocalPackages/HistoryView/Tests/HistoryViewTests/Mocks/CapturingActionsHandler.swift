//
//  CapturingActionsHandler.swift
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

final class CapturingActionsHandler: ActionsHandling {

    func showDeleteDialog(for range: DataModel.HistoryRange) async -> DataModel.DeleteDialogResponse {
        showDeleteDialogForRangeCalls.append(range)
        return await showDeleteDialogForRange(range)
    }

    func showDeleteDialog(for entries: [String]) async -> HistoryView.DataModel.DeleteDialogResponse {
        showDeleteDialogForEntriesCalls.append(entries)
        return await showDeleteDialogForEntries(entries)
    }

    func showDeleteDialog(for searchTerm: String) async -> HistoryView.DataModel.DeleteDialogResponse {
        showDeleteDialogForSearchTermCalls.append(searchTerm)
        return await showDeleteDialogForSearchTerm(searchTerm)
    }

    func showContextMenu(for entries: [String], using presenter: any ContextMenuPresenting) async -> DataModel.DeleteDialogResponse {
        return .noAction
    }

    func open(_ url: URL) {
        openCalls.append(url)
    }

    var showDeleteDialogForRangeCalls: [DataModel.HistoryRange] = []
    var showDeleteDialogForRange: (DataModel.HistoryRange) async -> DataModel.DeleteDialogResponse = { _ in .delete }

    var showDeleteDialogForEntriesCalls: [[String]] = []
    var showDeleteDialogForEntries: ([String]) async -> DataModel.DeleteDialogResponse = { _ in .delete }

    var showDeleteDialogForSearchTermCalls: [String] = []
    var showDeleteDialogForSearchTerm: (String) async -> DataModel.DeleteDialogResponse = { _ in .delete }

    var openCalls: [URL] = []
}
