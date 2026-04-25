//
//  dziennikpokladowyApp.swift
//  dziennikpokladowy
//
//  Created by Grzegorz Nowak on 05/04/2026.
//

import SwiftUI

@main
struct Xenergi: App {
    // 1. Tworzymy główny kontener danych jako @StateObject.
    // To gwarantuje, że dane żyją tak długo, jak cała aplikacja.
    @StateObject private var data = AppData()
    
    var body: some Scene {
        WindowGroup {
            // 2. Wstrzykujemy obiekt 'data' do drzewa widoków.
            // Każdy widok wewnątrz (ContentView, Settings, etc.) może teraz
            // użyć @EnvironmentObject var data: AppData
            ContentView()
                .environmentObject(data)
        }
    }
}
