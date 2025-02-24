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
        WebExtension(id: 1, name: "Dark Reader", description: "Enable dark mode on all websites", iconName: "darkreader", url: "https://addons.mozilla.org/firefox/downloads/file/4433330/darkreader-4.9.101.xpi"),
        WebExtension(id: 2, name: "Emoji", description: "Securely store your passwords", iconName: "emoji", url: "https://addons.mozilla.org/firefox/downloads/file/4433330/darkreader-4.9.101.xpi"),
        WebExtension(id: 3, name: "LanguageTool", description: "With this extension you can check text with the free style and grammar checker", iconName: "languagetool", url: "https://addons.mozilla.org/firefox/downloads/file/4433330/darkreader-4.9.101.xpi"),
        WebExtension(id: 4, name: "Bitwarden", description: "Bitwarden easily secures all your passwords, passkeys, and sensitive information", iconName: "bitwarden1", url: "https://addons.mozilla.org/firefox/downloads/file/4433330/darkreader-4.9.101.xpi"),
        WebExtension(id: 5, name: "Tomato Clock", description: "Simple browser extension that helps with online time management.", iconName: "tomato", url: "https://addons.mozilla.org/firefox/downloads/file/4433330/darkreader-4.9.101.xpi")
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
    let url: String
    var category: String = "Featured"
}

struct ExtensionCardView: View {
    let extensionItem: WebExtension
    @State private var isDownloading = false
    @State private var isInstalled = false

    var body: some View {
        VStack(alignment: .leading) {
            Image(extensionItem.iconName)
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
                if isInstalled {
                    removeExtension()
                } else {
                    downloadExtension()
                }
            }) {
                if isDownloading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(isInstalled ? "Remove" : "Install")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.top, 5)
        }
        .padding()
        .background(Color.preferencesBackground)
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    func downloadExtension() {
        guard let downloadURL = URL(string: extensionItem.url) else { return }
        isDownloading = true

        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destinationURL = downloadsDirectory.appendingPathComponent(downloadURL.lastPathComponent)

        let task = URLSession.shared.downloadTask(with: downloadURL) { tempURL, response, error in

            guard let tempURL = tempURL, error == nil else { return }

            do {
                let zipURL = downloadsDirectory.appendingPathComponent(downloadURL.deletingPathExtension().lastPathComponent + ".zip")

                // Remove existing file if it exists before moving
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                if FileManager.default.fileExists(atPath: zipURL.path) {
                    try FileManager.default.removeItem(at: zipURL)
                }
                try FileManager.default.moveItem(at: destinationURL, to: zipURL)

                let unzipDirectory = downloadsDirectory.appendingPathComponent(downloadURL.deletingPathExtension().lastPathComponent)

                // Remove existing directory if it exists
                if FileManager.default.fileExists(atPath: unzipDirectory.path) {
                    try FileManager.default.removeItem(at: unzipDirectory)
                }

                try FileManager.default.createDirectory(at: unzipDirectory, withIntermediateDirectories: true, attributes: nil)

                let process = Process()
                process.launchPath = "/usr/bin/unzip"
                process.arguments = ["-o", zipURL.path, "-d", unzipDirectory.path]
                process.launch()
                process.waitUntilExit()

                if #available(macOS 15.3, *) {
                    DispatchQueue.main.async {
                        WebExtensionManager.shared.addExtension(path: unzipDirectory.absoluteString + "/")
                    }
                }

                DispatchQueue.main.async {
                    isInstalled = true
                }
            } catch {
                print("Error handling downloaded file: \(error)")
            }

            DispatchQueue.main.async {
                isDownloading = false
            }
        }

        task.resume()
    }

    func removeExtension() {
        // Implement the removal logic here
        // For now, we'll just toggle the isInstalled state
        isInstalled = false
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
