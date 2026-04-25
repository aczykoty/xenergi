import SwiftUI
import UniformTypeIdentifiers
import Combine

struct BackupService {
    
    // MARK: - Generowanie Kopii (Eksport)
    static func generateBackup(data: AppData) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let storage = AppData.StorageData(
            cars: data.cars,
            logs: data.logs,
            selectedTheme: data.selectedTheme
        )
        
        do {
            let jsonData = try encoder.encode(storage)
            
            // 1. Tworzymy formatowanie daty
            let formatter = DateFormatter()
            formatter.dateFormat = "dd_MM_yyyy"
            let dateString = formatter.string(from: Date())
            
            // 2. Składamy nową nazwę pliku
            let fileName = "xenergi_backup_\(dateString).json"
            
            // 3. Tworzymy ścieżkę do pliku
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try jsonData.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            print("❌ Błąd zapisu pliku eksportu: \(error)")
            return nil
        }
    }
    
    // MARK: - Przywracanie Kopii (Import z Natychmiastowym Odświeżeniem)
    static func restoreBackup(from url: URL, to appData: AppData) -> Bool {
        do {
            // Uzyskanie dostępu do pliku wybranego przez użytkownika
            guard url.startAccessingSecurityScopedResource() else { return false }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let jsonData = try Data(contentsOf: url)
            let decodedData = try JSONDecoder().decode(AppData.StorageData.self, from: jsonData)
            
            // Wszystkie zmiany UI muszą dziać się na głównym wątku
            DispatchQueue.main.async {
                // !!! KLUCZOWY MOMENT !!!
                // Informujemy SwiftUI, że cały obiekt AppData zaraz się zmieni.
                // To wymusza odświeżenie ContentView i wszystkich podwidoków natychmiast.
                appData.objectWillChange.send()
                
                appData.cars = decodedData.cars
                appData.logs = decodedData.logs
                appData.selectedTheme = decodedData.selectedTheme
                
                print("✅ Import zakończony pomyślnie. Widoki odświeżone.")
            }
            return true
        } catch {
            print("❌ Błąd podczas importowania pliku: \(error)")
            return false
        }
    }
}

// MARK: - Pomocniczy ShareSheet (używany jeśli wywołujesz przez .sheet)
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
