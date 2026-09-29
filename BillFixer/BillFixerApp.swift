//
//  BillFixerApp.swift
//  BillFixer
//

import SwiftUI

@main
struct BillFixerApp: App {
    @StateObject private var settings = SettingsManager()
    @State private var session = AppSession()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(settings)
                .environment(session)
                .environment(\.locale, Locale(identifier: settings.languageCode))
                .preferredColorScheme(settings.preferredColorScheme)
                .tint(BFColor.blue)
        }
    }
}
