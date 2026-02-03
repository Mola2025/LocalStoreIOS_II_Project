//
//  LocalStoreProjectApp.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-02.
//

import SwiftUI
import CoreData

import FirebaseCore  // Necesito añadir las librerias primero en la config del proyecto en frameworks las que necesite (Auth,Store, Etc)


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
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
