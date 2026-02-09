//
//  LocalStoreProjectApp.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-02.
//

import CoreData
import FirebaseCore  // Necesito añadir las librerias primero en la config del proyecto en frameworks las que necesite (Auth,Store, Etc)
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication
            .LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        return true
    }
}

@main
struct LocalStoreProjectApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        let context = PersistenceController.shared.container.viewContext
        _authManager = StateObject(
            wrappedValue: AuthManager(viewContext: context)
        )
        _vendorAuthManager = StateObject(
            wrappedValue: VendorAuthManager(viewContext: context)
        )
    }

    @StateObject private var authManager: AuthManager
    @StateObject private var vendorAuthManager: VendorAuthManager
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            ContentRoutes()
                .environment(
                    \.managedObjectContext,
                    persistenceController.container.viewContext
                )
                .environmentObject(authManager)
                .environmentObject(vendorAuthManager)

        }
    }
}

struct ContentRoutes: View {

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var vendorAuthManager: VendorAuthManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                ProfileView()
                    .environmentObject(authManager)
            } else if vendorAuthManager.isAuthenticated {
                VendorProfileView()
                    .environmentObject(vendorAuthManager)
            } else {
                LoginPage()
                    .environmentObject(authManager)
            }
        }
    }
}
