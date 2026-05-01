import SwiftUI

struct ContentView: View {
    @EnvironmentObject var data: AppData

    @State private var selectedCarId: UUID?

    @State private var showingAddCar = false
    @State private var statsYear: YearStatsData? = nil
    @State private var showingSettings = false
    @State private var showingEditCar = false
    @State private var activeEntryType: EntryType? = nil
    @State private var logToEdit: LogEntry? = nil
    @State private var showingCostBreakdown = false
    @State private var showingOdometerHistory = false
    @State private var selectedMonthData: MonthSheetData? = nil
    @State private var listAppeared: Bool = true
    @State private var displayedCarId: UUID? = nil

    var selectedCar: Car? {
        data.cars.first(where: { $0.id == selectedCarId })
    }

    var currentLogs: [LogEntry] {
        // List uses displayedCarId so it can hold the previous car's data
        // through the brief out-animation before swapping to the new car.
        let listCarId = displayedCarId ?? selectedCarId
        return data.logs.filter { $0.carId == listCarId }.sorted { $0.date > $1.date }
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

    private var monthSummaries: [MonthSummary] {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale.current

        var result: [MonthSummary] = []
        for log in currentLogs {
            let monthYear = formatter.string(from: log.date).capitalized
            if let lastIndex = result.indices.last, result[lastIndex].month == monthYear {
                result[lastIndex].totalCost += log.totalCost
                result[lastIndex].fillupCount += 1
                result[lastIndex].logs.append(log)
            } else {
                result.append((month: monthYear, totalCost: log.totalCost, fillupCount: 1, logs: [log]))
            }
        }
        return result
    }

    private var yearSections: [YearSection] {
        let cal = Calendar.current
        var grouped: [Int: [MonthSummary]] = [:]
        for summary in monthSummaries {
            guard let firstLog = summary.logs.first else { continue }
            let year = cal.component(.year, from: firstLog.date)
            grouped[year, default: []].append(summary)
        }
        return grouped
            .map { (year: $0.key, summaries: $0.value) }
            .sorted { $0.year > $1.year }
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private func openCurrentMonthSheet(for carId: UUID) {
        let cal = Calendar.current
        let now = Date()
        let logs = data.logs
            .filter { $0.carId == carId && cal.isDate($0.date, equalTo: now, toGranularity: .month) }
            .sorted { $0.date > $1.date }
        guard !logs.isEmpty else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale.current
        let monthLabel = formatter.string(from: now).capitalized
        selectedMonthData = MonthSheetData(month: monthLabel, logs: logs)
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
            if displayedCarId == nil { displayedCarId = selectedCarId }
        }
        .onChange(of: data.cars) { _, newCars in
            if let id = selectedCarId, !newCars.contains(where: { $0.id == id }) {
                selectedCarId = newCars.first?.id
            }
        }
        .task(id: selectedCarId) {
            // Skip the animation on first render.
            guard displayedCarId != nil, displayedCarId != selectedCarId else {
                displayedCarId = selectedCarId
                return
            }
            withAnimation { listAppeared = false }
            try? await Task.sleep(for: .milliseconds(280))
            displayedCarId = selectedCarId
            withAnimation { listAppeared = true }
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
        .sheet(item: $statsYear) { yearData in
            if let car = selectedCar {
                StatisticsView(car: car, logs: yearData.logs)
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
        // Scroll state lives in CarouselListContainer so vertical scroll updates
        // do not invalidate ContentView.body — keeps month/year aggregations and
        // the list of children stable while the user scrolls.
        CarouselListContainer(
            screenWidth: screenWidth,
            cars: data.cars,
            selectedCarId: $selectedCarId,
            logs: data.logs,
            currencySymbol: currencySymbol,
            currentCarIndex: currentCarIndex,
            yearSections: yearSections,
            monthCountPrefix: monthCountPrefix,
            hasLogs: !currentLogs.isEmpty,
            listAppeared: listAppeared,
            onRefuel: { activeEntryType = .fuel },
            onCharge: { activeEntryType = .charge },
            onEditCar: { showingEditCar = true },
            onCurrentMonth: { carId in openCurrentMonthSheet(for: carId) },
            onStatsTap: { year, logs in statsYear = YearStatsData(year: year, logs: logs) },
            onMonthTap: { month, logs in selectedMonthData = MonthSheetData(month: month, logs: logs) }
        )
    }

    private var monthCountPrefix: [Int] {
        var counts: [Int] = []
        var running = 0
        for section in yearSections {
            counts.append(running)
            running += section.summaries.count
        }
        return counts
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

struct YearStatsData: Identifiable {
    let id = UUID()
    let year: Int
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
