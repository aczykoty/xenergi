import SwiftUI
import CoreLocation
import MapKit
import Combine

// MARK: - HUD SERVICE

@MainActor
class HUDService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()

    @Published var speed: Double = 0
    @Published var heading: Double = 0
    @Published var currentInstruction: String = ""
    @Published var distanceToNextTurn: Double = 0
    @Published var turnDirection: TurnDirection = .straight
    @Published var routeActive = false
    @Published var destinationName: String = ""

    private var routeSteps: [MKRoute.Step] = []
    private var currentStepIndex = 0

    enum TurnDirection {
        case left, right, slightLeft, slightRight, straight, uTurn, arrive

        var symbolName: String {
            switch self {
            case .left: return "arrow.turn.up.left"
            case .right: return "arrow.turn.up.right"
            case .slightLeft: return "arrow.up.left"
            case .slightRight: return "arrow.up.right"
            case .straight: return "arrow.up"
            case .uTurn: return "arrow.uturn.down"
            case .arrive: return "flag.checkered"
            }
        }
    }

    var compassDirection: String {
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading + 22.5).truncatingRemainder(dividingBy: 360) / 45.0)
        return dirs[max(0, min(index, 7))]
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .automotiveNavigation
    }

    func start() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    func navigateTo(_ mapItem: MKMapItem) {
        destinationName = mapItem.name ?? "Cel"
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = mapItem
        request.transportType = .automobile

        Task {
            do {
                let response = try await MKDirections(request: request).calculate()
                guard let route = response.routes.first else { return }
                self.routeSteps = route.steps.filter { !$0.instructions.isEmpty }
                self.currentStepIndex = 0
                self.routeActive = true
                self.updateCurrentStep()
            } catch {
                print("Route error: \(error)")
            }
        }
    }

    func clearRoute() {
        routeSteps = []
        currentStepIndex = 0
        routeActive = false
        currentInstruction = ""
        distanceToNextTurn = 0
        turnDirection = .straight
        destinationName = ""
    }

    private func updateCurrentStep() {
        guard currentStepIndex < routeSteps.count else {
            turnDirection = .arrive
            currentInstruction = "Cel osiągnięty"
            distanceToNextTurn = 0
            return
        }
        let step = routeSteps[currentStepIndex]
        currentInstruction = step.instructions
        distanceToNextTurn = step.distance
        turnDirection = parseTurn(step.instructions)
    }

    private func parseTurn(_ text: String) -> TurnDirection {
        let l = text.lowercased()
        if l.contains("zawróć") || l.contains("u-turn") { return .uTurn }
        if l.contains("lekko") && l.contains("lewo") || l.contains("slight left") || l.contains("bear left") { return .slightLeft }
        if l.contains("lekko") && l.contains("prawo") || l.contains("slight right") || l.contains("bear right") { return .slightRight }
        if l.contains("lewo") || l.contains("left") { return .left }
        if l.contains("prawo") || l.contains("right") { return .right }
        if l.contains("cel") || l.contains("destination") || l.contains("dotar") { return .arrive }
        return .straight
    }

    fileprivate func handleLocationUpdate(_ location: CLLocation) {
        speed = location.speed > 0 ? location.speed * 3.6 : 0

        guard routeActive, currentStepIndex < routeSteps.count else { return }
        let step = routeSteps[currentStepIndex]
        let polyline = step.polyline
        let count = polyline.pointCount
        guard count > 0 else { return }

        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: count)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))

        let stepEnd = CLLocation(latitude: coords[count - 1].latitude, longitude: coords[count - 1].longitude)
        distanceToNextTurn = location.distance(from: stepEnd)

        if distanceToNextTurn < 40 {
            currentStepIndex += 1
            updateCurrentStep()
        }
    }

    fileprivate func handleHeadingUpdate(_ newHeading: CLHeading) {
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }
}

extension HUDService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.handleLocationUpdate(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in self.handleHeadingUpdate(newHeading) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

// MARK: - HUD PALETTE

struct HUDPalette {
    let background: Color
    let speed: Color
    let speedLabel: Color
    let glow: Color
    let navAccent: Color
    let navText: Color
    let compass: Color
    let buttonFg: Color
    let buttonBg: Color
    let panelBg: Color
    let mapTint: Color
    let mapOpacity: Double
}

// MARK: - HUD THEMES

enum HUDTheme: String, CaseIterable {
    case classic  = "CLASSIC"
    case sonar    = "SONAR"
    case nightOps = "NOCS"
    case sport    = "SPORT"
    case tesla    = "TESLA"
    case bright   = "BRIGHT"

    var icon: String {
        switch self {
        case .classic:  return "circle.hexagongrid"
        case .sonar:    return "waveform"
        case .nightOps: return "moon.stars.fill"
        case .sport:    return "gauge.open.with.lines.needle.33percent.and.arrowtriangle"
        case .tesla:    return "bolt.fill"
        case .bright:   return "sun.max.fill"
        }
    }

    var next: HUDTheme {
        let all = HUDTheme.allCases
        let idx = all.firstIndex(of: self)!
        return all[(idx + 1) % all.count]
    }

    func palette(dayMode: Bool) -> HUDPalette {
        dayMode ? dayPalette : nightPalette
    }

    // MARK: Night palettes

    private var nightPalette: HUDPalette {
        switch self {
        case .classic:
            return HUDPalette(
                background: .black,
                speed: .white,
                speedLabel: .white.opacity(0.35),
                glow: .clear,
                navAccent: .cyan,
                navText: .white.opacity(0.6),
                compass: .green,
                buttonFg: .white.opacity(0.8),
                buttonBg: .white.opacity(0.12),
                panelBg: .white.opacity(0.06),
                mapTint: Color(white: 0.7),
                mapOpacity: 0.45
            )
        case .sonar:
            let g = Color(red: 0, green: 1, blue: 0.25)
            return HUDPalette(
                background: .black,
                speed: g,
                speedLabel: g.opacity(0.35),
                glow: g.opacity(0.15),
                navAccent: Color(red: 0.2, green: 1, blue: 0.5),
                navText: g.opacity(0.5),
                compass: g,
                buttonFg: g.opacity(0.8),
                buttonBg: g.opacity(0.1),
                panelBg: g.opacity(0.06),
                mapTint: g,
                mapOpacity: 0.50
            )
        case .nightOps:
            let r = Color(red: 1, green: 0.1, blue: 0.1)
            return HUDPalette(
                background: .black,
                speed: r,
                speedLabel: r.opacity(0.35),
                glow: .clear,
                navAccent: Color(red: 1, green: 0.25, blue: 0.2),
                navText: r.opacity(0.5),
                compass: Color(red: 1, green: 0.2, blue: 0.15),
                buttonFg: Color(red: 1, green: 0.2, blue: 0.15).opacity(0.8),
                buttonBg: r.opacity(0.1),
                panelBg: Color(red: 1, green: 0.05, blue: 0.05).opacity(0.08),
                mapTint: Color(red: 1, green: 0.2, blue: 0.1),
                mapOpacity: 0.35
            )
        case .sport:
            let o = Color(red: 1, green: 0.42, blue: 0)
            let b = Color(red: 0, green: 0.75, blue: 1)
            return HUDPalette(
                background: .black,
                speed: o,
                speedLabel: o.opacity(0.35),
                glow: o.opacity(0.2),
                navAccent: b,
                navText: .white.opacity(0.65),
                compass: Color(red: 1, green: 0.84, blue: 0),
                buttonFg: Color(red: 1, green: 0.55, blue: 0.1).opacity(0.9),
                buttonBg: o.opacity(0.12),
                panelBg: b.opacity(0.06),
                mapTint: Color(red: 0, green: 0.65, blue: 1),
                mapOpacity: 0.45
            )
        case .tesla:
            return HUDPalette(
                background: .black,
                speed: .white,
                speedLabel: .white.opacity(0.3),
                glow: Color(red: 0.4, green: 0.8, blue: 1).opacity(0.12),
                navAccent: Color(red: 0.3, green: 0.7, blue: 1),
                navText: .white.opacity(0.5),
                compass: .white.opacity(0.7),
                buttonFg: .white.opacity(0.7),
                buttonBg: .white.opacity(0.08),
                panelBg: .white.opacity(0.05),
                mapTint: Color(red: 0.5, green: 0.7, blue: 1),
                mapOpacity: 0.35
            )
        case .bright:
            return HUDPalette(
                background: .white,
                speed: .black,
                speedLabel: .black.opacity(0.4),
                glow: .clear,
                navAccent: Color(red: 0, green: 0.3, blue: 0.7),
                navText: .black.opacity(0.6),
                compass: Color(red: 0.1, green: 0.45, blue: 0.2),
                buttonFg: .black.opacity(0.7),
                buttonBg: .black.opacity(0.1),
                panelBg: .black.opacity(0.06),
                mapTint: Color(white: 0.3),
                mapOpacity: 0.12
            )
        }
    }

    // MARK: Day palettes (high contrast for windshield in sunlight)

    private var dayPalette: HUDPalette {
        switch self {
        case .classic:
            return HUDPalette(
                background: .black,
                speed: .white,
                speedLabel: .white.opacity(0.55),
                glow: .white.opacity(0.3),
                navAccent: Color(red: 0, green: 1, blue: 1),
                navText: .white.opacity(0.85),
                compass: Color(red: 0.2, green: 1, blue: 0.4),
                buttonFg: .white,
                buttonBg: .white.opacity(0.2),
                panelBg: .white.opacity(0.1),
                mapTint: Color(white: 0.9),
                mapOpacity: 0.55
            )
        case .sonar:
            let g = Color(red: 0, green: 1, blue: 0.3)
            return HUDPalette(
                background: .black,
                speed: g,
                speedLabel: g.opacity(0.55),
                glow: g.opacity(0.35),
                navAccent: Color(red: 0.1, green: 1, blue: 0.5),
                navText: g.opacity(0.75),
                compass: g,
                buttonFg: g,
                buttonBg: g.opacity(0.18),
                panelBg: g.opacity(0.1),
                mapTint: Color(red: 0, green: 1, blue: 0.25),
                mapOpacity: 0.60
            )
        case .nightOps:
            let a = Color(red: 1, green: 0.8, blue: 0)
            return HUDPalette(
                background: .black,
                speed: a,
                speedLabel: a.opacity(0.5),
                glow: a.opacity(0.25),
                navAccent: Color(red: 1, green: 0.9, blue: 0.2),
                navText: a.opacity(0.7),
                compass: Color(red: 1, green: 0.75, blue: 0.1),
                buttonFg: a.opacity(0.9),
                buttonBg: Color(red: 1, green: 0.7, blue: 0).opacity(0.15),
                panelBg: a.opacity(0.08),
                mapTint: Color(red: 1, green: 0.7, blue: 0.1),
                mapOpacity: 0.40
            )
        case .sport:
            let o = Color(red: 1, green: 0.5, blue: 0)
            let b = Color(red: 0, green: 0.85, blue: 1)
            return HUDPalette(
                background: .black,
                speed: o,
                speedLabel: o.opacity(0.55),
                glow: o.opacity(0.4),
                navAccent: b,
                navText: .white.opacity(0.85),
                compass: Color(red: 1, green: 0.9, blue: 0),
                buttonFg: Color(red: 1, green: 0.6, blue: 0.1),
                buttonBg: o.opacity(0.18),
                panelBg: b.opacity(0.1),
                mapTint: Color(red: 0, green: 0.7, blue: 1),
                mapOpacity: 0.55
            )
        case .tesla:
            return HUDPalette(
                background: .black,
                speed: .white,
                speedLabel: .white.opacity(0.55),
                glow: Color(red: 0.3, green: 0.85, blue: 1).opacity(0.3),
                navAccent: Color(red: 0.2, green: 0.65, blue: 1),
                navText: .white.opacity(0.75),
                compass: .white.opacity(0.9),
                buttonFg: .white.opacity(0.9),
                buttonBg: .white.opacity(0.15),
                panelBg: .white.opacity(0.08),
                mapTint: Color(red: 0.5, green: 0.8, blue: 1),
                mapOpacity: 0.50
            )
        case .bright:
            return HUDPalette(
                background: .white,
                speed: .black,
                speedLabel: .black.opacity(0.5),
                glow: .clear,
                navAccent: Color(red: 0, green: 0.25, blue: 0.65),
                navText: .black.opacity(0.7),
                compass: Color(red: 0.1, green: 0.4, blue: 0.15),
                buttonFg: .black.opacity(0.8),
                buttonBg: .black.opacity(0.12),
                panelBg: .black.opacity(0.08),
                mapTint: Color(white: 0.3),
                mapOpacity: 0.08
            )
        }
    }
}

// MARK: - HUD VIEW

struct HUDView: View {
    @StateObject private var service = HUDService()
    @State private var showSearch = false
    @State private var showDisclaimer = true
    @State private var isDayMode = false
    @State private var mapPosition: MapCameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
    @AppStorage("hudTheme") private var themeRaw: String = HUDTheme.classic.rawValue
    @Environment(\.dismiss) var dismiss

    private var theme: HUDTheme {
        HUDTheme(rawValue: themeRaw) ?? .classic
    }

    private var palette: HUDPalette {
        theme.palette(dayMode: isDayMode)
    }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            mapBackground

            hudContent
                .scaleEffect(x: -1, y: 1)
        }
        .onAppear {
            service.start()
            UIApplication.shared.isIdleTimerDisabled = true
            isDayMode = UIScreen.main.brightness > 0.4
        }
        .onDisappear {
            service.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.brightnessDidChangeNotification)) { _ in
            let day = UIScreen.main.brightness > 0.4
            if day != isDayMode {
                withAnimation(.easeInOut(duration: 0.6)) { isDayMode = day }
            }
        }
        .sheet(isPresented: $showSearch) {
            DestinationSearchView { mapItem in
                service.navigateTo(mapItem)
                showSearch = false
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .alert("⚠️ Safety Warning", isPresented: $showDisclaimer) {
            Button("I Understand") {}
        } message: {
            Text("This HUD is for informational purposes only. Always keep your eyes on the road. The driver is fully responsible for safe vehicle operation at all times. Do not adjust settings while driving.")
        }
    }

    private var mapBackground: some View {
        Map(position: $mapPosition, interactionModes: []) {}
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
            .mapControls {}
            .environment(\.colorScheme, .dark)
            .allowsHitTesting(false)
            .saturation(0)
            .colorMultiply(palette.mapTint)
            .opacity(palette.mapOpacity)
            .mask(
                RadialGradient(
                    colors: [.white, .white.opacity(0.8), .white.opacity(0.4), .clear],
                    center: .center,
                    startRadius: 120,
                    endRadius: 350
                )
            )
            .scaleEffect(x: -1, y: 1)
            .ignoresSafeArea()
    }

    private var hudContent: some View {
        VStack(spacing: 0) {
            if service.routeActive {
                navigationPanel
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
            }

            Spacer()

            ZStack {
                Text("\(Int(service.speed))")
                    .font(.system(size: 180, weight: .thin, design: .rounded))
                    .foregroundColor(palette.glow)
                    .blur(radius: 30)

                VStack(spacing: -4) {
                    Text("\(Int(service.speed))")
                        .font(.system(size: 180, weight: .thin, design: .rounded))
                        .foregroundColor(palette.speed)
                        .monospacedDigit()

                    Text("km/h")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(palette.speedLabel)
                }
            }

            Spacer()

            bottomBar
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
    }

    private var navigationPanel: some View {
        HStack(spacing: 16) {
            Image(systemName: service.turnDirection.symbolName)
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(palette.navAccent)

            VStack(alignment: .leading, spacing: 4) {
                Text(formatDistance(service.distanceToNextTurn))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(palette.navAccent)
                    .monospacedDigit()

                Text(service.currentInstruction)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(palette.navText)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(palette.panelBg)
        .cornerRadius(14)
    }

    private var bottomBar: some View {
        HStack {
            VStack(spacing: 2) {
                Image(systemName: "location.north.fill")
                    .rotationEffect(.degrees(-service.heading))
                    .font(.system(size: 18))
                    .foregroundColor(palette.compass)
                Text(service.compassDirection)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(palette.compass.opacity(0.8))
            }
            .frame(width: 44)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    themeRaw = theme.next.rawValue
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: theme.icon).font(.system(size: 14))
                    Text(theme.rawValue)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1.5)
                }
                .foregroundColor(palette.buttonFg)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(palette.buttonBg)
                .cornerRadius(8)
            }

            Spacer()

            Button {
                if service.routeActive { service.clearRoute() }
                else { showSearch = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: service.routeActive ? "xmark.circle.fill" : "magnifyingglass")
                    Text(service.routeActive ? "ZAKOŃCZ" : "NAWIGUJ")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                }
                .foregroundColor(palette.buttonFg)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(palette.buttonBg)
                .cornerRadius(10)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(palette.speed.opacity(0.2))
            }
            .frame(width: 44)
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 { return String(format: "%.1f km", meters / 1000) }
        return "\(Int(meters)) m"
    }
}

// MARK: - DESTINATION SEARCH

struct DestinationSearchView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var completer = SearchCompleter()
    @State private var searchText = ""
    let onSelect: (MKMapItem) -> Void

    var body: some View {
        NavigationStack {
            List(completer.results, id: \.self) { result in
                Button {
                    Task { await selectResult(result) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.title).fontWeight(.medium)
                        if !result.subtitle.isEmpty {
                            Text(result.subtitle).font(.caption).foregroundColor(.gray)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Szukaj celu podróży...")
            .onChange(of: searchText) { _, newValue in
                completer.search(newValue)
            }
            .navigationTitle("Nawigacja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
            }
        }
    }

    private func selectResult(_ result: MKLocalSearchCompletion) async {
        let request = MKLocalSearch.Request(completion: result)
        if let response = try? await MKLocalSearch(request: request).start(),
           let item = response.mapItems.first {
            onSelect(item)
        }
    }
}

class SearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func search(_ query: String) {
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {}
}
