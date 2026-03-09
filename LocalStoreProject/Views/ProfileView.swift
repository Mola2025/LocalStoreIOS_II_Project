//
//  ProfileView.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-07.
//

import CoreData
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SDWebImageSwiftUI
import SwiftUI

struct ProfileView: View {

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.managedObjectContext) private var viewContext

    @State private var currentUser: User? = nil
    @State private var errorMessage: String? = nil

    // For the address
    @State private var showAddressPicker = false

    // For the Toast
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Header
                    if let user = currentUser {
                        VStack(spacing: 20) {
                            HStack(alignment: .top, spacing: 16) {

                                WebImage(
                                    url: URL(string: user.profileImageURL ?? "")
                                )
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(user.displayName)
                                        .font(.system(size: 26))
                                        .bold()
                                    Text(user.email ?? "No email")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal)
                            }
                            .padding(.top, 4)

                            Divider()
                        }

                        // Buttons

                        HStack(spacing: 12) {

                            NavigationLink(destination: EditProfileView()) {
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

                        VStack(alignment: .leading, spacing: 12) {
                            Text("My Location")
                                .font(.title2)
                                .bold()
                                .padding(.horizontal)

                            if let address = user.address,
                                address.hasValidCoordinates
                            {
                                AddressMiniMapView(
                                    coordinate: address.coordinate,
                                    addressText: address.displayAddress,
                                    onEditTapped: {
                                        showAddressPicker = true
                                    }
                                )
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "mappin.slash")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("No Location Registered")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text(
                                        "Add your location so vendors can find you"
                                    )
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)

                                    Button {
                                        showAddressPicker = true
                                    } label: {
                                        Label(
                                            "Add My Location",
                                            systemImage: "plus"
                                        )
                                        .frame(maxWidth: .infinity)
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
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadUser()
            }
            .sheet(isPresented: $showAddressPicker) {
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
                    initialCoordinate: currentUser?.address?.coordinate
                )
            }
            .toast(
                isPresented: $showToast,
                message: toastMessage,
                isError: toastIsError
            )
        }
    }

    private func loadUser() {
        if let user = authManager.currentUser {
            self.currentUser = user
        }
    }

    private func signOut() {
        authManager.signOut { result in
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

    private func saveAddress(
        lat: Double,
        lon: Double,
        city: String,
        street: String
    ) {
        guard let user = currentUser else { return }

        let manager = AddressManager(viewContext: viewContext)
        manager
            .saveAddressForUser(
                user: user,
                latitude: lat,
                longitude: lon,
                city: city,
                street: street
            ) {
                result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.loadUser()
                        self.showSuccess("Location Saved Successfully")
                    case .failure(let error):
                        self.showError(
                            "Error saving location: \(error.localizedDescription)"
                        )
                    }
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
    ProfileView()
        .environment(
            \.managedObjectContext,
            PersistenceController.preview.container.viewContext
        )
        .environmentObject(
            AuthManager(
                viewContext: PersistenceController.preview.container.viewContext
            )
        )
}
