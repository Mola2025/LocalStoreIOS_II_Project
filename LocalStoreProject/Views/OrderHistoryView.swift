//
//  OrderHistoryView.swift
//  LocalStoreProject
//
//  Created by Alvaro Limaymanta Soria on 2026-03-01.
//

import SwiftUI

struct OrderHistoryView: View {
    @EnvironmentObject private var orderHolder: OrderHolder
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var vendorAuthManager: VendorAuthManager
    @State private var selectedOrder: Order?
    @State private var showFilterMenu = false
    @State private var filterOption: FilterOption = .all
    
    enum FilterOption {
        case all, active, completed
        
        var title: String {
            switch self {
            case .all: return "All Orders"
            case .active: return "Active"
            case .completed: return "Completed"
            }
        }
    }
    
    var filteredOrders: [Order] {
        switch filterOption {
        case .all:
            return orderHolder.orders
        case .active:
            return orderHolder.activeOrders
        case .completed:
            return orderHolder.completedOrders
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Picker
                Picker("Filter", selection: $filterOption) {
                    Text("All").tag(FilterOption.all)
                    Text("Active").tag(FilterOption.active)
                    Text("Completed").tag(FilterOption.completed)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                Group {
                    if filteredOrders.isEmpty {
                        emptyStateView
                    } else {
                        ordersList
                    }
                }
            }
            .navigationTitle("Order History")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let vendor = vendorAuthManager.currentVendor {
                    orderHolder.setupForVendor(vendor)
                    orderHolder.fetchVendorOrdersFromFirestore { result in
                        switch result {
                        case .success:
                            break
                        case .failure(let error):
                            print("Error loading vendor orders: \(error.localizedDescription)")
                        }
                    }
                } else if let user = authManager.currentUser {
                    orderHolder.setupForUser(user)
                    orderHolder.fetchUsersOrdersFromFirestore { result in
                        switch result {
                        case .success:
                            break
                        case .failure(let error):
                            print("Error loading user orders: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .sheet(item: $selectedOrder) { order in
                OrderDetailView(order: order)
                    .environmentObject(orderHolder)
                    .environmentObject(vendorAuthManager)
                    .environmentObject(authManager)
            }
            .refreshable {
                refreshOrders()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(emptyStateTitle)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateTitle: String {
        if orderHolder.orders.isEmpty {
            return "No orders yet"
        } else {
            switch filterOption {
            case .all:
                return "No orders"
            case .active:
                return "No active orders"
            case .completed:
                return "No completed orders"
            }
        }
    }
    
    private var emptyStateMessage: String {
        if orderHolder.orders.isEmpty {
            if vendorAuthManager.currentVendor != nil {
                return "Customer orders for your products will appear here"
            } else {
                return "Your orders will appear here once you make a purchase"
            }
        } else {
            switch filterOption {
            case .all:
                return "You have no orders"
            case .active:
                return "You don't have any active orders"
            case .completed:
                return "You haven't completed any orders yet"
            }
        }
    }
    
    private var ordersList: some View {
        List {
            ForEach(filteredOrders, id: \.id) { order in
                OrderRowView(order: order)
                    .onTapGesture {
                        selectedOrder = order
                    }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func refreshOrders() {
        if vendorAuthManager.currentVendor != nil {
            orderHolder.fetchVendorOrdersFromFirestore { result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    print("Error refreshing vendor orders: \(error.localizedDescription)")
                }
            }
        } else if authManager.currentUser != nil {
            orderHolder.fetchUsersOrdersFromFirestore { result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    print("Error refreshing user orders: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct OrderRowView: View {
    let order: Order
    @EnvironmentObject private var orderHolder: OrderHolder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Order #\(String(order.id?.uuidString.prefix(8) ?? ""))")
                    .font(.headline)
                
                Spacer()
                
                StatusBadge(status: order.status ?? "pending")
            }
            
            // Date
            Text(orderHolder.formattedDate(order))
                .font(.caption)
                .foregroundColor(.gray)
            
            // Items preview
            let items = orderHolder.items(for: order)
            if let firstItem = items.first {
                HStack {
                    Text(firstItem.productName ?? "Product")
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    if items.count > 1 {
                        Text("+\(items.count - 1) more")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Total
            HStack {
                Text("Total:")
                    .font(.subheadline)
                
                Text(order.total, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("\(orderHolder.items(for: order).count) items")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: String
    
    private var colour: Color {
        switch status.lowercased() {
        case "delivered":  return .green
        case "cancelled":  return .red
        case "processing": return .orange
        default:           return .gray   // pending
        }
    }
    
    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colour.opacity(0.15))
            .foregroundColor(colour)
            .cornerRadius(8)
    }
}

// MARK: - OrderDetailView
 
struct OrderDetailView: View {
    let order: Order
    @EnvironmentObject private var orderHolder: OrderHolder
    @EnvironmentObject private var vendorAuthManager: VendorAuthManager
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var currentStatus: String = ""
    @State private var isUpdating = false
    @State private var updateError: String?
    @State private var showConfirmation: Bool = false
    @State private var pendingNewStatus: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    orderHeaderSection
                    itemsSection
                    totalSection
                    
                    if vendorCanActOnOrder {
                        vendorActionSection
                    }
                }
                .padding()
            }
            .navigationTitle("Order #\(String(order.id?.uuidString.prefix(8) ?? ""))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Confirm action", isPresented: $showConfirmation) {
                Button("Confirm", role: .destructive) {
                    commitStatusUpdate(to: pendingNewStatus)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                let verb = pendingNewStatus == "delivered" ? "mark as Delivered" : "Cancel"
                Text("Are you sure you want to \(verb) this order?")
            }
            .safeAreaInset(edge: .bottom) {
                if let errorMsg = updateError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMsg)
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                        Button { updateError = nil } label: {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemRed).opacity(0.08))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
        .onAppear {
            currentStatus = order.status ?? "pending"
        }
    }
    
    // MARK: - Sub-sections
    
    private var orderHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Order Details")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                Text("Status:")
                    .font(.headline)
                StatusBadge(status: currentStatus)
            }
            
            HStack {
                Text("Order Date:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(orderHolder.formattedDate(order))
                    .font(.subheadline)
            }
            
            HStack {
                Text("Order ID:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(order.id?.uuidString ?? "")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items")
                .font(.title2)
                .fontWeight(.bold)
            
            let items = orderHolder.items(for: order)
            ForEach(items, id: \.id) { item in
                OrderItemRow(item: item)
                
                if item.id != items.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var totalSection: some View {
        HStack {
            Text("Total Amount:")
                .font(.title3)
                .fontWeight(.bold)
            Spacer()
            Text(order.total, format: .currency(code: "USD"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var vendorActionSection: some View {
        VStack(spacing: 12) {
            Text("Update Order Status")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Button {
                    pendingNewStatus = "delivered"
                    showConfirmation = true
                } label: {
                    Label("Mark Delivered", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isUpdating)
                
                Button {
                    pendingNewStatus = "cancelled"
                    showConfirmation = true
                } label: {
                    Label("Cancel Order", systemImage: "xmark.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isUpdating)
            }
            
            if isUpdating {
                ProgressView("Updating…")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    // MARK: - Helpers
    
    // Check if there is an product from the current vendor in the order
    private var vendorCanActOnOrder: Bool {
        guard let vendor = vendorAuthManager.currentVendor,
              let vendorFirebaseUUID = vendor.firebaseUUID else { return false }
        
        let isTerminal = currentStatus == "delivered" || currentStatus == "cancelled"
        guard !isTerminal else { return false }
        
        let items = orderHolder.items(for: order)
        return items.contains { $0.vendorId == vendorFirebaseUUID }
    }
    
    private func commitStatusUpdate(to newStatus: String) {
        guard let vendor = vendorAuthManager.currentVendor,
              let vendorFirebaseUUID = vendor.firebaseUUID else { return }
        
        isUpdating = true
        updateError = nil
        
        Task {
            do {
                try await orderHolder.updateOrderStatus(
                    order: order,
                    newStatus: newStatus,
                    vendorFirebaseUUID: vendorFirebaseUUID
                )
                await MainActor.run {
                    currentStatus = newStatus
                    isUpdating = false
                }
            } catch {
                await MainActor.run {
                    updateError = error.localizedDescription
                    isUpdating = false
                }
            }
        }
    }
}

struct OrderItemRow: View {
    @EnvironmentObject private var vendorAuthManager: VendorAuthManager
    @EnvironmentObject private var authManager: AuthManager

    let item: OrderItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.productName ?? "Product")
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Text("Qty: \(item.quantity)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if authManager.currentUser != nil,
                       let vendorName = item.vendorName,
                       !vendorName.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("Sold by: \(vendorName)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    else if vendorAuthManager.currentVendor != nil,
                            let userName = item.userName,
                            !userName.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("Ordered by: \(userName)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            Text(item.productPrice * Double(item.quantity), format: .currency(code: "CAD"))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}
