//
//  DuckPlayerContainer.swift
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

import Combine
import SwiftUI

private let sheetTopMargin = 44.0

public enum DuckPlayerContainer {
  
  public enum DismissTrigger {
    case userInteraction
    case programmatic
  }

  public struct PresentationMetrics {
    public let contentWidth: Double
  }

  @MainActor
  public final class ViewModel: ObservableObject {
    @Published public private(set) var sheetVisible = false
    @Published public var hasDragHandle = false

    private let _onDismiss = PassthroughSubject<DismissTrigger, Never>()
    public private(set) lazy var onDismiss = _onDismiss.eraseToAnyPublisher()

    private var subscriptions = Set<AnyCancellable>()

    public func show() {      
      sheetVisible = true
    }

    public func dismiss(trigger: DismissTrigger) {
      sheetVisible = false
      _onDismiss.send(trigger)
    }
  }

  public struct Container<Content: View>: View {
    @ObservedObject var viewModel: ViewModel

    @State private var keyboardVisible = false
    @State private var sheetHeight = 0.0

    let hasBackground: Bool
    let content: (PresentationMetrics) -> Content

    public init(viewModel: ViewModel, hasBackground: Bool = true, @ViewBuilder content: @escaping (PresentationMetrics) -> Content) {
      self.viewModel = viewModel
      self.hasBackground = hasBackground
      self.content = content
    }

    @ViewBuilder private func sheet(containerHeight: Double) -> some View {
      SheetView(
        viewModel: viewModel,
        containerHeight: containerHeight,
        content: content,
        onHeightChange: { sheetHeight = $0 }
      )
    }

    public var body: some View {
      GeometryReader { geometry in
        let containerHeight = geometry.size.height
        ZStack {
          if hasBackground {
            Color.black
              .ignoresSafeArea()
              .opacity(viewModel.sheetVisible ? 1 : 0)
              .animation(.easeInOut(duration: 0.2), value: viewModel.sheetVisible)
              .onTapGesture { viewModel.dismiss(trigger: .userInteraction) }
          }
          Group {
            sheet(containerHeight: containerHeight)
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, keyboardVisible ? 20 : 0)
            
          }
        }
      }     
    }
  }
}

// MARK: - Private

private func calculateSheetOffset(for visible: Bool, containerHeight: Double) -> Double {
  visible ? 0 : containerHeight + 100
}

@MainActor
private struct SheetView<Content: View>: View {
  @ObservedObject var viewModel: DuckPlayerContainer.ViewModel
  let containerHeight: Double
  let content: (DuckPlayerContainer.PresentationMetrics) -> Content
  let onHeightChange: (Double) -> Void

  @State private var sheetHeight: Double = 0
  @State private var sheetWidth: Double?
  // Start at a high number so that the content doesn't flash on screen before we have the correct geometry values.
  @State private var sheetOffset = 10000.0

  @GestureState private var dragStartOffset: Double? = nil

  @ViewBuilder private var handle: some View {
    RoundedRectangle(cornerRadius: 2, style: .circular)
      .fill(Color.gray)
      .frame(width: 36, height: 4)
  }

  var body: some View {
    VStack(alignment: .center, spacing: 8) {
      if viewModel.hasDragHandle {
        HStack {
          handle
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
      }
      if let sheetWidth {
        content(DuckPlayerContainer.PresentationMetrics(contentWidth: sheetWidth))
      }
    }
    .onWidthChange { newWidth in
      sheetWidth = newWidth
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(Color.white)
        .shadow(color: Color.gray, radius: 36, y: 10)
    )
    .offset(y: sheetOffset)
    .animation(.easeInOut, value: viewModel.hasDragHandle)
    .onAppear {
      sheetOffset = calculateSheetOffset(for: viewModel.sheetVisible, containerHeight: containerHeight)
    }
    // If we use an animation() modifier for this this also animates all the content in with the spring
    // when the offset changes. To avoid this, use withAnimation() explicitly.
    .onChange(of: viewModel.sheetVisible) { sheetVisible in
      withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
        sheetOffset = calculateSheetOffset(for: sheetVisible, containerHeight: containerHeight)
      }
    }
    .onChange(of: containerHeight) { containerHeight in
      withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
        sheetOffset = calculateSheetOffset(for: viewModel.sheetVisible, containerHeight: containerHeight)
      }
    }
    // Add top padding to make the sheet easier to drag
    .padding(.top, sheetTopMargin)
    // For some reason contentShape() isn't working here for hit testing
    .background(.black.opacity(viewModel.sheetVisible ? 0.001 : 0))
    .highPriorityGesture(
      DragGesture()
        .updating($dragStartOffset) { _, state, _ in
          if state == nil {
            state = sheetOffset
          }
        }
        .onChanged { value in
          guard let dragStartOffset else { return }

          let offsetY = value.translation.height
          withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
            if offsetY < 0 {
              // Sigmoid function to decay the drag upwards to emulate resistance.
              let y = 1.0 / (1.0 + exp(-1 * (abs(offsetY) / 50.0))) - 0.5

              sheetOffset = dragStartOffset + y * max(offsetY, -150)
            } else {
              sheetOffset = dragStartOffset + offsetY
            }
          }
        }
        .onEnded { value in
          if value.translation.height > sheetHeight * 0.5 || value.velocity.height > 150 {
            viewModel.dismiss(trigger: .userInteraction)
          } else {
            withAnimation(.spring(duration: 0.2, bounce: 0.4)) {
              sheetOffset = calculateSheetOffset(for: viewModel.sheetVisible, containerHeight: containerHeight)
            }
          }
        }
    )
    .onHeightChange { newHeight in
      sheetHeight = newHeight
      onHeightChange(newHeight)
    }
  }
}

// MARK: - View Extensions

extension View {
  func onWidthChange(perform action: @escaping (Double) -> Void) -> some View {
    background(
      GeometryReader { geometry in
        Color.clear
          .preference(key: WidthPreferenceKey.self, value: geometry.size.width)
          .onPreferenceChange(WidthPreferenceKey.self, perform: action)
      }
    )
  }
  
  func onHeightChange(perform action: @escaping (Double) -> Void) -> some View {
    background(
      GeometryReader { geometry in
        Color.clear
          .preference(key: HeightPreferenceKey.self, value: geometry.size.height)
          .onPreferenceChange(HeightPreferenceKey.self, perform: action)
      }
    )
  }
}

// MARK: - Preference Keys

private struct WidthPreferenceKey: PreferenceKey {
  static var defaultValue: Double = 0
  static func reduce(value: inout Double, nextValue: () -> Double) {
    value = nextValue()
  }
}

private struct HeightPreferenceKey: PreferenceKey {
  static var defaultValue: Double = 0
  static func reduce(value: inout Double, nextValue: () -> Double) {
    value = nextValue()
  }
}
