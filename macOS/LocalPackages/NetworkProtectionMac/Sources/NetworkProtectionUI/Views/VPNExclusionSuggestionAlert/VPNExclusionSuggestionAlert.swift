//
//  VPNExclusionSuggestionAlert.swift
//  NetworkProtectionMac
//
//  Created by ddg on 3/24/25.
//

import SwiftUI
import SwiftUIExtensions

/*
@main
struct VPNAlertApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var isShowingAlert = false

    var body: some View {
        VStack {
            Button("Show Alert") {
                isShowingAlert = true
            }
            .padding()
        }
        .sheet(isPresented: $isShowingAlert) {
            VPNExclusionSuggestionAlert(isPresented: $isShowingAlert)
        }
    }
}*/

struct VPNExclusionSuggestionAlert: ModalView {
    @Environment(\.dismiss) private var dismiss
    @State private var dontAskAgain = false

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Is the VPN causing problems with a Website or App?")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.top, 20)

            // Description
            Text("You can exclude websites and apps from the VPN without turning it off.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Checkbox
            Toggle(isOn: $dontAskAgain) {
                Text("Don't Ask Again")
                    .font(.subheadline)
            }
            .toggleStyle(CheckboxToggleStyle())
            .padding(.horizontal)

            // Buttons
            HStack(spacing: 10) {
                Button(action: {
                    // Action for "Turn off VPN"
                    print("Turn off VPN tapped")
                    dismiss()
                }) {
                    Text("Turn off VPN")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: {
                    // Action for "Exclude a Website"
                    print("Exclude a Website tapped")
                    dismiss()
                }) {
                    Text("Exclude a Website")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }

                Button(action: {
                    // Action for "Exclude an App"
                    print("Exclude an App tapped")
                    dismiss()
                }) {
                    Text("Exclude an App")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .frame(width: 400)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 10)
    }
}

// Custom Checkbox Style for Toggle
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .blue : .gray)
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            configuration.label
        }
    }
}

struct VPNExclusionSuggestionAlert_Previews: PreviewProvider {
    static var previews: some View {
        VPNExclusionSuggestionAlert()
    }
}
