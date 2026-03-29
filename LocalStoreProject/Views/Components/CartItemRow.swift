//
//  CartItemRow.swift
//  LocalStoreProject
//
//  Created by Alvaro Limaymanta Soria on 2026-03-01.
//

import SwiftUI

struct CartItemRow: View {
    let item: CartItem
    let isUpdating: Bool
    let onUpdateQuantity: (Int32) -> Void
    
    @State private var localQuantity: Int32
    @State private var debounceWorkItem: DispatchWorkItem?
    
    init(item: CartItem, isUpdating: Bool, onUpdateQuantity: @escaping (Int32) -> Void) {
        self.item = item
        self.isUpdating = isUpdating
        self.onUpdateQuantity = onUpdateQuantity
        _localQuantity = State(initialValue: item.quantity)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            //image
            if let imageUrl = item.product?.imageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                .frame(width: 70, height: 70)
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
                    .cornerRadius(8)
            }
            
            //product Details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.product?.name ?? "Product")
                    .font(.headline)
                    .lineLimit(2)
                
                Text(item.product?.vendorName ?? "Vendor")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                HStack {
                    Text(item.product?.price ?? 0, format: .currency(code: "CAD"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.trailing)
                    
                    Spacer()
                    
                    //quantity buttons
                    HStack(spacing: 8) {
                        Button(action: {
                            if localQuantity > 1 && !isUpdating {
                                let newQuantity = localQuantity - 1
                                localQuantity = newQuantity
                                onUpdateQuantity(localQuantity)

                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .disabled(localQuantity <= 1 || isUpdating)
                        .buttonStyle(BorderlessButtonStyle()) // This prevents parent taps
                        
                        Text("\(localQuantity)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(minWidth: 30)
                        
                        Button(action: {
                            if localQuantity < (item.product?.stock ?? 0) && !isUpdating {
                                let newQuantity = localQuantity + 1
                                localQuantity = newQuantity
                                onUpdateQuantity(localQuantity)
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .disabled(localQuantity >= (item.product?.stock ?? 0) || isUpdating)
                        .buttonStyle(BorderlessButtonStyle()) // This prevents parent taps
                    }
                }
            }
            
            //total
            VStack(alignment: .trailing) {
                Text("Total:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text((item.product?.price ?? 0) * Double(localQuantity), format: .currency(code: "CAD"))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            .frame(minWidth: 70, alignment: .trailing)
            
        }
        .opacity(isUpdating ? 0.6 : 1.0)
        .onChange(of: item.quantity) { _, newValue in
            if newValue != localQuantity && !isUpdating {
                localQuantity = newValue
            }
        }
    }
}
