import Foundation
import SwiftUI
import Combine

class AppData: ObservableObject {
    // MARK: - Dane Published
    @Published var cars: [Car] = []
    @Published var logs: [LogEntry] = []
    @Published var selectedTheme: AppTheme = .darkBlue
    
    // --- NOWE POLA ---
    @Published var selectedWallpaper: WallpaperTheme = .none
    @Published var selectedUnitSystem: UnitSystem = .metric
    
    private var cancellables = Set<AnyCancellable>()
    private var isInitialLoading = true

    // MARK: - Ścieżka zapisu
    private var savePath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DziennikData.json")
    }
    
    init() {
        loadFromDisk()
        setupAutoSave()
    }
    
    // MARK: - Automatyczny Zapis
    private func setupAutoSave() {
        objectWillChange
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveToDisk()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Struktura JSON
    // Dodajemy nowe pola tutaj, aby Codable wiedział, jak je zapisać
    struct StorageData: Codable {
        var cars: [Car]
        var logs: [LogEntry]
        var selectedTheme: AppTheme
        // Ustawiamy jako opcjonalne (?), żeby stare pliki zapisu nadal działały
        var selectedWallpaper: WallpaperTheme?
        var selectedUnitSystem: UnitSystem?
    }
    
    // MARK: - Zapis na dysk
    func saveToDisk() {
        guard !isInitialLoading else { return }
        
        do {
            let storage = StorageData(
                cars: cars,
                logs: logs,
                selectedTheme: selectedTheme,
                selectedWallpaper: selectedWallpaper,
                selectedUnitSystem: selectedUnitSystem
            )
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(storage)
            try data.write(to: savePath, options: [.atomic, .completeFileProtection])
            print("✅ Dane zapisane: Motyw: \(selectedTheme), Tapeta: \(selectedWallpaper), System: \(selectedUnitSystem)")
        } catch {
            print("❌ Błąd zapisu: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Odczyt z dysku
    private func loadFromDisk() {
        let path = savePath.path
        guard FileManager.default.fileExists(atPath: path) else {
            isInitialLoading = false
            return
        }
        
        do {
            let data = try Data(contentsOf: savePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let storage = try decoder.decode(StorageData.self, from: data)
            
            self.cars = storage.cars
            self.logs = storage.logs
            self.selectedTheme = storage.selectedTheme
            
            // Jeśli w pliku nie ma nowych pól (stara wersja apki), użyj domyślnych
            self.selectedWallpaper = storage.selectedWallpaper ?? .none
            self.selectedUnitSystem = storage.selectedUnitSystem ?? .metric
            
            print("📖 Dane wczytane pomyślnie")
            
        } catch {
            // Jeśli struktura JSON się całkiem zmieniła i nie można jej odczytać
            print("⚠️ Błąd odczytu: Struktura danych mogła ulec zmianie. Używam domyślnych.")
        }
        
        self.isInitialLoading = false
    }
}
