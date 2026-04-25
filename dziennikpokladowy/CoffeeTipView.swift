import SwiftUI
import StoreKit
import UIKit

struct CoffeeTipView: View {
    @StateObject var store = CoffeeStore()
    @Environment(\.dismiss) var dismiss
    @State private var showSuccess = false
    let isDark: Bool
    
    private var bgColor: Color { isDark ? Color(red: 10/255, green: 20/255, blue: 40/255) : Color(red: 245/255, green: 245/255, blue: 247/255) }
    private var cardColor: Color { isDark ? Color(red: 20/255, green: 35/255, blue: 60/255) : .white }
    private var textColor: Color { isDark ? .white : .primary }

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                
                if showSuccess {
                    successView
                } else {
                    mainView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }.foregroundColor(.gray)
                }
            }
        }
    }
    
    private var mainView: some View {
        VStack(spacing: 25) {
            VStack(spacing: 15) {
                Text("☕️")
                    .font(.system(size: 80))
                    .shadow(radius: 10)
                
                Text("Postaw mi kawę")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(textColor)
                
                Text("Twoje wsparcie pozwala mi rozwijać aplikację i dodawać nowe funkcje. Każda kawa to potężna dawka motywacji!")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 20)

            if store.products.isEmpty {
                ProgressView().tint(.blue).padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(store.products) { product in
                        Button(action: {
                            Task {
                                let success = await store.buy(product)
                                if success {
                                    withAnimation(.spring()) { showSuccess = true }
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                }
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.displayName)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(textColor)
                                    Text(product.description)
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text(product.displayPrice)
                                    .font(.system(size: 14, weight: .black))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding()
                            .background(cardColor)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.05), radius: 10, y: 5)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                    }
                }
            }
            
            Spacer()
            
            Text("Płatność realizowana przez Apple App Store.\nMożesz zrezygnować w dowolnym momencie.")
                .font(.system(size: 10))
                .foregroundColor(.gray.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)
        }
    }
    
    private var successView: some View {
        VStack(spacing: 20) {
            Text("🎉").font(.system(size: 100))
            Text("DZIĘKUJĘ!").font(.system(size: 30, weight: .black)).foregroundColor(textColor)
            Text("Twoja kawa właśnie została „wypita”.\nEnergia do kodowania: 100%!")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            
            Button("Wróć do Garażu") { dismiss() }
                .font(.headline)
                .foregroundColor(.blue)
                .padding(.top, 20)
        }
    }
}
