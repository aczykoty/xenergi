import SwiftUI

// MARK: - Pitstop Top Bar

struct PitstopTopBar: View {
    @EnvironmentObject var data: AppData
    var onSettings: () -> Void

    private var isDark: Bool { data.selectedTheme == .darkBlue }

    var body: some View {
        HStack {
            Image(isDark ? "LogoPitstopWhite" : "LogoPitstopBlack")
                .resizable()
                .scaledToFit()
                .frame(height: 24)

            Spacer()

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDark ? .gray : PitstopColor.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(isDark ? Color(red: 20/255, green: 35/255, blue: 60/255) : PitstopColor.cardSurface)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.06), radius: 8, y: 2)
            }
            .accessibilityIdentifier(ViewID.settingsButton)
        }
        .accessibilityIdentifier(ViewID.topBar)
    }
}

// MARK: - Vehicle Hero Carousel

struct VehicleHeroCarousel: View {
    let screenWidth: CGFloat
    let scrollOffset: CGFloat
    var overscroll: CGFloat = 0
    let cars: [Car]
    @Binding var selectedCarId: UUID?
    let logs: [LogEntry]
    let currencySymbol: String
    var onRefuel: () -> Void
    var onCharge: () -> Void
    var onEditCar: () -> Void
    var onCurrentMonth: (UUID) -> Void

    private static let peekWidth: CGFloat = 24
    private static let cardSpacing: CGFloat = 2
    private static let expandedSideInset: CGFloat = peekWidth + cardSpacing
    // Minimum side margin when the card is fully widened (no peek).
    private static let collapsedSideInset: CGFloat = 16
    // Card collapses to a height that still fits the title capsule, a strip of
    // hero image, and the Refuel button anchored to the bottom edge.
    static let collapsedHeight: CGFloat = 260

    // Static side inset — horizontal scroll layout stays fixed regardless of
    // vertical scroll progress. The width grow effect is applied as a
    // separate scaleEffect on each card so it can't disrupt the horizontal
    // scroll position or shift the centered card off-axis.
    private var sideInset: CGFloat { Self.expandedSideInset }

    private var cardWidth: CGFloat { screenWidth - 2 * sideInset }

    // How much wider the centered card should appear at full vertical scroll.
    private var cardWidthScale: CGFloat {
        let targetWidth = screenWidth - 2 * Self.collapsedSideInset
        let baseWidth = screenWidth - 2 * Self.expandedSideInset
        guard baseWidth > 0 else { return 1 }
        let maxScale = targetWidth / baseWidth
        return 1 + (maxScale - 1) * widthProgress
    }

    var collapseDistance: CGFloat {
        max(expandedHeight - Self.collapsedHeight, 1)
    }

    var scrollProgress: CGFloat {
        min(max(scrollOffset / collapseDistance, 0), 1)
    }

    // Sibling fade runs in the first half of the scroll progress so peek
    // cards are gone by the time the width starts widening.
    private var siblingFadeProgress: CGFloat {
        min(scrollProgress * 2, 1)
    }

    // Width animation kicks in only after siblings are mostly faded.
    private var widthProgress: CGFloat {
        max((scrollProgress - 0.5) * 2, 0)
    }

    // Use the static expanded layout to compute the natural full height —
    // height shouldn't depend on the dynamic sideInset (we animate height
    // independently via effectiveHeight).
    var expandedHeight: CGFloat {
        let baseWidth = screenWidth - 2 * Self.expandedSideInset
        return baseWidth / VehicleHeroCard.cardRatio
    }

    var effectiveHeight: CGFloat {
        expandedHeight + (Self.collapsedHeight - expandedHeight) * scrollProgress
    }

    // Height- AND velocity-independent rubber-band so the bounce feels the
    // same regardless of card size, list length, or fling speed.
    // We square-root-compress the input so a hard fling doesn't produce a
    // proportionally larger bounce than a gentle pull, then clamp the output
    // to a small fixed maximum.
    private var rubberBandOffset: CGFloat {
        let sign: CGFloat = overscroll < 0 ? -1 : 1
        let normalized = min(abs(overscroll) / 60, 1)        // saturates by 60pt of input
        let damped = sqrt(normalized)                         // non-linear compression
        let maxOut: CGFloat = sign < 0 ? 12 : 6               // top stretch a bit more visible than bottom
        return -sign * damped * maxOut
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: Self.cardSpacing) {
                ForEach(cars) { car in
                    let carLogs = logs.filter { $0.carId == car.id }
                    let monthTotal = currentMonthTotal(for: carLogs)

                    VehicleHeroCard(
                        car: car,
                        monthTotal: monthTotal,
                        currencySymbol: currencySymbol,
                        fullHeight: expandedHeight,
                        visibleHeight: effectiveHeight,
                        onRefuel: {
                            selectedCarId = car.id
                            onRefuel()
                        },
                        onCharge: {
                            selectedCarId = car.id
                            onCharge()
                        },
                        onTitleTap: {
                            selectedCarId = car.id
                            onEditCar()
                        },
                        onTotalTap: {
                            selectedCarId = car.id
                            onCurrentMonth(car.id)
                        }
                    )
                    .frame(width: cardWidth, height: effectiveHeight)
                    // Width-grow is a per-card horizontal scale anchored to
                    // center, fully independent from horizontal scroll layout.
                    .scaleEffect(x: cardWidthScale, y: 1, anchor: .center)
                    .id(car.id)
                    .accessibilityIdentifier(ViewID.heroCard(car.id))
                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                        // Sibling fade runs in the first half of the scroll
                        // (siblingFadeProgress) so peek cards are gone before
                        // the width transition begins.
                        let siblingFade = abs(phase.value) * siblingFadeProgress
                        return content
                            .scaleEffect(
                                x: 1 - abs(phase.value) * 0.1,
                                y: 1 - abs(phase.value) * 0.1
                            )
                            .opacity((1 - abs(phase.value) * 0.15) * (1 - siblingFade))
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selectedCarId, anchor: .center)
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, sideInset, for: .scrollContent)
        .frame(height: effectiveHeight)
        // Height-independent rubber-band: translate vertically by a fixed
        // pixel offset so all cards feel the same regardless of size.
        .offset(y: rubberBandOffset)
        .animation(.spring(response: 0.45, dampingFraction: 0.65), value: rubberBandOffset)
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
    let fullHeight: CGFloat
    let visibleHeight: CGFloat
    var onRefuel: () -> Void
    var onCharge: () -> Void
    var onTitleTap: () -> Void
    var onTotalTap: () -> Void

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

    // 0 when fully expanded, 1 when fully collapsed.
    private var collapseProgress: CGFloat {
        guard fullHeight > 0 else { return 0 }
        return min(max((fullHeight - visibleHeight) / fullHeight, 0), 1)
    }

    var body: some View {
        let inset = PitstopSpacing.cardInner * 0.5

        ZStack(alignment: .top) {
            // Hero image — always sized to the visible area and centered, so
            // the car stays in the middle of the card as it collapses.
            // A subtle zoom on collapse keeps the subject prominent.
            heroImage
                .frame(maxWidth: .infinity)
                .frame(height: visibleHeight)
                .scaleEffect(1 + collapseProgress * 0.08)
                .clipShape(RoundedRectangle(cornerRadius: PitstopRadius.card))

            // Bottom gradient sized to the visible area.
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: visibleHeight * 0.35)
            }
            .frame(height: visibleHeight)
            .clipShape(RoundedRectangle(cornerRadius: PitstopRadius.card))
            .allowsHitTesting(false)

            // Title capsule pinned to the top.
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(car.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        if !car.licensePlate.isEmpty {
                            Text(car.licensePlate.uppercased())
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { onTitleTap() }

                    Spacer(minLength: 8)

                    Text(formatCurrency(monthTotal))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { onTotalTap() }
                }
                .padding(.horizontal, 20)
                .frame(height: 64)
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
            }
            .padding(inset)

            // Refuel button anchored to the visible bottom edge.
            VStack {
                Spacer()
                ctaButtons
                    .padding(.horizontal, inset)
                    .padding(.bottom, inset)
            }
            .frame(height: visibleHeight)
        }
        .frame(height: visibleHeight)
        .contentShape(RoundedRectangle(cornerRadius: PitstopRadius.card))
        .onTapGesture { onRefuel() }
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
    @EnvironmentObject var data: AppData
    let count: Int
    let currentIndex: Int

    private var isDark: Bool { data.selectedTheme == .darkBlue }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                if index == currentIndex {
                    Capsule()
                        .fill(isDark ? Color.white.opacity(0.7) : PitstopColor.textPrimary.opacity(0.7))
                        .frame(width: 18, height: 6)
                } else {
                    Circle()
                        .fill(isDark ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
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
    var baseIndex: Int = 0
    var appeared: Bool = true
    var onStatsTap: () -> Void
    var onMonthTap: ((month: String, totalCost: Double, fillupCount: Int, logs: [LogEntry])) -> Void

    private let cardPadding: CGFloat = 20
    // 60ms between adjacent items so the cascade reads clearly without
    // dragging on long lists.
    private let perItemDelay: Double = 0.06

    var body: some View {
        VStack(alignment: .leading, spacing: PitstopSpacing.stack) {
            HStack {
                Text("Summary \(String(year))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
                Button("Stats") { onStatsTap() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(PitstopColor.accentBlue)
                    .accessibilityIdentifier(ViewID.statsLink)
            }
            .padding(.horizontal, PitstopSpacing.pageHorizontal + cardPadding)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(staggerAnimation(globalIndex: baseIndex), value: appeared)

            ForEach(Array(summaries.enumerated()), id: \.element.month) { localIndex, summary in
                let globalIndex = baseIndex + localIndex + 1
                MonthBreakdownCard(
                    summary: summary,
                    currencySymbol: currencySymbol,
                    showLastTransaction: isCurrentMonth(summary),
                    onTap: { onMonthTap(summary) }
                )
                .accessibilityIdentifier(ViewID.monthCard(summary.month))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(staggerAnimation(globalIndex: globalIndex), value: appeared)
            }
        }
        .accessibilityIdentifier(ViewID.breakdownsSection)
    }

    private func isCurrentMonth(_ summary: (month: String, totalCost: Double, fillupCount: Int, logs: [LogEntry])) -> Bool {
        guard let firstLog = summary.logs.first else { return false }
        return Calendar.current.isDate(firstLog.date, equalTo: Date(), toGranularity: .month)
    }

    // Forward stagger when entering (top → bottom), reverse when leaving so
    // items closest to the bottom slide out first.
    private func staggerAnimation(globalIndex: Int) -> Animation {
        let delay = Double(globalIndex) * perItemDelay
        if appeared {
            return .spring(response: 0.55, dampingFraction: 0.85).delay(delay)
        } else {
            // Out is lighter than the in but still pronounced enough to read.
            return .easeIn(duration: 0.28).delay(delay * 0.6)
        }
    }
}

// MARK: - Month Breakdown Card

struct MonthBreakdownCard: View {
    @EnvironmentObject var data: AppData
    let summary: (month: String, totalCost: Double, fillupCount: Int, logs: [LogEntry])
    let currencySymbol: String
    var showLastTransaction: Bool = true
    var onTap: () -> Void

    private let cardPadding: CGFloat = 20
    private var isDark: Bool { data.selectedTheme == .darkBlue }
    private var cardColor: Color { isDark ? Color(red: 20/255, green: 35/255, blue: 60/255) : PitstopColor.cardSurface }
    private var primaryText: Color { isDark ? .white : PitstopColor.textPrimary }
    private var secondaryText: Color { isDark ? .gray : PitstopColor.textSecondary }

    private var monthName: String {
        summary.month.components(separatedBy: " ").first ?? summary.month
    }

    private var lastTransaction: LogEntry? {
        summary.logs.first
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Text(monthName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PitstopColor.accentBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(formatCurrency(summary.totalCost))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(primaryText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, cardPadding)
                .padding(.vertical, 16)

                if showLastTransaction, let last = lastTransaction {
                    HStack(spacing: 8) {
                        Text("NEW")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                            )
                        Text(transactionMeta(last))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(secondaryText)
                        Spacer()
                        Text(formatCurrency(last.totalCost))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(secondaryText)
                    }
                    .padding(.horizontal, cardPadding)
                    .padding(.bottom, 12)
                }
            }
            .padding(.vertical, 10)
            .background(cardColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .clipShape(RoundedRectangle(cornerRadius: PitstopRadius.card))
        .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.04), radius: 8, y: 4)
        .padding(.horizontal, PitstopSpacing.pageHorizontal)
    }

    private func transactionMeta(_ log: LogEntry) -> String {
        let day = Calendar.current.component(.day, from: log.date)
        let ordinal = dayOrdinal(day)

        let tf = DateFormatter()
        tf.dateFormat = "h:mma"
        tf.amSymbol = "am"
        tf.pmSymbol = "pm"
        let time = tf.string(from: log.date)

        let unit = log.fuelType?.unit(for: data.selectedUnitSystem) ?? "L"
        let amount = String(format: "%.0f%@", log.amount, unit)
        let fuelName = log.fuelType?.label(for: data.selectedUnitSystem) ?? ""
        return "\(ordinal), \(time), \(amount) \(fuelName)"
    }

    private func dayOrdinal(_ day: Int) -> String {
        let suffix: String
        switch day {
        case 11, 12, 13: suffix = "th"
        default:
            switch day % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(day)\(suffix)"
    }

    private func formatCurrency(_ value: Double) -> String {
        String(format: "%.2f %@", value, currencySymbol)
    }
}

// MARK: - Month Transactions Sheet

struct MonthTransactionsSheet: View {
    @EnvironmentObject var data: AppData
    let month: String
    let logs: [LogEntry]
    let currencySymbol: String
    @State private var logToEdit: LogEntry? = nil

    private var isDark: Bool { data.selectedTheme == .darkBlue }
    private var bgColor: Color { isDark ? Color(red: 10/255, green: 18/255, blue: 30/255) : PitstopColor.background }
    private var cardColor: Color { isDark ? Color(red: 20/255, green: 35/255, blue: 60/255) : PitstopColor.cardSurface }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(logs) { log in
                        Button(action: { logToEdit = log }) {
                            BreakdownTransactionRow(
                                log: log,
                                currencySymbol: currencySymbol
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        if log.id != logs.last?.id {
                            Divider()
                                .padding(.horizontal, 20)
                                .opacity(isDark ? 0.3 : 0.5)
                        }
                    }
                }
                .background(cardColor)
                .clipShape(RoundedRectangle(cornerRadius: PitstopRadius.card))
                .padding(.horizontal, PitstopSpacing.pageHorizontal)
                .padding(.top, 16)
            }
            .background(bgColor.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Text(month)
                            .font(.headline)
                        HStack(spacing: 4) {
                            Image(systemName: "fuelpump.fill")
                                .font(.system(size: 11))
                            Text("\(logs.count)")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(isDark ? .dark : .light)
        .sheet(item: $logToEdit) { log in
            EditEntryView(data: data, logToEdit: log)
        }
    }
}

// MARK: - Breakdown Transaction Row

struct BreakdownTransactionRow: View {
    @EnvironmentObject var data: AppData
    let log: LogEntry
    let currencySymbol: String

    private var isDark: Bool { data.selectedTheme == .darkBlue }
    private var primaryText: Color { isDark ? .white : PitstopColor.textPrimary }
    private var secondaryText: Color { isDark ? .gray : PitstopColor.textSecondary }

    private var fuelInfo: (name: String, color: Color) {
        let type = log.fuelType ?? .pb95
        let label = type.label(for: data.selectedUnitSystem).uppercased()

        switch type {
        case .pb95: return (label, Color(hex: 0xFFBE00))
        case .pb98: return (label, .red)
        case .diesel: return (label, isDark ? Color(white: 0.85) : Color(hex: 0x333333))
        case .lpg: return (label, .blue)
        case .electricity: return ("EV", .green)
        case .adblue: return (label, .cyan)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(fuelInfo.color.opacity(isDark ? 0.2 : 0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: log.type == .charge ? "bolt.fill" : "fuelpump.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(fuelInfo.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(fuelInfo.name)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(fuelInfo.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(fuelInfo.color.opacity(isDark ? 0.2 : 0.1))
                    .cornerRadius(PitstopRadius.chip)

                Text(log.date, style: .date)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f %@", log.totalCost, currencySymbol))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(primaryText)

                Text(String(format: "%.1f %@", log.amount, log.fuelType?.unit(for: data.selectedUnitSystem) ?? "L"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(secondaryText)
            }
        }
        .padding(.horizontal, PitstopSpacing.cardInner)
        .padding(.vertical, 20)
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
