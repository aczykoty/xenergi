import SwiftUI

struct ManageCarsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var data: AppData
    @Binding var selectedCarId: UUID?
    @State private var showingAddForm = false
    @State private var carToEdit: Car? = nil
    
    // MARK: - Inteligentna Paleta
    private var isDark: Bool { data.selectedTheme == .darkBlue }
    private var bgColor: Color { isDark ? Color(red: 10/255, green: 20/255, blue: 40/255) : Color(red: 245/255, green: 245/255, blue: 247/255) }
    private var rowColor: Color { isDark ? Color(red: 20/255, green: 35/255, blue: 60/255) : .white }
    private var primaryText: Color { isDark ? .white : .black }
    private var accentColor: Color { isDark ? .white : .black } // Kolor przycisku głównego

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List {
                    Section(header: Text("Twoje Pojazdy")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isDark ? .white.opacity(0.4) : .gray)
                        .padding(.bottom, 5)) {
                            
                        ForEach(data.cars) { car in
                            Button(action: { carToEdit = car }) {
                                HStack(spacing: 15) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "car.fill")
                                            .foregroundColor(primaryText)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(car.name)
                                            .foregroundColor(primaryText)
                                            .fontWeight(.semibold)
                                        Text(car.licensePlate.isEmpty ? "Brak rejestracji" : car.licensePlate.uppercased())
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(isDark ? .white.opacity(0.2) : .gray.opacity(0.5))
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(rowColor)
                        }
                        .onDelete { data.cars.remove(atOffsets: $0) }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden) // Ukrywa systemowy grafit
                
                // MARK: - NOWOCZESNY PRZYCISK (Dostosowany do motywu)
                Button(action: { showingAddForm = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                        Text("DODAJ NOWY POJAZD")
                    }
                    .font(.system(size: 13, weight: .black))
                    .tracking(1.0)
                    .foregroundColor(isDark ? .black : .white) // Odwrócenie kolorów dla kontrastu
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(accentColor)
                    .cornerRadius(15)
                    .shadow(color: accentColor.opacity(isDark ? 0.3 : 0.2), radius: 15, x: 0, y: 8)
                    .padding(.horizontal, 25)
                    .padding(.bottom, 20)
                }
            }
            .background(bgColor.ignoresSafeArea())
            .navigationTitle("Garaż")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Gotowe") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundColor(isDark ? .white : .black)
                }
            }
            // Zapewniamy, że arkusze też dostaną dane
            // POPRAWIONE WYWOŁANIA
            .sheet(isPresented: $showingAddForm) {
                CarFormView(data: data, selectedCarId: $selectedCarId, carToEdit: nil)
            }
            .sheet(item: $carToEdit) { car in
                CarFormView(data: data, selectedCarId: $selectedCarId, carToEdit: car)
            }
        }
        .preferredColorScheme(isDark ? .dark : .light)
    }
}
