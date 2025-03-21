import SwiftUI
import Core
import DuckUI

/// A debug settings view for DuckPlayer that provides options to reset and manage DuckPlayer-specific settings.
struct DuckPlayerDebugSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let appSettings: AppSettings
    
    init(appSettings: AppSettings = AppDependencyProvider.shared.appSettings) {
        self.appSettings = appSettings
    }
    
    var body: some View {
        List {
            Section(header: Text("Priming Modal")) {
                Button(role: .destructive) {
                    resetPrimingModalSettings()
                } label: {
                    Text("Reset Priming Modal State")
                }
            }
        }
        .navigationTitle("DuckPlayer")
    }
    
    private func resetPrimingModalSettings() {
        appSettings.duckPlayerNativeUIPrimingModalPresentedCount = 0
        appSettings.duckPlayerNativeUIPrimingModalTimeSinceLastPresented = 0
    }
}
