//
//  AnimatableTypingText.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

#if canImport(UIKit)
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
typealias PlatformColor = NSColor
#endif

import SwiftUI
import Combine

// MARK: - View
public struct AnimatableTypingText: View {
    private let text: NSAttributedString
    private var startAnimating: Binding<Bool>
    private var skipAnimation: Binding<Bool>
    private var onTypingFinished: (() -> Void)?

    @StateObject private var model: AnimatableTypingTextModel

    public init(
        _ text: NSAttributedString,
        startAnimating: Binding<Bool> = .constant(true),
        skipAnimation: Binding<Bool> = .constant(false),
        onTypingFinished: (() -> Void)? = nil
    ) {
        self.text = text
        _model = StateObject(wrappedValue: AnimatableTypingTextModel(text: text, onTypingFinished: onTypingFinished))
        self.startAnimating = startAnimating
        self.skipAnimation = skipAnimation
        self.onTypingFinished = onTypingFinished
    }

    public init(
        _ text: String,
        startAnimating: Binding<Bool> = .constant(true),
        skipAnimation: Binding<Bool> = .constant(false),
        onTypingFinished: (() -> Void)? = nil
    ) {
        let attributesText = NSAttributedString(string: text)
        self.text = attributesText
        _model = StateObject(wrappedValue: AnimatableTypingTextModel(text: attributesText, onTypingFinished: onTypingFinished))
        self.startAnimating = startAnimating
        self.skipAnimation = skipAnimation
        self.onTypingFinished = onTypingFinished
    }

    public var body: some View {
        Group {
            if #available(iOS 15, macOS 12, *) {
                Text(AttributedString(model.typedAttributedText))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(model.typedAttributedText.string)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onChange(of: startAnimating.wrappedValue, perform: { shouldAnimate in
            if skipAnimation.wrappedValue {
                model.skip()
                return
            }

            if shouldAnimate {
                model.startAnimating()
            } else {
                model.stopAnimating()
            }
        })
        .onChange(of: skipAnimation.wrappedValue, perform: { shouldSkip in
            if shouldSkip {
                model.skip()
            }
        })
        .onAppear {
            if skipAnimation.wrappedValue {
                model.skip()
            } else if startAnimating.wrappedValue {
                model.startAnimating()
            }
        }
    }
}

// MARK: - Model

final class AnimatableTypingTextModel: ObservableObject {
    private var timer: TimerInterface?

    @Published private(set) var typedAttributedText: NSAttributedString = .init(string: "")

    private var typingIndex = 0
    private let text: NSAttributedString
    private let onTypingFinished: (() -> Void)?
    private let timerFactory: TimerCreating

    init(text: NSAttributedString, onTypingFinished: (() -> Void)?, timerFactory: TimerCreating = TimerFactory()) {
        self.text = text
        self.onTypingFinished = onTypingFinished
        self.timerFactory = timerFactory
        typedAttributedText = createAttributedString(original: text, visibleLength: 0)
    }

    func skip() {
        timer?.invalidate()
        timer = nil

        typedAttributedText = text
        onTypingFinished?()
    }

    func startAnimating() {
        timer?.invalidate()
        timer = timerFactory.makeTimer(withTimeInterval: 0.02, repeats: true, block: { [weak self] timer in
            guard timer.isValid else { return }
            self?.handleTimerEvent()
        })
    }

    func stopAnimating() {
        timer?.invalidate()
        timer = nil

        stopTyping()
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    private func handleTimerEvent() {
        if typingIndex >= text.length {
            onTypingFinished?()
            stopAnimating()
            return
        }

        showCharacter()
    }

    private func stopTyping() {
        typedAttributedText = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.onTypingFinished?()
        }
    }

    private func showCharacter() {
        typingIndex = min(typingIndex + 1, text.length)
        typedAttributedText = createAttributedString(original: text, visibleLength: typingIndex)
    }

    private func createAttributedString(original: NSAttributedString, visibleLength: Int) -> NSAttributedString {
        let totalRange = NSRange(location: 0, length: original.length)
        let visibleRange = NSRange(location: 0, length: min(visibleLength, original.length))

        // Make the entire text transparent
        let transparentText = original.applyingColor(.clear, to: totalRange)

        #if os(iOS)
        let visibleTextColor = UIColor.label
        #else
        let visibleTextColor = NSColor.labelColor
        #endif

        // Change the color to standard for the visible range
        let visibleText = transparentText.applyingColor(visibleTextColor, to: visibleRange)

        return visibleText
    }
}

// Extension to apply color to NSAttributedString
extension NSAttributedString {
    func applyingColor(_ color: PlatformColor, to range: NSRange) -> NSAttributedString {
        let mutableAttributedString = NSMutableAttributedString(attributedString: self)

        mutableAttributedString.enumerateAttributes(in: range, options: []) { attributes, range, _ in
            var newAttributes = attributes
            newAttributes[.foregroundColor] = color
            mutableAttributedString.setAttributes(newAttributes, range: range)
        }

        return mutableAttributedString
    }
}
