//
//  NewTabPageDataModel+VPNStatsData.swift
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

extension NewTabPageDataModel {

    struct VPNStatsData: Encodable { //, Equatable {

        enum CodingKeys: CodingKey {
            case pending
            case state
            case value
        }

        let pending: String
        let state: String
        let value: (any Encodable)?

        init(pending: String,
             state: String,
             value: (any Encodable)? = nil) {

            self.pending = pending
            self.state = state
            self.value = value
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(pending, forKey: .pending)
            try container.encode(state, forKey: .state)
            if let value {
                try container.encode(value, forKey: .value)
            }
        }
    }

    public struct VPNActiveSessionInfo: Codable {

        public struct DataVolume: Codable {
            let upload: Double
            let download: Double
            let unit: String

            public init(upload: Double, download: Double, unit: String) {
                self.upload = upload
                self.download = download
                self.unit = unit
            }
        }

        let currentIp: String
        // Seconds since epoch
        let connectedSince: TimeInterval
        let dataVolume: DataVolume

        public init(currentIp: String, connectedSince: Date, dataVolume: DataVolume) {
            self.currentIp = currentIp
            self.connectedSince = connectedSince.timeIntervalSince1970 * 1000
            self.dataVolume = dataVolume
        }
    }

    public struct VPNConnectedData: Codable {
        let session: VPNActiveSessionInfo
        let history: VPNUsageHistory

        public init(session: VPNActiveSessionInfo, history: VPNUsageHistory) {
            self.history = history
            self.session = session
        }
    }

    public struct VPNDisconnectedData: Codable {
        let history: VPNUsageHistory

        public init(history: VPNUsageHistory) {
            self.history = history
        }
    }

    public struct VPNUsageHistory: Codable {
        let longestConnection: TimeInterval
        let weeklyUsage: VPNWeeklyUsage

        public init(longestConnection: TimeInterval, weeklyUsage: VPNWeeklyUsage) {
            self.longestConnection = longestConnection
            self.weeklyUsage = weeklyUsage
        }
    }

    public struct VPNWeeklyUsage: Codable {
        let days: [VPNDailyUsage]
        let maxValue: Int
        let timeUnit: String

        public init(days: [VPNDailyUsage], maxValue: Int, timeUnit: String? = nil) {
            self.days = days
            self.maxValue = maxValue
            self.timeUnit = timeUnit ?? "hours"
        }
    }

    public struct VPNDailyUsage: Codable {
        let active: Bool
        let day: VPNDay

        // Number of hours 0-24
        let value: Float

        public init(active: Bool, day: VPNDay, value: Float) {
            self.active = active
            self.day = day
            self.value = value
        }
    }

    public enum VPNDay: String, Codable {
        case sunday = "Sun"
        case monday = "Mon"
        case tuesday = "Tue"
        case wednesday = "Wed"
        case thursday = "Thu"
        case friday = "Fri"
        case saturday = "Sat"
    }
}
