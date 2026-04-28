import SwiftUI

// MARK: - Pitstop Top Bar

struct PitstopTopBar: View {
    var onSettings: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(PitstopColor.textPrimary)
                Text("Pitstop")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(PitstopColor.textPrimary)
            }

            Spacer()

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(PitstopColor.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(PitstopColor.cardSurface)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
            }
            .accessibilityIdentifier(ViewID.settingsButton)
        }
        .accessibilityIdentifier(ViewID.topBar)
    }
}

// MARK: - Vehicle Hero Carousel

struct VehicleHeroCarousel: View {
    let cars: [Car]
    @Binding var selectedCarId: UUID?
    let logs: [LogEntry]
    let currencySymbol: String
    var onRefuel: () -> Void
    var onCharge: () -> Void
    var onEditCar: () -> Void

    private static let peekWidth: CGFloat = 23
    private static let cardSpacing: CGFloat = 12
    private static var sideInset: CGFloat { peekWidth + cardSpacing }

    private var isSingleCard: Bool { cars.count <= 1 }
    private var inset: CGFloat { isSingleCard ? PitstopSpacing.pageHorizontal : Self.sideInset }

    var body: some View {
        GeometryReader { proxy in
            let screenWidth = proxy.size.width
            let cardWidth = screenWidth - 2 * inset

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Self.cardSpacing) {
                    ForEach(cars) { car in
                        let carLogs = logs.filter { $0.carId == car.id }
                        let monthTotal = currentMonthTotal(for: carLogs)

                        VehicleHeroCard(
                            car: car,
                            monthTotal: monthTotal,
                            currencySymbol: currencySymbol,
                            onRefuel: {
                                selectedCarId = car.id
                                onRefuel()
                            },
                            onCharge: {
                                selectedCarId = car.id
                                onCharge()
                            },
                            onTap: {
                                selectedCarId = car.id
                                onEditCar()
                            }
                        )
                        .frame(width: cardWidth)
                        .id(car.id)
                        .accessibilityIdentifier(ViewID.heroCard(car.id))
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(
                                    x: 1 - abs(phase.value) * 0.05,
                                    y: 1 - abs(phase.value) * 0.05
                                )
                                .opacity(1 - abs(phase.value) * 0.15)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selectedCarId, anchor: .center)
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, inset, for: .scrollContent)
        }
        .frame(height: (UIScreen.main.bounds.width - 2 * inset) / VehicleHeroCard.cardRatio)
        .accessibilityIdentifier(ViewID.heroCarousel)
    }

    private func currentMonthTotal(for carLogs: [LogEntry]) -> Double {
        let now = Date()
        let cal = Calendar.current
        return carLogs
            .filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.totalCost }
    }
}

// MARK: - Vehicle Hero Card

struct VehicleHeroCard: View {
    let car: Car
    let monthTotal: Double
    let currencySymbol: String
    var onRefuel: () -> Void
    var onCharge: () -> Void
    var onTap: () -> Void

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        formatter.locale = Locale.current
        return formatter.string(from: Date()).capitalized
    }

    private var driveCategory: DriveCategory {
        switch car.type {
        case .petrol, .diesel: return .ice
        case .electric: return .ev
        case .phev, .phevDiesel: return .phev
        }
    }

    private var driveLabel: String {
        switch car.type {
        case .petrol: return "PETROL"
        case .diesel: return "DIESEL"
        case .electric: return "EV"
        case .phev, .phevDiesel: return "PHEV"
        }
    }

    static let cardRatio: CGFloat = 320.0 / 430.0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / Self.cardRatio

            ZStack {
                heroImage
                    .frame(width: w, height: h)
                    .clipped()

                // Bottom gradient scrim for CTA legibility
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: h * 0.35)
                }

                // Content overlay
                VStack(spacing: 0) {
                    // Glossy header bar
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(car.name)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            if !car.licensePlate.isEmpty {
                                Text(car.licensePlate.uppercased())
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }

                        Spacer()

                        Text(formatCurrency(monthTotal))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 20)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.12), .white.opacity(0.04)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
                    .clipShape(Capsule())

                    Spacer()

                    ctaButtons
                }
                .padding(PitstopSpacing.cardInner * 0.5)
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(Self.cardRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: PitstopRadius.card))
        .onTapGesture { onTap() }
    }

    @ViewBuilder
    private var heroImage: some View {
        if let imageData = car.imageData, let uiImage = UIImage(data: imageData) {
            Color.clear.overlay(
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            )
            .clipped()
        } else {
            ZStack {
                fallbackGradient
                VStack(spacing: 12) {
                    Image(systemName: fallbackIcon)
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                    Text(car.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }

    private var fallbackGradient: some View {
        LinearGradient(
            colors: fallbackColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fallbackColors: [Color] {
        switch driveCategory {
        case .ice: return [Color(hex: 0x2C3E50), Color(hex: 0x4A6274)]
        case .ev: return [Color(hex: 0x1A5632), Color(hex: 0x2D7A4F)]
        case .phev: return [Color(hex: 0x1B3A5C), Color(hex: 0x2D6A9F)]
        }
    }

    private var fallbackIcon: String {
        switch driveCategory {
        case .ice: return "car.fill"
        case .ev: return "bolt.car.fill"
        case .phev: return "leaf.fill"
        }
    }

    private var ctaButtons: some View {
        PitstopCTAButton(
            title: "Refuel",
            icon: "fuelpump.fill",
            action: onRefuel
        )
        .accessibilityIdentifier(ViewID.refuelCTA)
    }

    private func formatCurrency(_ value: Double) -> String {
        String(format: "%.2f %@", value, currencySymbol)
    }
}

enum DriveCategory {
    case ice, ev, phev
}

// MARK: - CTA Button

struct PitstopCTAButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                ZStack {
                    // Blur layer
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)

                    // Gradient overlay for the olive-to-teal glossy tint
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    PitstopColor.ctaOlive.opacity(0.6),
                                    PitstopColor.ctaOlive.opacity(0.3),
                                    Color(hex: 0x5A7A6A).opacity(0.4)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    // Top highlight for gloss
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Page Dots

struct PitstopPageDots: View {
    let count: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                if index == currentIndex {
                    Capsule()
                        .fill(PitstopColor.textPrimary.opacity(0.7))
                        .frame(width: 18, height: 6)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.05))
        .clipShape(Capsule())
        .animation(.snappy(duration: 0.25), value: currentIndex)
        .accessibilityIdentifier(ViewID.pageDots)
    }
}

// MARK: - Breakdowns Section

struct BreakdownsSection: View {
    let year: Int
    let summaries: [(month: String, totalCost: Double, fillupCount: Int, logs: [LogEntry])]
    let currencySymbol: String
    @Binding var expandedMonths: Set<String>
    var onStatsTap: () -> Void
    var onLogTap: (LogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PitstopSpacing.stack) {
            HStack {
                Text("\(String(year)) Breakdowns")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(PitstopColor.textSecondary)
                Spacer()
                Button("Stats") { onStatsTap() }
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(PitstopColor.accentBlue)
                    .accessibilityIdentifier(ViewID.statsLink)
            }
            .padding(.horizontal, PitstopSpacing.pageHorizontal + PitstopSpacing.cardInner)

            ForEach(summaries, id: \.month) { summary in
                MonthBreakdownCard(
                    summary: summary,
                    currencySymbol: currencySymbol,
                    isExpanded: expandedMonths.contains(summary.month),
                    onToggle: {
                        withAnimation(.snappy(duration: 0.25)) {
                            if expandedMonths.contains(summary.month) {
                                expandedMonths.remove(summary.month)
                            } else {
                                expandedMonths.insert(summary.month)
                            }
                        }
                    },
                    onLogTap: onLogTap
                )
                .accessibilityIdentifier(ViewID.monthCard(summary.month))
            }
        }
        .accessibilityIdentifier(ViewID.breakdownsSection)
    }
}

// MARK: - Month Breakdown Card

struct MonthBreakdownCard: View {
    let summary: (month: String, totalCost: Double, fillupCount: Int, logs: [LogEntry])
    let currencySymbol: String
    let isExpanded: Bool
    var onToggle: () -> Void
    var onLogTap: (LogEntry) -> Void

    private var monthName: String {
        summary.month.components(separatedBy: " ").first ?? summary.month
    }

    private var lastTransaction: LogEntry? {
        summary.logs.first
    }

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed header — always visible
            Button(action: onToggle) {
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        Text(monthName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(PitstopColor.accentBlue)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "fuelpump.fill")
                                .font(.system(size: 11))
                                .foregroundColor(PitstopColor.textSecondary)
                            Text("\(summary.fillupCount)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(PitstopColor.textSecondary)
                        }
                        .padding(.trailing, 12)

                        Text(formatCurrency(summary.totalCost))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(PitstopColor.textPrimary)
                    }
                    .padding(.horizontal, PitstopSpacing.cardInner)
                    .padding(.vertical, 14)

                    // Last transaction preview (collapsed only)
                    if !isExpanded, let last = lastTransaction {
                        Divider()
                            .padding(.horizontal, PitstopSpacing.cardInner)

                        HStack {
                            Text(transactionMeta(last))
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(PitstopColor.textSecondary)
                            Spacer()
                            Text(formatCurrency(last.totalCost))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(PitstopColor.textSecondary)
                        }
                        .padding(.horizontal, PitstopSpacing.cardInner)
                        .padding(.vertical, 10)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded transactions
            if isExpanded {
                Divider()
                    .padding(.horizontal, PitstopSpacing.cardInner)

                VStack(spacing: 0) {
                    ForEach(summary.logs) { log in
                        Button(action: { onLogTap(log) }) {
                            BreakdownTransactionRow(
                                log: log,
                                currencySymbol: currencySymbol
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier(ViewID.transactionRow(log.id))

                        if log.id != summary.logs.last?.id {
                            Divider()
                                .padding(.horizontal, PitstopSpacing.cardInner)
                                .opacity(0.5)
                        }
                    }
                }
            }
        }
        .background(PitstopColor.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: PitstopRadius.card))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
        .padding(.horizontal, PitstopSpacing.pageHorizontal)
    }

    private func transactionMeta(_ log: LogEntry) -> String {
        let df = DateFormatter()
        df.dateFormat = "dd.MM"
        let date = df.string(from: log.date)

        let tf = DateFormatter()
        tf.dateFormat = "h:mma"
        tf.amSymbol = "am"
        tf.pmSymbol = "pm"
        let time = tf.string(from: log.date)

        let amount = String(format: "%.0fL", log.amount)
        return "\(date), \(time), \(amount)"
    }

    private func formatCurrency(_ value: Double) -> String {
        String(format: "%.2f %@", value, currencySymbol)
    }
}

// MARK: - Breakdown Transaction Row

struct BreakdownTransactionRow: View {
    @EnvironmentObject var data: AppData
    let log: LogEntry
    let currencySymbol: String

    private var fuelInfo: (name: String, color: Color) {
        let type = log.fuelType ?? .pb95
        let label = type.label(for: data.selectedUnitSystem).uppercased()

        switch type {
        case .pb95: return (label, Color(hex: 0xFFBE00))
        case .pb98: return (label, .red)
        case .diesel: return (label, Color(hex: 0x333333))
        case .lpg: return (label, .blue)
        case .electricity: return ("EV", .green)
        case .adblue: return (label, .cyan)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Fuel icon
            ZStack {
                Circle()
                    .fill(fuelInfo.color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: log.type == .charge ? "bolt.fill" : "fuelpump.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(fuelInfo.color)
            }

            // Grade chip + date
            VStack(alignment: .leading, spacing: 4) {
                Text(fuelInfo.name)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(fuelInfo.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(fuelInfo.color.opacity(0.1))
                    .cornerRadius(PitstopRadius.chip)

                Text(log.date, style: .date)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(PitstopColor.textSecondary)
            }

            Spacer()

            // Cost + amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f %@", log.totalCost, currencySymbol))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(PitstopColor.textPrimary)

                Text(String(format: "%.1f %@", log.amount, log.fuelType?.unit(for: data.selectedUnitSystem) ?? "L"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(PitstopColor.textSecondary)
            }
        }
        .padding(.horizontal, PitstopSpacing.cardInner)
        .padding(.vertical, 10)
    }
}

// MARK: - Shared Components (used by other views)

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
