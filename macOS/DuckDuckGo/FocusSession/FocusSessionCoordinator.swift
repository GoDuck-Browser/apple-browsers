//
//  FocusSessionCoordinator.swift
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
import Combine
import SwiftUI
import SwiftUICore
import AVFoundation

public extension NSNotification.Name {

    static let focusModeFeatureEnabled = Notification.Name(rawValue: "com.duckduckgo.focus.mode.feature.enabled")
    static let focusModelSiteChanged = Notification.Name(rawValue: "com.duckduckgo.focus.mode.site.changed")
}

enum FocusSessionTimer {
    case twentyFive
    case fifty
    case seventyFive
    case oneHundred

    var duration: TimeInterval {
        switch self {
        case .twentyFive:
            return 25 * 60
        case .fifty:
            return 50 * 60
        case .seventyFive:
            return 75 * 60
        case .oneHundred:
            return 100 * 60
        }
    }
}

struct FocusModeNavigationBarPopover: View {

    @ObservedObject
    var coordinator = FocusSessionCoordinator.shared

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading) {
            Image(.hourglassBlocked128)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)

            Text("Focus Mode is ON")
                .font(.system(size: 15, weight: .bold))
                .padding(.bottom, 8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Sites not on your allow list are restricted. You can manage your list anytime in settings.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
                .multilineTextAlignment(.center)
                .frame(alignment: .center)

            Divider()

            HStack {
                Text("Time Left")
                Spacer()
                Text(coordinator.currentTimeRemaining)
                    .foregroundColor(.secondary)
            }.padding([.top, .bottom], 2)

            Divider()

            HStack {
                Image(.settings16)
                    .padding(.trailing, 2)
                Text("Customize Focus Mode")
            }
            .padding([.top, .bottom], 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? .menuItemHover : Color.clear)
            .onHover { isHovered in
                self.isHovered = isHovered
            }
            .onTapGesture {
                coordinator.openFocusModeSettings()
            }

        }
        .frame(width: 255)
        .padding(16)
    }
}

protocol FocusModePreferencesPersistor {
    var playSoundEnabled: Bool { get set }
}

struct FocusModePreferencesUserDefaultsPersistor: FocusModePreferencesPersistor {

    @UserDefaultsWrapper(key: .focusModePlaySoundEnabled, defaultValue: true)
    var playSoundEnabled: Bool
}

final class FocusSessionCoordinator: ObservableObject {

    static let shared = FocusSessionCoordinator() // Singleton instance

    private let notificationCenter: NotificationCenter
    let allowedSitesViewModel: ExcludedDomainsViewModel

    private var persistor: FocusModePreferencesPersistor
    private var timer: Timer?
    private var totalDuration: TimeInterval = 0
    private var remainingTime: TimeInterval = 0
    private var audioPlayer: AVAudioPlayer?
    private var menu = NSMenu()
    private var timeRemainingMenuItem: NSMenuItem
    private var cancellables = Set<AnyCancellable>()

    @UserDefaultsWrapper(key: .focusModeEnabled, defaultValue: false)
    private var isFocusModeEnabled: Bool

    @Published var status: Preferences.StatusIndicator?
    @Published var isCurrentOnFocusSession: Bool = false
    @Published var currentTimeRemaining: String = "--:--"
    @Published
    var isPlaySoundEnabled: Bool {
        didSet {
            persistor.playSoundEnabled = isPlaySoundEnabled
        }
    }

    private init(notificationCenter: NotificationCenter = .default,
                 persistor: FocusModePreferencesPersistor = FocusModePreferencesUserDefaultsPersistor(),
                 allowedSitesViewModel: ExcludedDomainsViewModel = DefaultAllowedDomainsViewModel()) {
        timeRemainingMenuItem = NSMenuItem(title: "Time remaining: --:--", action: nil, keyEquivalent: "")
        status = .off

        self.notificationCenter = notificationCenter
        self.persistor = persistor
        self.allowedSitesViewModel = allowedSitesViewModel
        self.isPlaySoundEnabled = persistor.playSoundEnabled
    }

    var canHaveAccessToTheFeature: Bool {
        NSApp.delegateTyped.internalUserDecider.isInternalUser
    }

    var isEnabled: Bool {
        NSApp.delegateTyped.internalUserDecider.isInternalUser && isFocusModeEnabled
    }

    func shouldBlock(url: URL) -> Bool {
        if (url.isSettingsURL || url.isDuckDuckGo || url.isDuckURLScheme) && !url.isDuckPlayer {
            return false
        }

        let isSiteAllowed = allowedSitesViewModel.domains.contains(where: { url.isPart(ofDomain: $0) })

        return !isSiteAllowed
    }

    func enableFeature() {
        if !isFocusModeEnabled {
            isFocusModeEnabled = true

            notificationCenter.post(name: .focusModeFeatureEnabled, object: nil)
        }
    }

    func startFocusSession(session: FocusSessionTimer) {
        isCurrentOnFocusSession = true
        status = .on
        totalDuration = session.duration
        remainingTime = totalDuration

        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRemainingTime()
        }

        RunLoop.current.add(timer!, forMode: RunLoop.Mode.common)

        publishRemainingTime()
    }

    private func updateRemainingTime() {
        if remainingTime > 0 {
            remainingTime -= 1
            publishRemainingTime()
        } else {
            cancelFocusSession()
            if isPlaySoundEnabled {
                playSound() // Play sound when the timer finishes
            }
        }
    }

    private func playSound() {
        guard isPlaySoundEnabled else { return } // Check if sound playback is enabled

        guard let url = Bundle.main.url(forResource: "duck-quack", withExtension: "wav") else {
            print("Sound file not found")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }

    private func publishRemainingTime() {
        let totalSeconds = Int(remainingTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        let timeString: String
        if hours > 0 {
            timeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            timeString = String(format: "%02d:%02d", minutes, seconds)
        }

        currentTimeRemaining = timeString

        // Update menu item
        timeRemainingMenuItem.title = "Time remaining: \(timeString)"
        menu.itemChanged(timeRemainingMenuItem)
    }

    @objc func cancelFocusSession() {
        isCurrentOnFocusSession = false
        status = .off
        timer?.invalidate() // Invalidate the timer if it's still running
        timer = nil
        remainingTime = 0
        timeRemainingMenuItem.title = "Time remaining: --:--" // Reset the menu item title
    }

    func getMenu() -> NSMenu {
        menu.removeAllItems()

        if isCurrentOnFocusSession {
            menu.addItem(timeRemainingMenuItem)
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Cancel session", action: #selector(cancelFocusSession), target: self, keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "25 minutes", action: #selector(startTwentyFiveMinutesSession), target: self))
            menu.addItem(NSMenuItem(title: "50 minutes", action: #selector(startFiftyMinutesSession), target: self))
            menu.addItem(NSMenuItem(title: "75 minutes", action: #selector(startSeventyFiveMinutessession), target: self))
            menu.addItem(NSMenuItem(title: "100 minutes", action: #selector(startOneHundredMinutesSession), target: self))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Manage Allowed Sites", action: #selector(openFocusModeSettings), target: self))
        }

        return menu
    }

    func showPopover(in view: NSView) {
        let popover = NSPopover()
        let contentView = FocusModeNavigationBarPopover()
        popover.animates = true
        popover.behavior = .semitransient
        popover.contentSize = NSHostingView(rootView: contentView).fittingSize
        let controller = NSViewController()
        controller.view = NSHostingView(rootView: contentView)
        popover.contentViewController = controller

        popover.show(positionedBelow: view)
    }

    @objc func startTwentyFiveMinutesSession() {
        startFocusSession(session: .twentyFive)
    }

    @objc func startFiftyMinutesSession() {
        startFocusSession(session: .fifty)
    }

    @objc func startSeventyFiveMinutessession() {
        startFocusSession(session: .seventyFive)
    }

    @objc func startOneHundredMinutesSession() {
        startFocusSession(session: .oneHundred)
    }

    @MainActor @objc func openFocusModeSettings() {
        WindowControllersManager.shared.showTab(with: .settings(pane: .focusMode))
    }
}
