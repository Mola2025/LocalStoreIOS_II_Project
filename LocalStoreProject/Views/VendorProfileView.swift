//
//  VendorProfileView.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-08.
//

import CoreData
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SDWebImageSwiftUI
import SwiftUI


struct VendorProfileView: View {
    
    @EnvironmentObject var vendorAuthManager: VendorAuthManager
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var currentVendor: Vendor? = nil
    @State private var errorMessage: String? = nil
    
    // For the address
    @State private var showAddressPicker = false
    
    // For the Toast
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false
    
    var body: some View {
        NavigationView{
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Header
                    if let vendor = currentVendor {
                        VStack(spacing: 20) {
                            HStack(alignment: .top, spacing: 16) {
                                
                                WebImage(
                                    url: URL(string: vendor.profileImageURL ?? "")
                                )
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack{
                                        Image(systemName: "storefront.fill")
                                        Text(vendor.displayName)
                                            .font(.system(size: 26))
                                            .bold()
                                    }

                                    Text(vendor.email ?? "No email")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                    
                                    if let description = vendor.vendorDescription, !description.isEmpty {
                                        Text(description)
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .lineLimit(3)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.top, 4)
                            
                            Divider()
                        }
                        
                        // Buttons
                        
                        HStack(spacing: 12) {
                            
                            NavigationLink(destination: EditVendorProfileView()) {
                                Text("Edit Profile")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(30)
                            
                            Button(role: .destructive) {
                                signOut()
                            } label: {
                                Text("Sign Out")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(30)
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        VStack(alignment: .leading,spacing: 12){
                            Text("Store Location")
                                .font(.title2)
                                .bold()
                                .padding(.horizontal)
                            
                            if let address = vendor.address, address.hasValidCoordinates {
                                AddressMiniMapView(
                                    coordinate: address.coordinate,
                                    addressText: address.displayAddress,
                                    onEditTapped: {
                                        showAddressPicker = true
                                    }
                                )
                            }
                            else{
                                VStack(spacing: 12){
                                    Image(systemName: "mappin.slash")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("No Store Location Registered")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text("Add your store location so customer can find you on the map")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    Button{
                                        showAddressPicker = true
                                    } label: {
                                        Label("Add Store Location", systemImage: "plus")
                                            .frame(maxWidth:.infinity)
                                            .padding()
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                    }.padding(.horizontal)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }.padding(.vertical)
                        
                        Divider()
                        
//                        // TODO: Add section for products management
//                        VStack(alignment: .leading, spacing: 12) {
//                            Text("My Products")
//                                .font(.title2)
//                                .bold()
//                                .padding(.horizontal)
//                            
//                            Text("Product management coming soon...")
//                                .foregroundColor(.gray)
//                                .padding(.horizontal)
//                        }
//                        .padding(.vertical)
                    }
                }
                
            }            .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.large)
            .onAppear{
                loadVendor()
            }
            .sheet(isPresented: $showAddressPicker){
                AddressPickerView(
                    onSave: {
                        lat,
                        lon,
                        city,
                        street in
                        saveAddress(
                            lat: lat,
                            lon: lon,
                            city: city,
                            street: street
                        )
                    },
                    initialCoordinate: currentVendor?.address?.coordinate
                )
            }
            .toast(
                isPresented: $showToast,
                message: toastMessage,
                isError: toastIsError
            )
        }
    }
    private func loadVendor(){
        if let vendor = vendorAuthManager.currentVendor{
            self.currentVendor = vendor
        }
    }
    
    private func saveAddress(lat: Double, lon: Double, city: String, street: String){
        guard let vendor = currentVendor else {return}
        
        let manager = AddressManager(viewContext: viewContext)
        manager
            .saveAddressForVendor(
                vendor: vendor,
                latitude: lat,
                longitude: lon,
                city: city,
                street: street
            ){
                result in
                DispatchQueue.main.async{
                    switch result {
                    case .success:
                        self.loadVendor()
                        self.showSuccess("Store Location Saved Successfully")
                    case .failure(let error):
                        self.showError("Error saving location: \(error.localizedDescription)")
                    }
                }
            }
    }
    
    private func signOut() {
        vendorAuthManager.signOut { result in
            switch result {
            case .success():
                self.errorMessage = nil
                print("Successfully Logout")

            case .failure(let error):
                self.errorMessage = error.localizedDescription
                print("Sign Out Error: \(error.localizedDescription)")
            }
        }
    }
    
    // Toast Functions

    private func showSuccess(_ message: String) {
        toastMessage = message
        toastIsError = false
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }

    private func showError(_ message: String) {
        toastMessage = message
        toastIsError = true
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }
}

#Preview {
    VendorProfileView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(
            VendorAuthManager(
                viewContext: PersistenceController.preview.container.viewContext
            )
        )
}
