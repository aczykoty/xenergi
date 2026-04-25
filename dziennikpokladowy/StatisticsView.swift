import SwiftUI
import Charts

// MARK: - 1. MODEL DANYCH
struct FuelStat: Identifiable {
    let id = UUID()
    let date: String
    let value: Double
    let type: String
}

struct StatisticsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var data: AppData
    
    let car: Car
    let logs: [LogEntry]
    
    // KOLORYSTYKA (Zmieniłem na słownik, jest lżejszy dla kompilatora)
    private let fuelColors: [String: Color] = [
        "PB95": Color(red: 255/255, green: 190/255, blue: 0/255),
        "PB98": Color.red,
        "Diesel": Color(white: 0.15),
        "LPG": Color.blue,
        "Prąd": Color.green,
        "AdBlue": Color.cyan
    ]
    
    private var isDark: Bool { data.selectedTheme == .darkBlue }
    private var bgColor: Color { isDark ? Color(red: 10/255, green: 20/255, blue: 40/255) : Color(red: 235/255, green: 235/255, blue: 240/255) }
    private var cardColor: Color { isDark ? Color.white.opacity(0.06) : .white }
    private var primaryText: Color { isDark ? .white : .black }

    // --- PRE-OBLICZENIA (Żeby kompilator nie płakał) ---
    private var totalSpent: Double {
        logs.reduce(0) { $0 + $1.totalCost }
    }
    
    private var fuelStructure: [FuelStat] {
        calculateFuelStructure()
    }
    
    private var frequencyData: [FuelStat] {
        calculateFrequency()
    }

    var body: some View {
        NavigationView {
            ZStack {
                bgColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        
                        // 1. STRUKTURA WYDATKÓW
                        statCard(title: "Stosunek wydatków (PLN)", icon: "chart.pie.fill") {
                            HStack(spacing: 20) {
                                Chart(fuelStructure) { item in
                                    SectorMark(
                                        angle: .value("Suma", item.value),
                                        innerRadius: .ratio(0.65),
                                        angularInset: 2
                                    )
                                    .foregroundStyle(fuelColors[item.type] ?? .gray)
                                    .cornerRadius(5)
                                }
                                .frame(width: 160, height: 160)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(fuelStructure) { item in
                                        VStack(alignment: .leading, spacing: 0) {
                                            HStack(spacing: 4) {
                                                Circle().fill(fuelColors[item.type] ?? .gray).frame(width: 6, height: 6)
                                                Text(item.type).font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                                            }
                                            Text(String(format: "%.0f zł", item.value))
                                                .font(.system(size: 14, weight: .black))
                                                .foregroundColor(primaryText)
                                        }
                                        .padding(.bottom, 4)
                                    }
                                }
                            }
                        }

                        // 2. CZĘSTOTLIWOŚĆ
                        statCard(title: "Wizyty na stacji / Ładowania", icon: "calendar.badge.clock") {
                            Chart(frequencyData) { item in
                                BarMark(
                                    x: .value("Miesiąc", item.date),
                                    y: .value("Ilość", item.value)
                                )
                                .foregroundStyle(fuelColors[item.type] ?? .gray)
                                .cornerRadius(4)
                            }
                            .frame(height: 200)
                            .chartYAxis {
                                AxisMarks { value in
                                    AxisValueLabel().foregroundStyle(.gray)
                                }
                            }
                        }
                        
                        // 3. PODSUMOWANIE
                        VStack(spacing: 5) {
                            Text("SUMA WSZYSTKICH WYDATKÓW")
                                .font(.system(size: 10, weight: .black))
                                .tracking(2)
                                .foregroundColor(.gray)
                            
                            Text(String(format: "%.2f zł", totalSpent))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(primaryText)
                                .shadow(color: isDark ? .white.opacity(0.1) : .clear, radius: 10)
                        }
                        .padding(.vertical, 20)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Statystyki")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                    }
                }
            }
        }
    }

    // MARK: - LOGIKA (POMOCNIKI)
    
    private func fuelLabel(for type: FuelType?) -> String {
        guard let type = type else { return "Inne" }
        switch type {
        case .pb95: return "PB95"
        case .pb98: return "PB98"
        case .lpg: return "LPG"
        case .electricity: return "Prąd"
        case .diesel: return "Diesel"
        case .adblue: return "AdBlue"
        }
    }

    private func calculateFuelStructure() -> [FuelStat] {
        var distribution: [String: Double] = [:]
        for log in logs {
            let label = fuelLabel(for: log.fuelType)
            distribution[label, default: 0] += log.totalCost
        }
        return distribution.map { FuelStat(date: "", value: $0.value, type: $0.key) }.sorted { $0.value > $1.value }
    }

    private func calculateFrequency() -> [FuelStat] {
        var counts: [String: [String: Int]] = [:]
        for log in logs {
            let month = formatDate(log.date)
            let label = fuelLabel(for: log.fuelType)
            if counts[month] == nil { counts[month] = [:] }
            counts[month]![label, default: 0] += 1
        }
        var results: [FuelStat] = []
        for month in counts.keys.sorted() {
            for fuel in ["PB95", "PB98", "Diesel", "LPG", "Prąd", "AdBlue"] {
                if let count = counts[month]?[fuel], count > 0 {
                    results.append(FuelStat(date: month, value: Double(count), type: fuel))
                }
            }
        }
        return results
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MM.yy"; return f.string(from: date)
    }

    @ViewBuilder
    private func statCard<Content: View>(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Label(title.uppercased(), systemImage: icon)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundColor(.gray)
            
            content()
        }
        .padding(20)
        .background(cardColor)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(isDark ? .white.opacity(0.1) : .black.opacity(0.05), lineWidth: 1))
    }
}
