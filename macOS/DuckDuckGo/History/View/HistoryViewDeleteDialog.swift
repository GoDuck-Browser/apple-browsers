//
//  HistoryViewDeleteDialog.swift
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
import Persistence
import SwiftUIExtensions

protocol HistoryViewDeleteDialogPresenting {
    @MainActor
    func showDialog(for itemsCount: Int, deleteMode: HistoryViewDeleteDialogModel.DeleteMode) async -> HistoryViewDeleteDialogModel.Response
}

final class DefaultHistoryViewDeleteDialogPresenter: HistoryViewDeleteDialogPresenting {
    @MainActor
    func showDialog(for itemsCount: Int, deleteMode: HistoryViewDeleteDialogModel.DeleteMode) async -> HistoryViewDeleteDialogModel.Response {
        await withCheckedContinuation { continuation in
            let parentWindow = WindowControllersManager.shared.lastKeyMainWindowController?.window
            let model = HistoryViewDeleteDialogModel(entriesCount: itemsCount, mode: deleteMode)
            let dialog = HistoryViewDeleteDialog(model: model)
            dialog.show(in: parentWindow) {
                continuation.resume(returning: model.response)
            }
        }
    }
}

protocol HistoryViewDeleteDialogSettingsPersisting: AnyObject {
    var shouldBurnHistoryWhenDeleting: Bool { get set }
}

final class UserDefaultsHistoryViewDeleteDialogSettingsPersistor: HistoryViewDeleteDialogSettingsPersisting {
    enum Keys {
        static let shouldBurnHistoryWhenDeleting = "history.delete.should-burn"
    }

    private let keyValueStore: KeyValueStoring

    init(_ keyValueStore: KeyValueStoring = UserDefaults.standard) {
        self.keyValueStore = keyValueStore
    }

    var shouldBurnHistoryWhenDeleting: Bool {
        get { return keyValueStore.object(forKey: Keys.shouldBurnHistoryWhenDeleting) as? Bool ?? true }
        set { keyValueStore.set(newValue, forKey: Keys.shouldBurnHistoryWhenDeleting) }
    }
}

final class HistoryViewDeleteDialogModel: ObservableObject {
    enum Response {
        case unknown, noAction, delete, burn
    }

    enum DeleteMode: Equatable {
        case all, today, yesterday, date(Date), formattedDate(String), unspecified

        var date: Date? {
            guard case let .date(date) = self else {
                return nil
            }
            return date
        }
    }

    var title: String {
        switch mode {
        case .all:
            return UserText.deleteAllHistory
        case .today:
            return UserText.deleteAllHistoryFromToday
        case .yesterday:
            return UserText.deleteAllHistoryFromYesterday
        case .unspecified:
            return UserText.deleteHistory
        case .date(let date):
            return UserText.deleteHistory(for: Self.dateFormatter.string(from: date))
        case .formattedDate(let stringDate):
            return UserText.deleteHistory(for: stringDate)
        }
    }

    let entriesCountString: String

    var dataClearingExplanation: String {
        switch mode {
        case .all, .today:
            return UserText.deleteCookiesAndSiteDataExplanationWithClosingTabs
        default:
            return UserText.deleteCookiesAndSiteDataExplanation
        }
    }

    @Published var shouldBurn: Bool {
        didSet {
            settingsPersistor.shouldBurnHistoryWhenDeleting = shouldBurn
        }
    }
    @Published private(set) var response: Response = .unknown

    init(
        entriesCount: Int,
        mode: DeleteMode = .unspecified,
        settingsPersistor: HistoryViewDeleteDialogSettingsPersisting = UserDefaultsHistoryViewDeleteDialogSettingsPersistor()
    ) {
        self.entriesCountString = Self.numberFormatter.string(from: .init(value: entriesCount)) ?? String(entriesCount)
        self.mode = mode
        self.settingsPersistor = settingsPersistor
        shouldBurn = settingsPersistor.shouldBurnHistoryWhenDeleting
    }

    func cancel() {
        response = .noAction
    }

    func delete() {
        response = shouldBurn ? .burn : .delete
    }

    private let mode: DeleteMode
    private let settingsPersistor: HistoryViewDeleteDialogSettingsPersisting

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.formattingContext = .middleOfSentence
        return formatter
    }()

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

struct HistoryViewDeleteDialog: ModalView {

    @ObservedObject var model: HistoryViewDeleteDialogModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(.historyBurn)

            VStack(spacing: 12) {
                Text(model.title)
                    .multilineTextAlignment(.center)
                    .fixMultilineScrollableText()
                    .font(.system(size: 15).weight(.semibold))

                Text(.init(UserText.deleteHistoryMessage(items: model.entriesCountString)))
                    .multilineTextAlignment(.center)
                    .fixMultilineScrollableText()
                    .font(.system(size: 13))

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(UserText.deleteCookiesAndSiteData, isOn: $model.shouldBurn)
                        .font(.system(size: 13))
                        .fixMultilineScrollableText()
                        .toggleStyle(.checkbox)

                    Text(model.dataClearingExplanation)
                        .fixMultilineScrollableText()
                        .foregroundColor(.blackWhite60)
                        .font(.system(size: 11))
                        .padding(.leading, 19)
                }
                .padding(.init(top: 16, leading: 12, bottom: 16, trailing: 12))
                .background(RoundedRectangle(cornerRadius: 8.0).stroke(.blackWhite5))
            }
            .padding(.bottom, 16)

            HStack(spacing: 8) {
                Button {
                    model.cancel()
                    dismiss()
                } label: {
                    Text(UserText.cancel)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                }
                .buttonStyle(StandardButtonStyle(topPadding: 0, bottomPadding: 0))

                Button {
                    model.delete()
                    dismiss()
                } label: {
                    Text(UserText.delete)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                }
                .buttonStyle(DestructiveActionButtonStyle(enabled: true, topPadding: 0, bottomPadding: 0))

            }
        }
        .padding(16)
        .frame(width: 330)
    }
}
