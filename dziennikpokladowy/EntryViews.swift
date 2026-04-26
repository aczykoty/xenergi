import SwiftUI
import Combine
import UIKit

// MARK: - 0. MODELE POMOCNICZE
struct ScanResult: Identifiable {
    let id = UUID()
    let amount: Double
    let price: Double
    let total: Double
}

// MARK: - 1. GŁÓWNY WIDOK DODAWANIA
struct AddEntryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var data: AppData
    let carId: UUID
    let type: EntryType
    
    @State private var amountText = ""
    @State private var priceText = ""
    @State private var totalCostText = ""
    @State private var odometerText = ""
    @State private var date = Date()
    @FocusState private var activeField: Int?
    
    @State private var selectedFuel: FuelType = .pb95
    @State private var showingLiveScanner = false
    @State private var activeScanResult: ScanResult? = nil
    
    @State private var startSoC: Double = 0.2
    @State private var endSoC: Double = 0.8

    private var isDark: Bool { data.selectedTheme == .darkBlue }
    private var bgColor: Color { isDark ? Color(red: 10/255, green: 20/255, blue: 40/255) : Color(red: 245/255, green: 245/255, blue: 247/255) }
    private var rowColor: Color { isDark ? Color(red: 20/255, green: 35/255, blue: 60/255) : .white }
    private var textColor: Color { isDark ? .white : .primary }

    var currentCar: Car? { data.cars.first(where: { $0.id == carId }) }

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                Form {
                    if type == .fuel { fuelSelectionSection }
                    if type == .charge { batterySection }
                    aiScannerSection
                    transactionDataSection
                    additionalDataSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(type == .fuel ? "Tankowanie" : "Ładowanie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() }.foregroundColor(.gray) }
                ToolbarItem(placement: .confirmationAction) { Button("Zapisz") { saveEntry() }.bold().foregroundColor(.blue) }
            }
            .fullScreenCover(isPresented: $showingLiveScanner) { scannerCover }
        }
        .onAppear { setupInitialFuel() }
    }
}

// MARK: - SUBVIEWS DLA ADDENTRYVIEW
extension AddEntryView {
    private var batterySection: some View {
        Section {
            VStack(spacing: 20) {
                BatterySlider(percentage: $startSoC, label: "POZIOM PRZED", isDark: isDark)
                BatterySlider(percentage: $endSoC, label: "POZIOM PO", isDark: isDark)
            }
            .padding(.vertical, 10)
        } header: { Text("STAN BATERII (SoC)").font(.system(size: 10, weight: .black)).tracking(2).foregroundColor(.gray) }
        .listRowBackground(rowColor)
    }

    private var fuelSelectionSection: some View {
        Section {
            if let car = currentCar {
                HStack(spacing: 12) {
                    if car.primaryFuel == .pb95 || car.primaryFuel == .pb98 {
                        FuelSelectButton(fuel: .pb95, isSelected: selectedFuel == .pb95, theme: data.selectedTheme) { selectedFuel = .pb95 }
                        FuelSelectButton(fuel: .pb98, isSelected: selectedFuel == .pb98, theme: data.selectedTheme) { selectedFuel = .pb98 }
                    } else {
                        FuelSelectButton(fuel: car.primaryFuel, isSelected: selectedFuel == car.primaryFuel, theme: data.selectedTheme) { selectedFuel = car.primaryFuel }
                    }
                    if car.secondaryFuel == .lpg { FuelSelectButton(fuel: .lpg, isSelected: selectedFuel == .lpg, theme: data.selectedTheme) { selectedFuel = .lpg } }
                    if car.primaryFuel == .diesel { FuelSelectButton(fuel: .adblue, isSelected: selectedFuel == .adblue, theme: data.selectedTheme) { selectedFuel = .adblue } }
                }
                .padding(.vertical, 10)
            }
        } header: { Text("RODZAJ PALIWA").font(.system(size: 10, weight: .black)).tracking(2).foregroundColor(.gray) }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
    
    private var aiScannerSection: some View {
        Section {
            Button(action: { showingLiveScanner = true }) {
                HStack {
                    Spacer(); Image(systemName: "viewfinder.circle.fill").font(.title3)
                    Text("SKANUJ DYSTRYBUTOR (AI)").font(.system(size: 12, weight: .black)).tracking(1.5); Spacer()
                }
                .foregroundColor(.white).padding(.vertical, 14).background(Color.blue).cornerRadius(12)
                .shadow(color: Color.black.opacity(isDark ? 0.4 : 0.15), radius: 8, x: 0, y: 4)
            }
            .padding(.vertical, 5)
        }
        .listRowBackground(Color.clear)
    }
    
    private var transactionDataSection: some View {
        Section {
            rowField(label: "Ilość", unit: type == .charge ? "kWh" : "L", icon: type == .charge ? "bolt.fill" : "drop.fill", text: $amountText, fieldTag: 1)
            rowField(label: "Cena", unit: "zł/u", icon: "tag.fill", text: $priceText, fieldTag: 2)
            rowField(label: "Suma", unit: "zł", icon: "creditcard.fill", text: $totalCostText, fieldTag: 3)
        } header: { Text("DANE TRANSAKCJI").font(.system(size: 10, weight: .black)).tracking(2).foregroundColor(.gray) }
        .listRowBackground(rowColor)
    }
    
    private var additionalDataSection: some View {
        Section {
            HStack {
                Image(systemName: "gauge.with.needle.fill").foregroundColor(.blue).frame(width: 25)
                Text("Stan licznika").foregroundColor(textColor)
                Spacer()
                TextField("0", text: $odometerText).keyboardType(.numberPad).multilineTextAlignment(.trailing).focused($activeField, equals: 4)
                Text("km").foregroundColor(.gray).font(.caption).frame(width: 35, alignment: .leading)
            }
            DatePicker(selection: $date) {
                HStack { Image(systemName: "calendar").foregroundColor(.blue).frame(width: 25); Text("Data").foregroundColor(textColor) }
            }.tint(.blue)
        } header: { Text("DODATKOWE").font(.system(size: 10, weight: .black)).tracking(2).foregroundColor(.gray) }
        .listRowBackground(rowColor)
    }
    
    private var scannerCover: some View {
        ZStack {
            LiveScannerView(type: type) { bestTriplet, explicitKwh in
                if let result = bestTriplet {
                    self.activeScanResult = ScanResult(amount: result.amount, price: result.price, total: result.total)
                } else if type == .charge, let kwh = explicitKwh {
                    self.amountText = formatDouble(kwh); self.showingLiveScanner = false
                }
            }
            .ignoresSafeArea()
            LiveScannerHUD(type: type) { showingLiveScanner = false }
        }
        .sheet(item: $activeScanResult) { result in
            ScannerConfirmationView(result: result, isDark: isDark) {
                self.amountText = formatDouble(result.amount); self.priceText = formatDouble(result.price); self.totalCostText = formatDouble(result.total)
                self.activeScanResult = nil; self.showingLiveScanner = false
            } onCancel: { self.activeScanResult = nil }
            .presentationDetents([.medium]).presentationCornerRadius(30)
            .presentationBackground(isDark ? Color(red: 20/255, green: 35/255, blue: 60/255) : .white)
        }
    }
    
    @ViewBuilder
    private func rowField(label: String, unit: String, icon: String, text: Binding<String>, fieldTag: Int) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(.blue.opacity(0.8)).frame(width: 25)
            Text(label).foregroundColor(textColor); Spacer()
            TextField("0,00", text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($activeField, equals: fieldTag)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .onChange(of: text.wrappedValue) { _, _ in updateDependencies(from: fieldTag) }
            Text(unit).foregroundColor(.gray).font(.caption).frame(width: 35, alignment: .leading)
        }
    }

    private func formatDouble(_ value: Double) -> String { String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",") }

    private func setupInitialFuel() {
        if type == .charge { selectedFuel = .electricity }
        else if let car = currentCar { selectedFuel = car.primaryFuel }
    }

    private func updateDependencies(from field: Int) {
        guard activeField == field else { return }
        let amt = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let prc = Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let tot = Double(totalCostText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let format: (Double) -> String = { String(format: "%.2f", $0).replacingOccurrences(of: ".", with: ",") }
        if field == 1 && prc > 0 { totalCostText = format(amt * prc) }
        else if field == 2 && amt > 0 { totalCostText = format(amt * prc) }
        else if field == 3 && amt > 0 { priceText = format(tot / amt) }
    }

    private func saveEntry() {
        let amt = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let prc = Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let odo = Int(odometerText)
        var newEntry = LogEntry(carId: carId, type: type, fuelType: (type == .charge ? .electricity : selectedFuel), amount: amt, pricePerUnit: prc, odometer: (odo ?? 0) > 0 ? odo : nil, date: date)
        
        if type == .charge {
            newEntry.startSoC = startSoC
            newEntry.endSoC = endSoC
        }
        
        data.logs.append(newEntry); data.objectWillChange.send(); dismiss()
    }
}

// MARK: - 2. WIDOK EDYCJI
struct EditEntryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var data: AppData
    let logToEdit: LogEntry
    
    @State private var amountText: String; @State private var priceText: String; @State private var totalCostText: String; @State private var odometerText: String; @State private var date: Date
    @State private var startSoC: Double = 0.0
    @State private var endSoC: Double = 0.0
    
    @FocusState private var activeField: Int? // 4: Licznik, 1: Ilość, 2: Cena, 3: Suma
    
    private var isDark: Bool { data.selectedTheme == .darkBlue }
    private var bgColor: Color { isDark ? Color(red: 10/255, green: 20/255, blue: 40/255) : Color(red: 245/255, green: 245/255, blue: 247/255) }
    private var rowColor: Color { isDark ? Color(red: 20/255, green: 35/255, blue: 60/255) : .white }
    private var textColor: Color { isDark ? .white : .primary }

    init(data: AppData, logToEdit: LogEntry) {
        self.logToEdit = logToEdit
        _amountText = State(initialValue: String(format: "%.2f", logToEdit.amount).replacingOccurrences(of: ".", with: ","))
        _priceText = State(initialValue: String(format: "%.2f", logToEdit.pricePerUnit).replacingOccurrences(of: ".", with: ","))
        _totalCostText = State(initialValue: String(format: "%.2f", logToEdit.totalCost).replacingOccurrences(of: ".", with: ","))
        _odometerText = State(initialValue: logToEdit.odometer != nil ? "\(logToEdit.odometer!)" : "")
        _date = State(initialValue: logToEdit.date)
        _startSoC = State(initialValue: logToEdit.startSoC ?? 0.2)
        _endSoC = State(initialValue: logToEdit.endSoC ?? 0.8)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                Form {
                    if logToEdit.type == .charge {
                        Section {
                            VStack(spacing: 20) {
                                BatterySlider(percentage: $startSoC, label: "POZIOM PRZED", isDark: isDark)
                                BatterySlider(percentage: $endSoC, label: "POZIOM PO", isDark: isDark)
                            }
                            .padding(.vertical, 10)
                        } header: { Text("STAN BATERII (SoC)").font(.system(size: 10, weight: .black)).tracking(2).foregroundColor(.gray) }
                        .listRowBackground(rowColor)
                    }

                    Section {
                        DatePicker(selection: $date) { HStack { Image(systemName: "calendar").foregroundColor(.blue).frame(width: 25); Text("Data i godzina").foregroundColor(textColor) } }.tint(.blue)
                        
                        // Pola z przypisanymi tagami dla nawigacji
                        rowField(label: "Stan licznika", unit: "km", icon: "gauge.with.needle.fill", text: $odometerText, fieldTag: 4)
                        rowField(label: "Ilość", unit: logToEdit.type == .charge ? "kWh" : "L", icon: logToEdit.type == .charge ? "bolt.fill" : "drop.fill", text: $amountText, fieldTag: 1)
                        rowField(label: "Cena", unit: "zł/u", icon: "tag.fill", text: $priceText, fieldTag: 2)
                        rowField(label: "Suma", unit: "zł", icon: "creditcard.fill", text: $totalCostText, fieldTag: 3)
                        
                    } header: { Text("DANE PODSTAWOWE").font(.system(size: 10, weight: .black)).tracking(2).foregroundColor(.gray) }.listRowBackground(rowColor)
                    
                    Section {
                        Button(role: .destructive) { data.logs.removeAll(where: { $0.id == logToEdit.id }); data.objectWillChange.send(); dismiss() } label: { HStack { Spacer(); Image(systemName: "trash.fill"); Text("USUŃ WPIS"); Spacer() }.font(.system(size: 12, weight: .black)).tracking(1) }
                    }.listRowBackground(rowColor)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edytuj Wpis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Przyciski zapisu/anulowania
                ToolbarItem(placement: .confirmationAction) { Button("Zapisz") { save() }.bold().foregroundColor(.blue) }
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() }.foregroundColor(.gray) }
                
                // Pasek nad klawiaturą
                ToolbarItemGroup(placement: .keyboard) {
                    Button(action: focusPreviousField) {
                        Image(systemName: "chevron.up")
                    }
                    Button(action: focusNextField) {
                        Image(systemName: "chevron.down")
                    }
                    Spacer()
                    Button("Gotowe") {
                        activeField = nil
                    }
                    .font(.system(size: 15, weight: .bold))
                }
            }
        }
    }
    
    // MARK: - Row Field Builder
    
    @ViewBuilder
    private func rowField(label: String, unit: String, icon: String, text: Binding<String>, fieldTag: Int) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(.blue.opacity(0.8)).frame(width: 25)
            Text(label).foregroundColor(textColor); Spacer()
            TextField("0,00", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($activeField, equals: fieldTag)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                // Poprawka: Auto-czyszczenie pola po kliknięciu
                .onChange(of: activeField) { oldValue, newValue in
                    if newValue == fieldTag {
                        if text.wrappedValue == "0" || text.wrappedValue == "0,00" {
                            text.wrappedValue = ""
                        }
                    }
                }
                .onChange(of: text.wrappedValue) { _, _ in updateDependencies(from: fieldTag) }
            Text(unit).foregroundColor(.gray).font(.caption).frame(width: 35, alignment: .leading)
        }
    }
    
    // MARK: - Nawigacja klawiatury
    
    private func focusNextField() {
        switch activeField {
        case 4: activeField = 1
        case 1: activeField = 2
        case 2: activeField = 3
        case 3: activeField = nil
        default: break
        }
    }
    
    private func focusPreviousField() {
        switch activeField {
        case 1: activeField = 4
        case 2: activeField = 1
        case 3: activeField = 2
        default: break
        }
    }
    
    // MARK: - Funkcje logiczne
    
    private func save() {
        if let index = data.logs.firstIndex(where: { $0.id == logToEdit.id }) {
            data.logs[index].amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
            data.logs[index].pricePerUnit = Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
            data.logs[index].odometer = Int(odometerText)
            data.logs[index].date = date
            data.logs[index].startSoC = startSoC
            data.logs[index].endSoC = endSoC
            data.objectWillChange.send()
        }
        dismiss()
    }

    private func updateDependencies(from field: Int) {
        guard activeField == field else { return }
        let amt = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let prc = Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let tot = Double(totalCostText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let format: (Double) -> String = { String(format: "%.2f", $0).replacingOccurrences(of: ".", with: ",") }
        if field == 1 && prc > 0 { totalCostText = format(amt * prc) }
        else if field == 2 && amt > 0 { totalCostText = format(amt * prc) }
        else if field == 3 && amt > 0 { priceText = format(tot / amt) }
    }
}

// MARK: - 4. INNE KOMPONENTY
struct ScannerConfirmationView: View {
    let result: ScanResult; let isDark: Bool
    var onConfirm: () -> Void; var onCancel: () -> Void
    private var bgColor: Color { isDark ? Color(red: 20/255, green: 35/255, blue: 60/255) : .white }
    private var textColor: Color { isDark ? .white : .primary }
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            VStack(spacing: 25) {
                Capsule().fill(.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 10)
                Text("WERYFIKACJA AI").font(.system(size: 11, weight: .black)).tracking(2).foregroundColor(.blue)
                VStack(spacing: 15) {
                    confirmRow(label: "SUMA DO ZAPŁATY", value: String(format: "%.2f zł", result.total), isMain: true)
                    Divider().background(isDark ? .white.opacity(0.1) : .black.opacity(0.1))
                    HStack(spacing: 40) {
                        confirmRow(label: "ILOŚĆ", value: String(format: "%.2f", result.amount), isMain: false)
                        confirmRow(label: "CENA", value: String(format: "%.2f", result.price), isMain: false)
                    }
                }.padding(25).background(isDark ? Color.white.opacity(0.05) : Color.blue.opacity(0.05)).cornerRadius(20)
                Button(action: { UIImpactFeedbackGenerator(style: .heavy).impactOccurred(); onConfirm() }) {
                    Text("ZASTOSUJ DANE").font(.system(size: 15, weight: .bold)).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 55).background(Color.blue).cornerRadius(15).shadow(color: Color.blue.opacity(isDark ? 0 : 0.3), radius: 10, y: 5)
                }.padding(.horizontal)
                Button("Anuluj i spróbuj ponownie", action: onCancel).font(.system(size: 14)).foregroundColor(.gray).padding(.bottom, 20)
            }.padding()
        }
    }
    private func confirmRow(label: String, value: String, isMain: Bool) -> some View {
        VStack { Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.gray); Text(value).font(.system(size: isMain ? 42 : 24, weight: .black, design: .rounded)).foregroundColor(textColor) }
    }
}

struct FuelSelectButton: View {
    let fuel: FuelType; let isSelected: Bool; let theme: AppTheme; let action: () -> Void
    private var isDark: Bool { theme == .darkBlue }
    private var fuelColor: Color {
        switch fuel {
        case .pb95: return Color(red: 255/255, green: 190/255, blue: 0/255)
        case .pb98: return Color.red
        case .diesel: return isDark ? Color(white: 0.8) : Color(white: 0.1)
        case .lpg: return Color.blue
        case .electricity: return Color.green
        case .adblue: return Color.cyan
        }
    }
    var body: some View {
        Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); action() }) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15).fill(isSelected ? fuelColor : fuelColor.opacity(isDark ? 0.08 : 0.05))
                    Image(systemName: fuelIcon).font(.system(size: 24, weight: .bold)).foregroundColor(isSelected ? (fuel == .pb95 ? .black : .white) : fuelColor)
                }.frame(height: 70).overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? fuelColor.opacity(0.5) : fuelColor.opacity(0.2), lineWidth: isSelected ? 2 : 1))
                Text(fuel.rawValue.uppercased()).font(.system(size: 10, weight: .black)).foregroundColor(isSelected ? (isDark ? .white : fuelColor) : .gray)
            }.frame(maxWidth: .infinity)
        }.buttonStyle(PlainButtonStyle()).scaleEffect(isSelected ? 1.03 : 1.0).animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    private var fuelIcon: String {
        switch fuel { case .electricity: return "bolt.fill"; case .lpg: return "leaf.fill"; case .adblue: return "drop.fill"; default: return "fuelpump.fill" }
    }
}
