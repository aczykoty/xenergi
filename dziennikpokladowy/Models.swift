import Foundation
import SwiftUI

// MARK: - ENUMY KONFIGURACYJNE

enum AppTheme: String, Codable, CaseIterable {
    case light = "Jasny"
    case darkBlue = "Dark Blue"
}

// NOWOŚĆ: Zarządzanie tapetami lokalnymi
enum WallpaperTheme: String, Codable, CaseIterable {
    case none = "none"
    case deepSpace = "bg_01"
    case neonCity = "bg_02"
    case carbonFiber = "bg_03"
    
    var displayName: String {
        switch self {
        case .none: return "Gradient"
        case .deepSpace: return "Głęboki Kosmos"
        case .neonCity: return "Neonowe Miasto"
        case .carbonFiber: return "Karbon"
        }
    }
}

// NOWOŚĆ: Systemy miar (USA vs Europa)
enum UnitSystem: String, Codable, CaseIterable {
    case metric = "Metryczny (L, km)"
    case imperial = "Imperialny (Gal, mi)"
}

// MARK: - ENUMY PALIWA

enum EntryType: String, Codable, Identifiable {
    case fuel = "fuel"
    case charge = "charge"
    var id: String { rawValue }
}

enum FuelType: String, Codable, CaseIterable {
    case pb95 = "Pb95", pb98 = "Pb98", diesel = "Diesel", lpg = "LPG", adblue = "AdBlue", electricity = "Prąd"
    
    // Logika nazewnictwa dla USA (AKI) vs Europa (RON)
    func label(for system: UnitSystem) -> String {
        switch self {
        case .pb95: return system == .imperial ? "87 Regular" : "Pb95"
        case .pb98: return system == .imperial ? "91-93 Premium" : "Pb98"
        case .electricity: return "Prąd"
        default: return self.rawValue
        }
    }
    
    func unit(for system: UnitSystem) -> String {
        if self == .electricity { return "kWh" }
        return system == .imperial ? "gal" : "L"
    }
    
    var icon: String { self == .electricity ? "bolt.fill" : "drop.fill" }
    
    var color: Color {
        switch self {
        case .pb95: return Color(red: 255/255, green: 190/255, blue: 0/255)
        case .pb98: return .red
        case .diesel: return .primary
        case .lpg: return .blue
        case .adblue: return .cyan
        case .electricity: return .green
        }
    }
}

enum CarDriveType: String, Codable, CaseIterable {
    case petrol = "Benzyna"
    case diesel = "Diesel"
    case phev = "PHEV (PB)"
    case phevDiesel = "PHEV (Diesel)"
    case electric = "Elektryk"
}

// MARK: - MODELE DANYCH

struct Car: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: CarDriveType
    var primaryFuel: FuelType
    var secondaryFuel: FuelType?
    var licensePlate: String
    var imageData: Data?
}

struct LogEntry: Identifiable, Codable {
    var id = UUID()
    var carId: UUID
    var type: EntryType
    var fuelType: FuelType?
    var amount: Double
    var pricePerUnit: Double
    var odometer: Int?
    var date: Date
    
    // --- POLA DLA BATERII ---
    var startSoC: Double?
    var endSoC: Double?
    
    // --- METRYKI ---
    var totalCost: Double { amount * pricePerUnit }
}
