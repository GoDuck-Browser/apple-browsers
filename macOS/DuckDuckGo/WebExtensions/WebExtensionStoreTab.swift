//
//  WebExtensionStoreTab.swift
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

struct WebExtensionStoreTab: View {
    @State private var searchText: String = ""
    @State private var selectedCategory: String? = nil

    let categories = ["Featured", "Popular", "Productivity", "Privacy", "Themes"]
    let extensions = [
        WebExtension(id: 1, name: "Ad Blocker", description: "Block ads and trackers", iconName: "shield.lefthalf.fill"),
        WebExtension(id: 2, name: "Dark Mode", description: "Enable dark mode on all websites", iconName: "moon.fill"),
        WebExtension(id: 3, name: "Password Manager", description: "Securely store your passwords", iconName: "lock.fill")
    ]

    var body: some View {
        NavigationView {
            List(categories) { category in
                Button(action: {
                    selectedCategory = category
                }) {
                    Text(category)
                        .fontWeight(selectedCategory == category ? .bold : .regular)
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Extensions")

            VStack {
                SearchBar(text: $searchText)
                    .padding()

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                        ForEach(filteredExtensions) { extensionItem in
                            ExtensionCardView(extensionItem: extensionItem)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(selectedCategory ?? "Featured")
        }
    }

    var filteredExtensions: [WebExtension] {
        extensions.filter { ext in
            (searchText.isEmpty || ext.name.localizedCaseInsensitiveContains(searchText)) &&
            (selectedCategory == nil || selectedCategory == "Featured" || ext.category == selectedCategory)
        }
    }
}

struct WebExtension: Identifiable {
    let id: Int
    let name: String
    let description: String
    let iconName: String
    var category: String = "Featured"
}

struct ExtensionCardView: View {
    let extensionItem: WebExtension

    var body: some View {
        VStack(alignment: .leading) {
            Image(systemName: extensionItem.iconName)
                .resizable()
                .scaledToFit()
                .frame(height: 50)
                .padding()
            Text(extensionItem.name)
                .font(.headline)
            Text(extensionItem.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Button(action: {
                // Install action
            }) {
                Text("Install")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.top, 5)
        }
        .padding()
        .background(Color.preferencesBackground)
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search extensions", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct WebExtensionStoreTab_Previews: PreviewProvider {
    static var previews: some View {
        WebExtensionStoreTab()
    }
}
