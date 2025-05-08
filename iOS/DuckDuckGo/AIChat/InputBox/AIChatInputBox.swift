//
//  AIChatInputBox.swift
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
import UIKit

struct ExpandingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    @Binding var isFirstResponder: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.font = .preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.textContainer.lineBreakMode = .byCharWrapping
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        updateHeight(for: uiView)

        DispatchQueue.main.async {
            switch (isFirstResponder, uiView.isFirstResponder) {
            case (true, false):
                uiView.becomeFirstResponder()
            case (false, true):
                uiView.resignFirstResponder()
            default:
                break
            }
        }
    }

    private func updateHeight(for view: UIView) {
        let newHeight = view.sizeThatFits(CGSize(width: view.bounds.width, height: .greatestFiniteMagnitude)).height
        if height != newHeight {
            DispatchQueue.main.async {
                height = newHeight
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, height: $height)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        @Binding var height: CGFloat

        init(text: Binding<String>, height: Binding<CGFloat>) {
            _text = text
            _height = height
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            let newHeight = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)).height
            if height != newHeight {
                DispatchQueue.main.async {
                    self.height = newHeight
                }
            }
        }
    }
}

struct AIChatInputBox: View {
    @ObservedObject var viewModel: AIChatInputBoxViewModel

    @State private var isFocused = false
    @State private var text = ""
    @State private var textHeight: CGFloat = 40

    private var isSendButtonDisabled: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                if isFocused {
                    ExpandingTextView(text: $text, height: $textHeight, isFirstResponder: $isFocused)
                        .frame(minHeight: 40, maxHeight: 200)
                        .frame(height: textHeight)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .layoutPriority(1)

                    Button {
                        viewModel.submitText(text)
                        text = ""
                        withAnimation(.spring()) {
                            isFocused = false
                        }
                    } label: {
                        Image(systemName: "paperplane.circle.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(isSendButtonDisabled ? .gray : .blue)
                    }
                    .disabled(isSendButtonDisabled)
                    .fixedSize()
                } else {
                    Button {
                        viewModel.fireButtonPressed()
                    } label: {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 20, weight: .medium))
                    }
                    .fixedSize()

                    Text(text.isEmpty ? "Enter message..." : text)
                        .foregroundColor(text.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                isFocused = true
                            }
                        }

                    Button {
                        viewModel.newChatButtonPressed()
                        withAnimation(.spring()) {
                            isFocused = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 20, weight: .medium))
                    }
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

struct AIChatInputBox_Previews: PreviewProvider {
    static var previews: some View {
        AIChatInputBox(viewModel: AIChatInputBoxViewModel())
    }
}
