import SwiftUI
import PhotosUI
import UIKit

struct CarFormView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var data: AppData
    @Binding var selectedCarId: UUID?
    let carToEdit: Car?
    
    // MARK: - State
    @State private var name = ""
    @State private var licensePlate = ""
    @State private var selectedType: CarDriveType = .petrol
    @State private var primaryFuel: FuelType = .pb95
    @State private var secondaryFuel: FuelType? = nil
    @State private var hasLPG = false
    
    @State private var selectedImageData: Data? = nil
    @State private var showActionSheet = false
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showDeleteConfirmation = false
    
    // MARK: - Helpers
    private var isDark: Bool { data.selectedTheme == .darkBlue }
    private var bgColor: Color { isDark ? Color(red: 10/255, green: 20/255, blue: 40/255) : Color(red: 245/255, green: 245/255, blue: 247/255) }
    private var rowColor: Color { isDark ? Color(red: 20/255, green: 35/255, blue: 60/255) : .white }
    private var textColor: Color { isDark ? .white : .primary }

    init(data: AppData, selectedCarId: Binding<UUID?>, carToEdit: Car?) {
        self.data = data
        self._selectedCarId = selectedCarId
        self.carToEdit = carToEdit
        
        if let car = carToEdit {
            _name = State(initialValue: car.name)
            _licensePlate = State(initialValue: car.licensePlate)
            _selectedType = State(initialValue: car.type)
            _selectedImageData = State(initialValue: car.imageData)
            _primaryFuel = State(initialValue: car.primaryFuel)
            _secondaryFuel = State(initialValue: car.secondaryFuel)
            _hasLPG = State(initialValue: car.secondaryFuel == .lpg)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                
                Form {
                    Section {
                        Button(action: { showActionSheet = true }) {
                            HStack(spacing: 15) {
                                imagePlaceholder
                                VStack(alignment: .leading) {
                                    Text("Zdjęcie pojazdu").font(.headline).foregroundColor(textColor)
                                    Text(selectedImageData == nil ? "Dodaj" : "Zmień").font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                        }
                    } header: { Text("Wizerunek").foregroundColor(.gray) }
                    .listRowBackground(rowColor)

                    Section {
                        TextField("Nazwa", text: $name).foregroundColor(textColor)
                        TextField("Nr rejestracyjny", text: $licensePlate)
                            .foregroundColor(textColor)
                            .textInputAutocapitalization(.characters)
                    } header: { Text("Podstawowe dane").foregroundColor(.gray) }
                    .listRowBackground(rowColor)
                    
                    Section {
                        HStack(spacing: 8) {
                            TypeSelectButton(title: "BENZYNA", icon: "drop.fill", type: .petrol, selectedType: $selectedType, color: .orange, isDark: isDark)
                            TypeSelectButton(title: "DIESEL", icon: "fuelpump.fill", type: .diesel, selectedType: $selectedType, color: .gray, isDark: isDark)
                            TypeSelectButton(title: "ELEKTRYK", icon: "bolt.fill", type: .electric, selectedType: $selectedType, color: .green, isDark: isDark)
                            TypeSelectButton(title: "PHEV", icon: "leaf.fill", type: .phev, selectedType: $selectedType, color: .blue, isDark: isDark)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    } header: { Text("Rodzaj napędu").foregroundColor(.gray) }
                    .listRowBackground(rowColor)
                    
                    Section {
                        if selectedType == .diesel {
                            HStack {
                                Text("Główne paliwo")
                                Spacer()
                                Text("Diesel (ON)").foregroundColor(.secondary)
                            }
                            .foregroundColor(textColor)
                        } else if selectedType == .electric {
                            HStack {
                                Text("Główne paliwo")
                                Spacer()
                                Text("Prąd").foregroundColor(.secondary)
                            }
                            .foregroundColor(textColor)
                        } else {
                            Picker("Główne paliwo", selection: $primaryFuel) {
                                Text("Benzyna Pb95").tag(FuelType.pb95)
                                Text("Benzyna Pb98").tag(FuelType.pb98)
                            }
                            .tint(.orange)
                        }
                        
                        if selectedType == .petrol {
                            Toggle("Instalacja LPG", isOn: $hasLPG)
                                .tint(.orange)
                        }
                    } header: { Text("Szczegóły paliwa").foregroundColor(.gray) }
                    .listRowBackground(rowColor)

                    if carToEdit != nil {
                        Section {
                            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                                HStack {
                                    Spacer()
                                    Label("Usuń pojazd", systemImage: "trash")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                            }
                        }
                        .listRowBackground(rowColor)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(carToEdit == nil ? "Nowy pojazd" : "Edycja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") { save() }.fontWeight(.bold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
            }
            .confirmationDialog("Wybierz źródło zdjęcia", isPresented: $showActionSheet) {
                Button("Aparat") {
                    self.sourceType = .camera
                    self.showImagePicker = true
                }
                Button("Galeria zdjęć") {
                    self.sourceType = .photoLibrary
                    self.showImagePicker = true
                }
                Button("Anuluj", role: .cancel) { }
            }
            .sheet(isPresented: $showImagePicker) {
                // Xcode znajdzie ImagePicker w Twoim innym pliku automatycznie!
                ImagePicker(image: $selectedImageData, sourceType: sourceType)
            }
            .onChange(of: selectedType) { _, newValue in
                updateDefaultFuel(for: newValue)
            }
            .alert("Usunąć pojazd?", isPresented: $showDeleteConfirmation) {
                Button("Usuń", role: .destructive) { deleteCar() }
                Button("Anuluj", role: .cancel) { }
            } message: {
                Text("Pojazd i wszystkie powiązane wpisy zostaną trwale usunięte.")
            }
        }
    }
    
    // MARK: - Logic (Prywatne funkcje pomocnicze)
    
    private func updateDefaultFuel(for type: CarDriveType) {
        switch type {
        case .diesel:    primaryFuel = .diesel
        case .electric:  primaryFuel = .electricity
        case .petrol, .phev, .phevDiesel:
            if primaryFuel != .pb95 && primaryFuel != .pb98 {
                primaryFuel = .pb95
            }
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            if let data = selectedImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else {
                Color.gray.opacity(0.1)
                Image(systemName: "car.fill").foregroundColor(.gray)
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func deleteCar() {
        guard let car = carToEdit else { return }
        data.logs.removeAll { $0.carId == car.id }
        data.cars.removeAll { $0.id == car.id }
        if selectedCarId == car.id {
            selectedCarId = data.cars.first?.id
        }
        dismiss()
    }

    private func save() {
        let finalSecondaryFuel: FuelType? = (hasLPG && selectedType == .petrol) ? .lpg : nil
        
        if let car = carToEdit, let index = data.cars.firstIndex(where: { $0.id == car.id }) {
            var updatedCar = data.cars[index]
            updatedCar.name = name
            updatedCar.licensePlate = licensePlate.uppercased()
            updatedCar.type = selectedType
            updatedCar.primaryFuel = primaryFuel
            updatedCar.secondaryFuel = finalSecondaryFuel
            updatedCar.imageData = selectedImageData
            data.cars[index] = updatedCar
        } else {
            let newCar = Car(name: name, type: selectedType, primaryFuel: primaryFuel, secondaryFuel: finalSecondaryFuel, licensePlate: licensePlate.uppercased(), imageData: selectedImageData)
            data.cars.append(newCar)
            selectedCarId = newCar.id
        }
        dismiss()
    }
}
