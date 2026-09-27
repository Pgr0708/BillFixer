//
//  BillFixerApp.swift
//  BillFixer
//
//  Created by Minaxi on 27/09/26.
//

import SwiftUI
import CoreData

@main
struct BillFixerApp: App {
    @StateObject private var settings = SettingsManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(settings)
                .environment(
                    \.locale,
                     Locale(identifier: settings.languageCode)
                     )
                .environment(
                           \.managedObjectContext,
                           CoreDataManager.shared.context
                       )
                .preferredColorScheme(settings.preferredColorScheme)
        }
    }
}
