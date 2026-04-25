import SwiftUI

// MARK: - 1. PRZYCISK AKCJI (Szklany / Solidny)
struct ActionButton: View {
    @EnvironmentObject var data: AppData
    
    let title: String
    let icon: String
    let color: Color
    let isDisabled: Bool
    let action: () -> Void
    
    private var isDark: Bool { data.selectedTheme == .darkBlue }
    private var isWallpaperActive: Bool { data.selectedWallpaper != .none }
    
    private var buttonBg: Color { isDark ? Color(red: 30/255, green: 45/255, blue: 75/255) : .white }
    private var textColor: Color { isDark ? .white.opacity(0.9) : .black }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isDisabled ? .gray.opacity(0.3) : color)
                
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(isDisabled ? .gray.opacity(0.4) : textColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(
                ZStack {
                    if isWallpaperActive {
                        // EFEKT SZKŁA
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, isDark ? .dark : .light)
                    } else {
                        buttonBg
                    }
                }
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isDark ? Color.white.opacity(0.15) : Color.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: isWallpaperActive ? .clear : Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .disabled(isDisabled)
    }
}

// MARK: - 2. GŁÓWNA KARTA POJAZDU (Glassmorphism Edition)
struct HeroCardView: View {
    @EnvironmentObject var data: AppData
    let car: Car
    let totalCost: Double
    let logs: [LogEntry]
    var onCostTap: () -> Void
    var onOdometerTap: () -> Void
    
    private var isDark: Bool { data.selectedTheme == .darkBlue }
    private var isWallpaperActive: Bool { data.selectedWallpaper != .none }
    private var currency: String { data.selectedUnitSystem == .imperial ? "$" : "zł" }
    private var distUnit: String { data.selectedUnitSystem == .imperial ? "mi" : "km" }

    private var brandName: String { car.name.components(separatedBy: " ").first ?? car.name }
    private var modelSuffix: String {
        let parts = car.name.components(separatedBy: " ")
        return parts.count > 1 ? parts.dropFirst().joined(separator: " ") : ""
    }
    
    // MARK: - HELPERS (Scope Safety)
    private var driveTypeColor: Color {
        switch car.type {
        case .petrol: return .orange
        case .diesel: return isDark ? Color(white: 0.8) : Color(white: 0.2)
        case .electric: return .green
        case .phev, .phevDiesel: return .blue
        }
    }
    
    private var driveTypeTitle: String {
        switch car.type {
        case .petrol: return "BENZYNA"
        case .diesel: return "DIESEL"
        case .electric: return "ELEKTRYK"
        case .phev: return "PHEV"
        case .phevDiesel: return "PHEV (DIESEL)"
        }
    }

    private var iconForType: String {
        switch car.type {
        case .electric: return "bolt.fill"
        case .phev, .phevDiesel: return "leaf.fill"
        default: return "drop.fill"
        }
    }
    
    var lastOdometer: String {
        let sorted = logs.compactMap { $0.odometer }.sorted()
        return sorted.last != nil ? "\(sorted.last!) \(distUnit)" : "— \(distUnit)"
    }

    // MARK: - BODY
    var body: some View {
        ZStack(alignment: .leading) {
            
            // --- 1. TŁO SZKLANE (IDEALNIE DOPASOWANE) ---
            if isWallpaperActive {
                RoundedRectangle(cornerRadius: 28)
                    // EKSTREMALNA PRZEZROCZYSTOŚĆ (0.35 opacity materiału)
                    .fill(.ultraThinMaterial.opacity(0.35))
                    .environment(\.colorScheme, isDark ? .dark : .light)
                    // Połysk krawędzi wewnątrz szkła
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(isDark ? Color.white.opacity(0.02) : Color.white.opacity(0.15))
                            .blendMode(.overlay)
                    )
            } else {
                RoundedRectangle(cornerRadius: 28)
                    .fill(isDark ? Color(red: 20/255, green: 30/255, blue: 50/255) : .white)
            }
            
            // --- 2. SUBTELNY BLIK (PŁYNNY GLOSS) ---
            if isWallpaperActive {
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .white.opacity(isDark ? 0.08 : 0.35),
                                .clear,
                                .white.opacity(isDark ? 0.01 : 0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // --- 3. TREŚĆ ---
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(driveTypeTitle)
                            .font(.system(size: 8, weight: .black))
                            .tracking(2.0)
                            .foregroundColor(driveTypeColor)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(driveTypeColor.opacity(0.12))
                            .cornerRadius(4)
                        
                        Text(brandName)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(isDark ? .white : .black)
                        
                        if !modelSuffix.isEmpty {
                            Text(modelSuffix)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isDark ? .white.opacity(0.7) : .gray)
                        }

                        if !car.licensePlate.isEmpty {
                            Text(car.licensePlate.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(isDark ? .white : .black)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 6).fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.08), lineWidth: 0.5))
                                .padding(.top, 4)
                        }
                    }
                    Spacer()
                    
                    if let imageData = car.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFit().frame(width: 120, height: 80).cornerRadius(10)
                            .shadow(color: .black.opacity(isDark ? 0.3 : 0.05), radius: 5)
                    }
                }
                .padding(.horizontal, 25).padding(.top, 25)
                
                Spacer(minLength: 24)
                
                Divider()
                    .background(isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.04))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("KOSZT ŁĄCZNY").font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
                        Text(String(format: "%.0f %@", totalCost, currency))
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(Color(red: 50/255, green: 215/255, blue: 110/255))
                            .shadow(color: Color(red: 50/255, green: 215/255, blue: 110/255).opacity(0.25), radius: 10)
                    }
                    .onTapGesture { onCostTap() }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("LICZNIK").font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
                        Text(lastOdometer)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isDark ? .white : .black)
                    }
                    .onTapGesture { onOdometerTap() }
                }
                .padding(.horizontal, 25).padding(.bottom, 16)
            }
        }
        .frame(height: 190)
        // GWARANCJA DOPASOWANIA: Docinamy wszystko do obrysu szkła
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            // --- NAJCIEŃSZY RANT ŚWIATA (0.5 pkt) ---
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .white.opacity(isDark ? 0.3 : 0.8),
                            .clear,
                            .white.opacity(isDark ? 0.05 : 0.15)
                        ]),
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        // Cień rzucany przez całą strukturę (nieprostokątny!)
        .shadow(color: Color.black.opacity(isDark ? 0.4 : 0.08), radius: 20, x: 0, y: 15)
        .padding(.horizontal)
    }
}
// MARK: - 3. WIERSZ HISTORII (Dopasowany do regionu)
struct LogRowView: View {
    @EnvironmentObject var data: AppData
    let log: LogEntry
    
    private var isDark: Bool { data.selectedTheme == .darkBlue }
    private var currency: String { data.selectedUnitSystem == .imperial ? "$" : "zł" }

    private var fuelInfo: (name: String, color: Color) {
        let type = log.fuelType ?? .pb95
        let label = type.label(for: data.selectedUnitSystem).uppercased()
        
        switch type {
        case .pb95: return (label, Color(red: 255/255, green: 190/255, blue: 0/255))
        case .pb98: return (label, .red)
        case .diesel: return (label, isDark ? Color(white: 0.85) : Color(white: 0.15))
        case .lpg: return (label, .blue)
        case .electricity: return ("EV", .green)
        case .adblue: return (label, .cyan)
        }
    }

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle().fill(fuelInfo.color.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: log.type == .charge ? "bolt.fill" : "fuelpump.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(fuelInfo.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(fuelInfo.name)
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(fuelInfo.color.opacity(isDark && log.fuelType == .diesel ? 0.4 : 0.1))
                        .foregroundColor(fuelInfo.color).cornerRadius(4)
                    
                    Text(log.date, style: .date)
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.gray)
                }
                
                if let odo = log.odometer {
                    Text("\(odo) \(data.selectedUnitSystem == .imperial ? "mi" : "km")")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isDark ? .white : .black)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f %@", log.totalCost, currency))
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(isDark ? .white : .black)
                
                Text(String(format: "%.2f %@", log.amount, log.fuelType?.unit(for: data.selectedUnitSystem) ?? "L"))
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }
}

// MARK: - 4. MINI KARTA STATYSTYK (Szklana)
struct MiniStatCard: View {
    @EnvironmentObject var data: AppData
    let title: String, value: String, unit: String, icon: String, color: Color
    
    private var isDark: Bool { data.selectedTheme == .darkBlue }
    private var isWallpaperActive: Bool { data.selectedWallpaper != .none }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(color).font(.system(size: 14))
                Text(title).font(.system(size: 10, weight: .medium)).foregroundColor(.gray).lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(isDark ? .white : .black)
                Text(unit).font(.system(size: 10, weight: .medium)).foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(
            ZStack {
                if isWallpaperActive {
                    Rectangle().fill(.ultraThinMaterial)
                        .environment(\.colorScheme, isDark ? .dark : .light)
                } else {
                    (isDark ? Color(red: 25/255, green: 40/255, blue: 70/255) : .white)
                }
            }
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.03), radius: 6, x: 0, y: 3)
    }
}

// MARK: - 5. PRZYCISK WYBORU NAPĘDU
struct TypeSelectButton: View {
    let title: String, icon: String, type: CarDriveType
    @Binding var selectedType: CarDriveType
    let color: Color, isDark: Bool
    
    var isSelected: Bool { selectedType == type }
    
    var body: some View {
        Button(action: { selectedType = type }) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 16, weight: .bold))
                Text(title).font(.system(size: 10, weight: .bold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(isSelected ? color : (isDark ? Color.white.opacity(0.05) : Color.gray.opacity(0.1)))
            .foregroundColor(isSelected ? .white : (isDark ? .white.opacity(0.6) : .gray))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? color : Color.clear, lineWidth: 2))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
