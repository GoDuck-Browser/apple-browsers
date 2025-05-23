//
//  PinnedTabsView.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

struct PinnedTabsView: View {
    private let tabStyleProvider: TabStyleProviding = NSApp.delegateTyped.visualStyleManager.style.tabStyleProvider

    @ObservedObject var model: PinnedTabsViewModel
    @State private var draggedTab: Tab?

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(model.items) { item in
                PinnedTabView(tabStyleProvider: tabStyleProvider,
                              model: item,
                              showsHover: draggedTab == nil)
                    .environmentObject(model)
                    .frame(maxWidth: tabStyleProvider.pinnedTabWidth,
                           maxHeight: tabStyleProvider.pinnedTabHeight)
                    .zIndex(model.selectedItem == item ? 1 : 0)
            }
        }
        .frame(minHeight: tabStyleProvider.pinnedTabHeight)
        .simultaneousGesture(dragGesture)
    }

    var dragGesture: some Gesture {
        DragGesture()
            .onChanged(updateDrag)
            .onEnded(endDrag)
    }

    private func updateDrag(_ value: DragGesture.Value) {
        if draggedTab == nil {
            let draggedTabIndex = itemIndex(for: value.startLocation.x)
            draggedTab = model.items[draggedTabIndex]
        }
        guard let draggedTab = draggedTab, let from = model.items.firstIndex(of: draggedTab) else {
            return
        }
        let to = itemIndex(for: value.location.x)

        if to != from, model.items[to] != draggedTab {
            withAnimation(.easeInOut(duration: 0.2)) {
                model.items.move(fromOffsets: IndexSet(integer: from),
                                 toOffset: to > from ? to + 1 : to)
            }
        }
    }

    private func endDrag(_ value: DragGesture.Value) {
        draggedTab = nil
    }

    private func itemIndex(for x: CGFloat) -> Int {
        max(0, min(Int(x / CGFloat(tabStyleProvider.pinnedTabWidth)), model.items.count - 1))
    }
}

extension PinnedTabsView {

    func index(forItemAt point: CGPoint) -> Int? {
        guard !model.items.isEmpty,
              (0..<tabStyleProvider.pinnedTabWidth).contains(point.y) else { return nil }

        let possibleItemIndex = min(model.items.count - 1, Int(point.x / tabStyleProvider.pinnedTabWidth))
        return model.items.index(model.items.startIndex, offsetBy: possibleItemIndex, limitedBy: model.items.endIndex)
    }

}
