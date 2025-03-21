//
//  BrokerJobData.swift
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

import Foundation

public protocol BrokerJobData {
    var brokerId: Int64 { get }
    var profileQueryId: Int64 { get }
    var lastRunDate: Date? { get }
    var preferredRunDate: Date? { get }
    var historyEvents: [HistoryEvent] { get }
}

public extension BrokerJobData {
    var isRemovedByUser: Bool {
        historyEvents.closestHistoryEvent?.type != .matchRemovedByUser
    }
}

public struct ScanJobData: BrokerJobData, Sendable {
    public let brokerId: Int64
    public let profileQueryId: Int64
    public let preferredRunDate: Date?
    public let historyEvents: [HistoryEvent]
    public let lastRunDate: Date?

    public init(brokerId: Int64,
                profileQueryId: Int64,
                preferredRunDate: Date? = nil,
                historyEvents: [HistoryEvent],
                lastRunDate: Date? = nil) {
        self.brokerId = brokerId
        self.profileQueryId = profileQueryId
        self.preferredRunDate = preferredRunDate
        self.historyEvents = historyEvents
        self.lastRunDate = lastRunDate
    }

    public func closestMatchesFoundEvent() -> HistoryEvent? {
        return historyEvents.filter { event in
            if case .matchesFound = event.type {
                return true
            }
            return false
        }
        .sorted { $0.date > $1.date }
        .last
    }

    public func scanStartedEvents() -> [HistoryEvent] {
        return historyEvents.filter { event in
            if case .scanStarted = event.type {
                return true
            }

            return false
        }
    }
}

public struct OptOutJobData: BrokerJobData, Sendable {
    public let brokerId: Int64
    public let profileQueryId: Int64
    public let createdDate: Date
    public let preferredRunDate: Date?
    public let historyEvents: [HistoryEvent]
    public let lastRunDate: Date?
    public let attemptCount: Int64

    // This was added in a later DB migration (V4), so will be nil for older entries submitted before the migration
    public let submittedSuccessfullyDate: Date?

    public let extractedProfile: ExtractedProfile
    public let sevenDaysConfirmationPixelFired: Bool
    public let fourteenDaysConfirmationPixelFired: Bool
    public let twentyOneDaysConfirmationPixelFired: Bool

    init(brokerId: Int64,
         profileQueryId: Int64,
         createdDate: Date,
         preferredRunDate: Date? = nil,
         historyEvents: [HistoryEvent],
         lastRunDate: Date? = nil,
         attemptCount: Int64,
         submittedSuccessfullyDate: Date? = nil,
         extractedProfile: ExtractedProfile,
         sevenDaysConfirmationPixelFired: Bool = false,
         fourteenDaysConfirmationPixelFired: Bool = false,
         twentyOneDaysConfirmationPixelFired: Bool = false) {
        self.brokerId = brokerId
        self.profileQueryId = profileQueryId
        self.createdDate = createdDate
        self.preferredRunDate = preferredRunDate
        self.historyEvents = historyEvents
        self.lastRunDate = lastRunDate
        self.attemptCount = attemptCount
        self.submittedSuccessfullyDate = submittedSuccessfullyDate
        self.extractedProfile = extractedProfile
        self.sevenDaysConfirmationPixelFired = sevenDaysConfirmationPixelFired
        self.fourteenDaysConfirmationPixelFired = fourteenDaysConfirmationPixelFired
        self.twentyOneDaysConfirmationPixelFired = twentyOneDaysConfirmationPixelFired
    }
}
