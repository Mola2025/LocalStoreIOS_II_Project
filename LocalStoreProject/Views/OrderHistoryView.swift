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
                if let user = authManager.currentUser {
                    orderHolder.setupForUser(user)
                    orderHolder.fetchOrdersFromFirestore { result in
                        switch result {
                        case .success:
                            break
                        case .failure(let error):
                            print("Error loading orders: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .sheet(item: $selectedOrder) { order in
                OrderDetailView(order: order)
                    .environmentObject(orderHolder)
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
            return "Your orders will appear here once you make a purchase"
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
        orderHolder.fetchOrdersFromFirestore { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                print("Error refreshing orders: \(error.localizedDescription)")
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
                
                Text(order.status?.capitalized ?? "Pending")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .cornerRadius(8)
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

struct OrderDetailView: View {
    let order: Order
    @EnvironmentObject private var orderHolder: OrderHolder
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Order Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Order Details")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text("Status:")
                                .font(.headline)
                            Text(order.status?.capitalized ?? "Pending")
                                .font(.headline)
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
                    
                    // Items
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
                    
                    // Total
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
                .padding()
            }
            .navigationTitle("Order #\(String(order.id?.uuidString.prefix(8) ?? ""))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct OrderItemRow: View {
    let item: OrderItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.productName ?? "Product")
                    .font(.headline)
                
                HStack {
                    Text("Qty: \(item.quantity)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if let vendorId = item.vendorId, !vendorId.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Vendor Name: \(String(vendorId.prefix(6)))")
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
