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
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Times Shown: \(appSettings.duckPlayerNativeUIPrimingModalPresentedCount)")
                        .font(.footnote)
                    Text("Last Shown: \(formattedLastShownTime)")
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("DuckPlayer")
    }
    
    private var formattedLastShownTime: String {
        let timestamp = appSettings.duckPlayerNativeUIPrimingModalTimeSinceLastPresented
        guard timestamp > 0 else { return "Never" }
        
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func resetPrimingModalSettings() {
        appSettings.duckPlayerNativeUIPrimingModalPresentedCount = 0
        appSettings.duckPlayerNativeUIPrimingModalTimeSinceLastPresented = 0
    }
}
