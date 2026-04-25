import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var data: AppData
    @Environment(\.dismiss) var dismiss
    
    @State private var showingFileImporter = false
    @State private var showingCoffeeShop = false
    @State private var importError = false
    
    // MARK: - Helpers dla motywu
    private var isDark: Bool { data.selectedTheme == .darkBlue }
    
    private var backgroundColor: Color {
        isDark ? Color(red: 10/255, green: 18/255, blue: 30/255) : Color(UIColor.systemGroupedBackground)
    }
    
    private var rowColor: Color {
        isDark ? Color(red: 20/255, green: 35/255, blue: 60/255) : .white
    }
    
    private var textColor: Color { isDark ? .white : .primary }
    private var headerColor: Color { isDark ? .gray : .secondary }
    
    var body: some View {
        NavigationView {
            List {
                // MARK: 1. WYGLĄD I MOTYW
                Section(header: Text("Wygląd").foregroundColor(headerColor)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Motyw aplikacji").font(.subheadline).foregroundColor(headerColor)
                        Picker("Motyw aplikacji", selection: $data.selectedTheme) {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(rowColor)

                // MARK: 2. GALERIA TAPET (NOWOŚĆ)
                Section(header: Text("Tapeta tła").foregroundColor(headerColor)) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(WallpaperTheme.allCases, id: \.self) { wallpaper in
                                VStack(spacing: 8) {
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            data.selectedWallpaper = wallpaper
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }) {
                                        if wallpaper == .none {
                                            // Podgląd standardowego gradientu
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(LinearGradient(
                                                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.black]),
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ))
                                                .frame(width: 80, height: 130)
                                                .overlay(
                                                    Image(systemName: "slash.circle")
                                                        .foregroundColor(.white.opacity(0.4))
                                                )
                                        } else {
                                            // Podgląd obrazka z Assets
                                            Image(wallpaper.rawValue)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 80, height: 130)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(data.selectedWallpaper == wallpaper ? Color.orange : Color.clear, lineWidth: 3)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                                    Text(wallpaper.displayName)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(textColor)
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 5)
                    }
                }
                .listRowBackground(rowColor)

                // MARK: 3. SYSTEM MIAR (USA vs EU)
                Section(header: Text("Region i jednostki").foregroundColor(headerColor),
                        footer: Text("Zmienia jednostki (L/Gal) oraz nazewnictwo paliw (RON/AKI).")) {
                    Picker("System miar", selection: $data.selectedUnitSystem) {
                        ForEach(UnitSystem.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.menu) // Menu wygląda lepiej przy długich nazwach systemów
                    .foregroundColor(textColor)
                }
                .listRowBackground(rowColor)

                // MARK: 4. DANE
                Section(header: Text("Zarządzanie danymi").foregroundColor(headerColor)) {
                    Button(action: { exportBackup() }) {
                        Label("Eksportuj kopię (.json)", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { showingFileImporter = true }) {
                        Label("Importuj kopię (.json)", systemImage: "square.and.arrow.down")
                            .foregroundColor(.orange)
                    }
                }
                .listRowBackground(rowColor)

                // MARK: 5. INFORMACJE
                Section(header: Text("O aplikacji").foregroundColor(headerColor)) {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Image("AppLogo") // Upewnij się, że logo jest w Assets
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 50)
                            
                            Text("Wersja 1.0.7")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .listRowSeparator(.hidden)

                    VStack(alignment: .center, spacing: 4) {
                        HStack {
                            Spacer()
                            Text("Created by Grzegorz Nowak")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textColor)
                            Spacer()
                        }
                        HStack(spacing: 4) {
                            Spacer()
                            Text("Proudly made in EU")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Text("🇪🇺")
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Ustawienia")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(backgroundColor.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundColor(isDark ? .white : .blue)
                }
            }
            // Handlery importera i alerty (bez zmian)
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert("Błąd importu", isPresented: $importError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Nie udało się wczytać pliku. Sprawdź czy format jest poprawny.")
            }
        }
    }

    // MARK: - LOGIKA POMOCNICZA
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                let success = BackupService.restoreBackup(from: url, to: data)
                if !success { importError = true }
            }
        case .failure:
            importError = true
        }
    }

    private func exportBackup() {
        guard let url = BackupService.generateBackup(data: data) else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            var presenter = rootVC
            while let next = presenter.presentedViewController { presenter = next }
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            presenter.present(activityVC, animated: true)
        }
    }
}
