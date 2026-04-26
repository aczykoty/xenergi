import SwiftUI
import Combine

struct ContentView: View {
    // MARK: - Stan Aplikacji
    @EnvironmentObject var data: AppData
    
    @State private var selectedCarId: UUID?
    
    // Stany dla arkuszy (Sheets)
    @State private var showingAddCar = false
    @State private var showingStats = false
    @State private var showingSettings = false
    @State private var showingEditCar = false
    @State private var activeEntryType: EntryType? = nil
    @State private var logToEdit: LogEntry? = nil
    
    // Stany dla popupów i historii
    @State private var showingCostBreakdown = false
    @State private var showingOdometerHistory = false
    @State private var expandedMonths: Set<String> = []
    
    // MARK: - Helpery Stylu (Zintegrowane)
    private var isDark: Bool {
        data.selectedTheme == .darkBlue
    }
    
    private var primaryTextColor: Color {
        isDark ? .white : .black
    }
    
    private var cardColor: Color {
        isDark ? Color(red: 20/255, green: 35/255, blue: 60/255) : .white
    }

    // MARK: - Dynamiczne Tło
    @ViewBuilder
    private var backgroundColor: some View {
        ZStack {
            // 1. Warstwa bazowa (Kolor pod spodem)
            (isDark ?
                Color(red: 10/255, green: 20/255, blue: 40/255) :
                Color(UIColor.systemGroupedBackground))
            .ignoresSafeArea()

            // 2. Warstwa tapety - CZYSTA, bez gradientu na dole
            if data.selectedWallpaper != .none {
                Image(data.selectedWallpaper.rawValue)
                    .resizable()
                    .aspectRatio(contentMode: .fit) // Zachowuje proporcje Twojej tapety
                    .ignoresSafeArea()
                    // Usunęliśmy stąd LinearGradient
                    .overlay(
                        // Zostawiamy tylko minimalne przyciemnienie całego zdjęcia,
                        // żeby białe napisy były czytelne na jasnych fotkach.
                        Color.black.opacity(isDark ? 0.15 : 0.05)
                    )
            }
        }
    }

    // MARK: - Właściwości Obliczeniowe
    var selectedCar: Car? {
        data.cars.first(where: { $0.id == selectedCarId })
    }
    
    var currentLogs: [LogEntry] {
        data.logs.filter { $0.carId == selectedCarId }.sorted { $0.date > $1.date }
    }
    
    var totalCostForCurrentCar: Double {
        currentLogs.map { $0.totalCost }.reduce(0, +)
    }
    
    var currencySymbol: String {
        data.selectedUnitSystem == .imperial ? "$" : "zł"
    }
    
    var distanceUnit: String {
        data.selectedUnitSystem == .imperial ? "mi" : "km"
    }
    
    var groupedLogs: [(String, [LogEntry])] {
        var result: [(String, [LogEntry])] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "pl_PL")
        
        for log in currentLogs {
            let monthYear = formatter.string(from: log.date).capitalized
            if let lastIndex = result.indices.last, result[lastIndex].0 == monthYear {
                result[lastIndex].1.append(log)
            } else {
                result.append((monthYear, [log]))
            }
        }
        return result
    }

    private func updateDotColors() {
        if isDark {
            UIPageControl.appearance().currentPageIndicatorTintColor = UIColor.white
            UIPageControl.appearance().pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.3)
        } else {
            UIPageControl.appearance().currentPageIndicatorTintColor = UIColor.black
            UIPageControl.appearance().pageIndicatorTintColor = UIColor.systemGray2
        }
    }

    // MARK: - Widok Główny
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 15) {
                        
                        if !data.cars.isEmpty {
                            TabView(selection: $selectedCarId) {
                                ForEach(data.cars) { car in
                                    HeroCardView(
                                        car: car,
                                        totalCost: totalCostForCurrentCar,
                                        logs: currentLogs,
                                        onCostTap: { showingCostBreakdown = true },
                                        onOdometerTap: { showingOdometerHistory = true }
                                    )
                                    .tag(car.id as UUID?)
                                    .padding(.bottom, 35)
                                    .onTapGesture {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        showingEditCar = true
                                    }
                                }
                            }
                            .frame(height: 240)
                            .tabViewStyle(.page(indexDisplayMode: .always))
                            .overlay(
                                Capsule()
                                    .fill(isDark ? Color.black.opacity(0.2) : Color.black.opacity(0.06))
                                    .frame(width: 90, height: 26)
                                    .overlay(
                                        Capsule()
                                            .stroke(isDark ? primaryTextColor.opacity(0.1) : Color.black.opacity(0.15), lineWidth: 0.5)
                                    )
                                    .padding(.bottom, 12),
                                alignment: .bottom
                            )
                        } else {
                            Button(action: { showingAddCar = true }) {
                                VStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill").font(.system(size: 40)).foregroundColor(.gray.opacity(0.3))
                                    Text("Dodaj swój pierwszy pojazd").font(.system(size: 14, weight: .medium)).foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity).frame(height: 170)
                                .background(cardColor).cornerRadius(20).padding(.horizontal)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // AKCJE
                        HStack(spacing: 15) {
                            ActionButton(
                                title: "TANKOWANIE",
                                icon: "fuelpump.fill",
                                color: .orange,
                                isDisabled: selectedCar?.type == .electric || selectedCar == nil
                            ) { activeEntryType = .fuel }
                            
                            ActionButton(
                                title: "ŁADOWANIE",
                                icon: "bolt.car.fill",
                                color: .blue,
                                isDisabled: selectedCar?.type == .petrol || selectedCar?.type == .diesel || selectedCar == nil
                            ) { activeEntryType = .charge }
                        }
                        .padding(.horizontal)
                        
                        // HISTORIA
                        VStack(alignment: .leading, spacing: 0) {
                            if currentLogs.isEmpty {
                                Text("Brak wpisów").font(.caption).foregroundColor(.gray).padding()
                            } else {
                                ForEach(groupedLogs, id: \.0) { month, logs in
                                    VStack(spacing: 0) {
                                        Button(action: {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                if expandedMonths.contains(month) { expandedMonths.remove(month) }
                                                else { expandedMonths.insert(month) }
                                            }
                                        }) {
                                            HStack {
                                                Text(month.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundColor(.blue)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.blue)
                                                    .rotationEffect(.degrees(expandedMonths.contains(month) ? 90 : 0))
                                            }
                                            .padding(.vertical, 18).padding(.horizontal, 20)
                                            .background(
                                                isDark ? Color(red: 45/255, green: 75/255, blue: 135/255) : Color(red: 228/255, green: 230/255, blue: 235/255)
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        if expandedMonths.contains(month) {
                                            VStack(spacing: 0) {
                                                Color.clear.frame(height: 10)
                                                ForEach(logs) { log in
                                                    VStack(spacing: 0) {
                                                        Button(action: { logToEdit = log }) {
                                                            LogRowView(log: log)
                                                                .padding(.vertical, 12)
                                                        }
                                                        .buttonStyle(PlainButtonStyle())

                                                        if log.id != logs.last?.id {
                                                            Divider()
                                                                .padding(.horizontal, 20)
                                                                .opacity(isDark ? 0.4 : 0.7)
                                                        }
                                                    }
                                                }
                                                Color.clear.frame(height: 10)
                                            }
                                            .background(isDark ? Color(red: 10/255, green: 20/255, blue: 40/255) : Color(white: 0.99))
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                        }
                                        Divider().padding(.horizontal, 20).opacity(isDark ? 0.1 : 0.3)
                                    }
                                }
                            }
                        }
                        .background(cardColor)
                        .cornerRadius(18)
                        .padding(.horizontal)
                        .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.03), radius: 10, x: 0, y: 5)
                    }
                    .padding(.vertical)
                }
                
                // PRZYCISK STATYSTYK (FAB)
                if !currentLogs.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: { showingStats = true }) {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .shadow(radius: 8)
                            }.padding(25)
                        }
                    }
                }
            }
            .navigationTitle("Dziennik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill").foregroundColor(primaryTextColor.opacity(0.6))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddCar = true }) {
                        Image(systemName: "car.fill").foregroundColor(primaryTextColor)
                    }
                }
            }
            .onAppear {
                updateDotColors()
                if selectedCarId == nil { selectedCarId = data.cars.first?.id }
                if let first = groupedLogs.first?.0 { expandedMonths.insert(first) }
            }
            .onChange(of: data.selectedTheme) { _ in updateDotColors() }
            .sheet(isPresented: $showingSettings) { SettingsView(data: data) }
            .sheet(isPresented: $showingAddCar) { ManageCarsView(data: data, selectedCarId: $selectedCarId) }
            .sheet(isPresented: $showingEditCar) {
                if let car = selectedCar {
                    CarFormView(data: data, selectedCarId: $selectedCarId, carToEdit: car)
                }
            }
            .sheet(item: $activeEntryType) { type in AddEntryView(carId: selectedCarId!, type: type) }
            .sheet(item: $logToEdit) { log in EditEntryView(data: data, logToEdit: log) }
            .sheet(isPresented: $showingStats) { if let car = selectedCar { StatisticsView(car: car, logs: currentLogs) } }
            .sheet(isPresented: $showingCostBreakdown) { CostBreakdownView(logs: currentLogs) }
            .sheet(isPresented: $showingOdometerHistory) { OdometerHistoryView(logs: currentLogs, unit: distanceUnit) }
        }
        .preferredColorScheme(isDark ? .dark : .light)
    }
}

// MARK: - WIDOKI POMOCNICZE

struct CostBreakdownView: View {
    @EnvironmentObject var data: AppData
    let logs: [LogEntry]
    
    private var selectedCar: Car? {
        guard let carId = logs.first?.carId else { return nil }
        return data.cars.first(where: { $0.id == carId })
    }
    
    private var currency: String {
        data.selectedUnitSystem == .imperial ? "$" : "zł"
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 6).padding(.top, 10)
            Text("Rozbicie kosztów").font(.system(size: 24, weight: .bold))
            
            VStack(spacing: 20) {
                if let car = selectedCar {
                    let existingFuelTypes: [FuelType] = {
                        var types = Set(logs.compactMap { $0.fuelType })
                        if logs.contains(where: { $0.fuelType == nil && $0.type == .fuel }) { types.insert(car.primaryFuel) }
                        if logs.contains(where: { $0.fuelType == nil && $0.type == .charge }) { types.insert(.electricity) }
                        return Array(types).sorted { $0.rawValue < $1.rawValue }
                    }()
                    
                    ForEach(existingFuelTypes, id: \.self) { fuel in
                        let total = logs.reduce(0.0) { sum, log in
                            if let logFuel = log.fuelType {
                                return logFuel == fuel ? sum + log.totalCost : sum
                            } else {
                                if log.type == .fuel && fuel == car.primaryFuel { return sum + log.totalCost }
                                else if log.type == .charge && fuel == .electricity { return sum + log.totalCost }
                                return sum
                            }
                        }
                        
                        if total > 0 {
                            HStack(spacing: 15) {
                                Image(systemName: fuel.icon).font(.system(size: 26)).foregroundColor(fuel.color)
                                Text(fuel.label(for: data.selectedUnitSystem))
                                    .font(.system(size: 20, weight: .medium))
                                Spacer()
                                Text(String(format: "%.2f %@", total, currency))
                                    .font(.system(size: 22, weight: .bold))
                            }
                            .padding(.horizontal, 25)
                        }
                    }
                }
            }
            Spacer()
        }
        .presentationDetents([.height(320)])
    }
}

struct OdometerHistoryView: View {
    let logs: [LogEntry]
    let unit: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(logs.filter { $0.odometer != nil }.sorted { $0.date > $1.date }) { log in
                HStack {
                    Text(log.date, style: .date).foregroundColor(.gray)
                    Spacer()
                    Text("\(log.odometer!) \(unit)").bold()
                }
            }
            .navigationTitle("Historia licznika")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Gotowe") { dismiss() } } }
        }
    }
}
