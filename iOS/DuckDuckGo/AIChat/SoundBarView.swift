//
//  SoundBarView.swift
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


import SwiftUI
import AVFoundation

struct SoundBarView: View {
    @Binding var isAnimating: Bool
    @State private var height: CGFloat = 0.1
    let animationDuration: Double

    init(isAnimating: Binding<Bool>) {
        self._isAnimating = isAnimating
        self.animationDuration = Double.random(in: 0.1...0.4)
    }

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.blue)
                .frame(width: geometry.size.width * 0.8, height: geometry.size.height * self.height)
                .position(x: geometry.size.width / 2, y: geometry.size.height - (geometry.size.height * self.height / 2))
                .onChange(of: isAnimating) { newValue in
                    if newValue {
                        self.animateBar()
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.height = 0.1
                        }
                    }
                }
        }
    }

    private func animateBar() {
        guard isAnimating else { return }
        withAnimation(Animation.easeInOut(duration: animationDuration).repeatForever(autoreverses: true)) {
            self.height = CGFloat.random(in: 0.1...1.0)
        }
    }
}

struct SoundBarsView: View {
    @Binding var isAnimating: Bool
    let numberOfBars: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<numberOfBars, id: \.self) { _ in
                SoundBarView(isAnimating: $isAnimating)
            }
        }
    }
}


struct SpeechView: View {
    let text: String
    @Binding var isShowingSheet: Bool
    @State private var isSpeaking = false
    @State private var isAnimating = false
    @State private var currentWordRange: NSRange = NSRange(location: 0, length: 0)

    let speechSynthesizer = AVSpeechSynthesizer()
    @State private var delegate: SpeechSynthesizerDelegate?

    var body: some View {
        VStack() {
            HStack {
                Button {
                    stopSpeaking()
                    isShowingSheet = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)

                }
                .buttonStyle(.bordered)
                .clipShape(Circle())

                Spacer()
            }
            .padding()

            ScrollView {
                Text(attributedText)
                    .font(.body)
                    .padding()
            }
            .frame(maxHeight: .infinity)


            SoundBarsView(isAnimating: $isAnimating, numberOfBars: 15)
                .frame(maxHeight: 66)
                .padding()


            Button {
                if isSpeaking {
                    stopSpeaking()
                } else {
                    startSpeaking()
                }
            } label: {
                Image(systemName: isSpeaking ? "stop.circle.fill" : "play.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(isSpeaking ? .red : .green)

            }
            Spacer()

        }
        
        .onAppear {
            startSpeaking()
        }
        .onDisappear {
            stopSpeaking()
        }
    }

    var attributedText: AttributedString {
        var attributed = AttributedString(text)

        if let stringRange = Range(currentWordRange, in: text) {
            let startIndex = AttributedString.Index(stringRange.lowerBound, within: attributed)
            let endIndex = AttributedString.Index(stringRange.upperBound, within: attributed)

            if let startIndex = startIndex, let endIndex = endIndex {
                attributed[startIndex..<endIndex].foregroundColor = .primary
                if startIndex > attributed.startIndex {
                    attributed[attributed.startIndex..<startIndex].foregroundColor = .secondary
                }
                if endIndex < attributed.endIndex {
                    attributed[endIndex..<attributed.endIndex].foregroundColor = .secondary
                }
            } else {
                attributed.foregroundColor = .secondary
            }
        } else {
            attributed.foregroundColor = .secondary
        }

        return attributed
    }

    func startSpeaking() {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        delegate = SpeechSynthesizerDelegate(
            onFinish: stopSpeaking,
            onWordBoundary: { range in
                self.currentWordRange = range
            }
        )
        speechSynthesizer.delegate = delegate
        speechSynthesizer.speak(utterance)
        isSpeaking = true
        isAnimating = true
    }

    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isAnimating = false
        currentWordRange = NSRange(location: 0, length: 0)
    }
}

class SpeechSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: () -> Void
    var onWordBoundary: (NSRange) -> Void

    init(onFinish: @escaping () -> Void, onWordBoundary: @escaping (NSRange) -> Void) {
        self.onFinish = onFinish
        self.onWordBoundary = onWordBoundary
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.onFinish()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        self.onWordBoundary(characterRange)
    }
}


#Preview {
    SpeechView(text: "You have selected microsoft Sam as your computer default voiceYou have selected microsoft Sam as your computer default voiceYou have selected microsoft Sam as your computer default voiceYou have selected microsoft Sam as your computer default voice", isShowingSheet: .constant(true))
}
