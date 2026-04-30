import SwiftUI

struct ContentView: View {
    @EnvironmentObject var data: AppData

    @State private var selectedCarId: UUID?

    @State private var showingAddCar = false
    @State private var showingStats = false
    @State private var showingSettings = false
    @State private var showingEditCar = false
    @State private var activeEntryType: EntryType? = nil
    @State private var logToEdit: LogEntry? = nil
    @State private var showingCostBreakdown = false
    @State private var showingOdometerHistory = false
    @State private var selectedMonthData: MonthSheetData? = nil
    @State private var scrollOffset: CGFloat = 0

    var selectedCar: Car? {
        data.cars.first(where: { $0.id == selectedCarId })
    }

    var currentLogs: [LogEntry] {
        data.logs.filter { $0.carId == selectedCarId }.sorted { $0.date > $1.date }
    }

    var currencySymbol: String {
        data.selectedUnitSystem == .imperial ? "$" : "zł"
    }

    var distanceUnit: String {
        data.selectedUnitSystem == .imperial ? "mi" : "km"
    }

    private var currentCarIndex: Int {
        guard let id = selectedCarId else { return 0 }
        return data.cars.firstIndex(where: { $0.id == id }) ?? 0
    }

    private var monthSummaries: [(month: String, totalCost: Double, fillupCount: Int, logs: [LogEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale.current

        var result: [(String, Double, Int, [LogEntry])] = []
        for log in currentLogs {
            let monthYear = formatter.string(from: log.date).capitalized
            if let lastIndex = result.indices.last, result[lastIndex].0 == monthYear {
                result[lastIndex].1 += log.totalCost
                result[lastIndex].2 += 1
                result[lastIndex].3.append(log)
            } else {
                result.append((monthYear, log.totalCost, 1, [log]))
            }
        }
        return result.map { (month: $0.0, totalCost: $0.1, fillupCount: $0.2, logs: $0.3) }
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var isDark: Bool { data.selectedTheme == .darkBlue }
    private var bgColor: Color { isDark ? Color(red: 10/255, green: 18/255, blue: 30/255) : PitstopColor.background }
    private var cardColor: Color { isDark ? Color(red: 20/255, green: 35/255, blue: 60/255) : PitstopColor.cardSurface }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            GeometryReader { geometry in
                mainContent(screenWidth: geometry.size.width)
            }
        }
        .onAppear {
            if selectedCarId == nil { selectedCarId = data.cars.first?.id }
        }
        .onChange(of: data.cars) { _, newCars in
            if let id = selectedCarId, !newCars.contains(where: { $0.id == id }) {
                selectedCarId = newCars.first?.id
            }
        }
        .sheet(isPresented: $showingSettings) { SettingsView(data: data) }
        .sheet(isPresented: $showingAddCar) { ManageCarsView(data: data, selectedCarId: $selectedCarId) }
        .sheet(isPresented: $showingEditCar) {
            if let car = selectedCar {
                CarFormView(data: data, selectedCarId: $selectedCarId, carToEdit: car)
            }
        }
        .sheet(item: $activeEntryType) { type in
            if let carId = selectedCarId {
                AddEntryView(carId: carId, type: type)
            }
        }
        .sheet(item: $logToEdit) { log in EditEntryView(data: data, logToEdit: log) }
        .sheet(isPresented: $showingStats) {
            if let car = selectedCar {
                StatisticsView(car: car, logs: currentLogs)
            }
        }
        .sheet(isPresented: $showingCostBreakdown) { CostBreakdownView(logs: currentLogs) }
        .sheet(isPresented: $showingOdometerHistory) { OdometerHistoryView(logs: currentLogs, unit: distanceUnit) }
        .sheet(item: $selectedMonthData) { monthData in
            MonthTransactionsSheet(
                month: monthData.month,
                logs: monthData.logs,
                currencySymbol: currencySymbol
            )
        }
        .preferredColorScheme(isDark ? .dark : .light)
    }

    @ViewBuilder
    private func mainContent(screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            PitstopTopBar(onSettings: { showingSettings = true })
                .padding(.horizontal, PitstopSpacing.pageHorizontal)
                .padding(.bottom, 12)
                .padding(.top, 8)

            if !data.cars.isEmpty {
                carouselWithList(screenWidth: screenWidth)
            } else {
                emptyState
            }
        }
    }

    @ViewBuilder
    private func carouselWithList(screenWidth: CGFloat) -> some View {
        let carousel = VehicleHeroCarousel(
            screenWidth: screenWidth,
            scrollOffset: scrollOffset,
            cars: data.cars,
            selectedCarId: $selectedCarId,
            logs: data.logs,
            currencySymbol: currencySymbol,
            onRefuel: { activeEntryType = .fuel },
            onCharge: { activeEntryType = .charge },
            onEditCar: { showingEditCar = true }
        )
        let expandedHeight = carousel.expandedHeight
        let dotsReservedHeight: CGFloat = data.cars.count > 1 ? 28 : 0

        // Pick non-scrolling layout when content fits; fall back to the
        // scroll-collapse layout when the list overflows.
        ViewThatFits(in: .vertical) {
            VStack(spacing: 0) {
                VehicleHeroCarousel(
                    screenWidth: screenWidth,
                    scrollOffset: 0,
                    cars: data.cars,
                    selectedCarId: $selectedCarId,
                    logs: data.logs,
                    currencySymbol: currencySymbol,
                    onRefuel: { activeEntryType = .fuel },
                    onCharge: { activeEntryType = .charge },
                    onEditCar: { showingEditCar = true }
                )

                if data.cars.count > 1 {
                    PitstopPageDots(
                        count: data.cars.count,
                        currentIndex: currentCarIndex
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: dotsReservedHeight)
                }

                if !currentLogs.isEmpty {
                    BreakdownsSection(
                        year: currentYear,
                        summaries: monthSummaries,
                        currencySymbol: currencySymbol,
                        onStatsTap: { showingStats = true },
                        onMonthTap: { summary in
                            selectedMonthData = MonthSheetData(
                                month: summary.month,
                                logs: summary.logs
                            )
                        }
                    )
                    .padding(.top, 16)
                }
            }
            .onAppear { scrollOffset = 0 }

            ZStack(alignment: .top) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: expandedHeight)

                        if data.cars.count > 1 {
                            PitstopPageDots(
                                count: data.cars.count,
                                currentIndex: currentCarIndex
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: dotsReservedHeight)
                        }

                        if !currentLogs.isEmpty {
                            BreakdownsSection(
                                year: currentYear,
                                summaries: monthSummaries,
                                currencySymbol: currencySymbol,
                                onStatsTap: { showingStats = true },
                                onMonthTap: { summary in
                                    selectedMonthData = MonthSheetData(
                                        month: summary.month,
                                        logs: summary.logs
                                    )
                                }
                            )
                            .padding(.top, 16)
                        }
                    }
                }
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y
                } action: { _, newValue in
                    scrollOffset = max(newValue, 0)
                }

                carousel
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        Spacer()
        Button(action: { showingAddCar = true }) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(isDark ? .white.opacity(0.3) : PitstopColor.textSecondary.opacity(0.4))
                Text("Add your first vehicle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDark ? .gray : PitstopColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(cardColor)
            .cornerRadius(PitstopRadius.card)
            .padding(.horizontal, PitstopSpacing.pageHorizontal)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(ViewID.emptyState)
        Spacer()
    }
}

struct MonthSheetData: Identifiable {
    let id = UUID()
    let month: String
    let logs: [LogEntry]
}

// MARK: - Cost Breakdown (kept from original)

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

#Preview {
    let data = AppData()
    data.cars = [
        Car(name: "Toyota RAV4", type: .phev, primaryFuel: .pb95, secondaryFuel: nil, licensePlate: "WA 12345"),
        Car(name: "Tesla Model 3", type: .electric, primaryFuel: .electricity, secondaryFuel: nil, licensePlate: "KR 99999"),
        Car(name: "VW Golf", type: .petrol, primaryFuel: .pb95, secondaryFuel: .lpg, licensePlate: "GD 55555")
    ]
    let now = Date()
    let cal = Calendar.current
    data.logs = [
        LogEntry(carId: data.cars[0].id, type: .fuel, fuelType: .pb95, amount: 45, pricePerUnit: 6.21, odometer: 52300, date: now),
        LogEntry(carId: data.cars[0].id, type: .fuel, fuelType: .pb95, amount: 40, pricePerUnit: 6.15, odometer: 51800, date: cal.date(byAdding: .day, value: -10, to: now)!),
        LogEntry(carId: data.cars[0].id, type: .charge, fuelType: .electricity, amount: 25, pricePerUnit: 2.0, odometer: 51500, date: cal.date(byAdding: .day, value: -20, to: now)!),
        LogEntry(carId: data.cars[0].id, type: .fuel, fuelType: .pb95, amount: 38, pricePerUnit: 6.30, odometer: 50900, date: cal.date(byAdding: .month, value: -1, to: now)!),
    ]
    return ContentView()
        .environmentObject(data)
}
