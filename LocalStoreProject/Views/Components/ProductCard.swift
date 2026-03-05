//
//  ProductCard.swift
//  IOS_Midterm_Assigment_3
//
//  Created by David Molano on 2026-02-03.
//

import SDWebImageSwiftUI
import SwiftUI

struct ProductCard: View {

    @ObservedObject var product: Product

    var body: some View {
        VStack(alignment: .leading) {

            if let imageURL = product.imageUrl, !imageURL.isEmpty {
                WebImage(url: URL(string: imageURL))
                    .resizable()
                    .scaledToFill()
                    .frame(height: 130)
                    .clipped()
                    .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 130)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
                    .cornerRadius(12)
            }

            VStack(alignment: .leading) {
                
                Text(product.displayName)
                    .font(.headline)

                Text(product.price, format: .currency(code: "CAD"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)

                // Stock Badge
                HStack {
                    Image(
                        systemName: product.isOnStock
                            ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundColor(product.isOnStock ? .green : .red)
                    .font(.caption)

                    Text(product.stockStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            product.isOnStock
                                ? Color.green.opacity(0.1)
                                : Color.red.opacity(0.1)
                        )
                )
            }
            .padding(.horizontal, 4)
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
