//
//  ContentView.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-02.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var vendorAuthManager: VendorAuthManager
    @EnvironmentObject var productHolder: ProductHolder
    
    //    @FetchRequest(
    //        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
    //        animation: .default)
    
    var body: some View {
        TabView {
            ProductsView()
                .tabItem {
                    Label("Products", systemImage: "bag")
                }
            
            OrderHistoryView()
                .tabItem {
                    Label("Orders", systemImage: "clock.arrow.circlepath")
                }
            
            if authManager.isAuthenticated {
                CartView()
                    .tabItem {
                        Label("Cart", systemImage: "cart.fill")
                    }
                
                AllVendorsMapView().tabItem {
                    Label("Map", systemImage: "map")
                }
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
            
            } else if vendorAuthManager.isAuthenticated {
                VendorProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
            }
        }
        
        //    private func addItem() {
        //        withAnimation {
        //            let newItem = Item(context: viewContext)
        //            newItem.timestamp = Date()
        //
        //            do {
        //                try viewContext.save()
        //            } catch {
        //                // Replace this implementation with code to handle the error appropriately.
        //                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        //                let nsError = error as NSError
        //                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        //            }
        //        }
        //    }
        //
        //    private func deleteItems(offsets: IndexSet) {
        //        withAnimation {
        //            offsets.map { items[$0] }.forEach(viewContext.delete)
        //
        //            do {
        //                try viewContext.save()
        //            } catch {
        //                // Replace this implementation with code to handle the error appropriately.
        //                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        //                let nsError = error as NSError
        //                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        //            }
        //        }
        //    }
        //}
        //
        //private let itemFormatter: DateFormatter = {
        //    let formatter = DateFormatter()
        //    formatter.dateStyle = .short
        //    formatter.timeStyle = .medium
        //    return formatter
        //}()
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
