//
//  BrowserToggleInputView.swift
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

struct BrowserToggleInputView: View {
    @ObservedObject var viewModel: AIChatInputBoxViewModel

    private let lineHeight: CGFloat = 25
    private let maxLines: Int = 7
    private let minLines: Int = 3
    let submitButtonPressed: () -> Void

    enum Position {
        case top
        case bottom
    }

    var body: some View {
        inputTextView
            .animation(.easeInOut, value: viewModel.inputMode)
    }

    var inputTextView: some View {
        Group {
            HStack(alignment: .top, spacing: 8) {
                if viewModel.inputMode == .search {
                    SearchTextField(text: $viewModel.inputText, placeholder: placeHolderText, viewModel: viewModel)
                        .textFieldStyle(.plain)
                        .frame(maxWidth: .infinity)
                } else {
                    ChatTextEditor(text: $viewModel.inputText)
                }
                VStack {
                    if !viewModel.inputText.isEmpty {
                        Button {
                            viewModel.clearText()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }

                    if viewModel.inputMode == .chat {
                        VStack {
                            Spacer()
                            Button {
                                submitButtonPressed()
                            } label: {
                                Image(systemName: "paperplane.circle.fill")
                                    .font(.system(size: 36, weight: .medium))
                                    .foregroundColor(viewModel.inputText.isEmpty ? .gray : .blue)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.inputText.isEmpty)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: calculatedHeight)
        .padding()
        .animation(.easeInOut, value: calculatedHeight)
    }

    var placeHolderText: String {
        switch viewModel.inputMode {
        case .search:
            return "Search..."
        case .chat:
            return "Type your message..."
        }
    }

    private var calculatedHeight: CGFloat {
        switch viewModel.inputMode {
        case .search:
            return lineHeight
        case .chat:
            var numberOfLines = min(viewModel.inputText.numberOfLines(), maxLines)
            numberOfLines = max(minLines, numberOfLines)
            return max(lineHeight, CGFloat(numberOfLines) * lineHeight)
        }
    }
}

struct SearchTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let viewModel: AIChatInputBoxViewModel

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.delegate = context.coordinator
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.keyboardType = .webSearch
        textField.autocapitalizationType = .none
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        if !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, viewModel: viewModel)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        let viewModel: AIChatInputBoxViewModel

        init(text: Binding<String>, viewModel: AIChatInputBoxViewModel) {
            _text = text
            self.viewModel = viewModel
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            if textField.text != text {
                DispatchQueue.main.async {
                    self.text = textField.text ?? ""
                }
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            viewModel.submitText(textField.text ?? "")
            viewModel.clearText()
            return true
        }
    }
}

struct ChatTextEditor: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .body)
        textView.isScrollEnabled = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        if !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }
    }
}

extension String {
    func numberOfLines() -> Int {
        let lines = self.components(separatedBy: "\n")
        return lines.count
    }
}
