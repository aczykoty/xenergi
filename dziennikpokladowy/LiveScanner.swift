import SwiftUI
import Vision
import AVFoundation

// MARK: - LIVE SCANNER VIEW (BRIDGE)
struct LiveScannerView: UIViewControllerRepresentable {
    let type: EntryType
    let onResult: ((amount: Double, price: Double, total: Double)?, Double?) -> Void
    
    func makeUIViewController(context: Context) -> LiveScannerViewController {
        let vc = LiveScannerViewController()
        vc.type = type
        vc.onResult = onResult
        return vc
    }
    func updateUIViewController(_ uiViewController: LiveScannerViewController, context: Context) {}
}

// MARK: - LOGIKA SKANERA (CONTROLLER)
class LiveScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var type: EntryType = .fuel
    var onResult: (((amount: Double, price: Double, total: Double)?, Double?) -> Void)?
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var isProcessing = false
    private var didFindResult = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .hd1920x1080
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        
        if captureSession.canAddInput(videoInput) { captureSession.addInput(videoInput) }
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessing, !didFindResult else { return }
        isProcessing = true
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { isProcessing = false; return }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            defer { self?.isProcessing = false }
            guard let self = self, !self.didFindResult else { return }
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            var scannedNumbers: [(val: Double, y: CGFloat)] = []
            var explicitKwhAmount: Double? = nil
            
            for obs in observations {
                let text = obs.topCandidates(1).first?.string ?? ""
                let lowerText = text.lowercased()
                
                if lowerText.contains("kwh") || lowerText.contains("kw") {
                    let cleanedKwh = lowerText.replacingOccurrences(of: ",", with: ".").components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
                    if let num = Double(cleanedKwh), num > 0 { explicitKwhAmount = num }
                }
                
                let pattern = "[0-9]+([.,][0-9]+)?"
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                    for match in matches {
                        if let range = Range(match.range, in: text) {
                            let matchStr = String(text[range]).replacingOccurrences(of: ",", with: ".")
                            if let num = Double(matchStr) { scannedNumbers.append((val: num, y: obs.boundingBox.midY)) }
                        }
                    }
                }
            }
            
            let validNums = scannedNumbers.filter { $0.val > 0 }
            var bestTriplet: (amount: Double, price: Double, total: Double)? = nil
            
            if validNums.count >= 3 {
                for i in 0..<validNums.count {
                    for j in 0..<validNums.count {
                        if i == j { continue }
                        for k in 0..<validNums.count {
                            if i == k || j == k { continue }
                            let a = validNums[i]; let b = validNums[j]; let c = validNums[k]
                            if abs((a.val * b.val) - c.val) <= 0.25 {
                                let priceVal = a.y < b.y ? a.val : b.val
                                let amountVal = a.y < b.y ? b.val : a.val
                                if priceVal < 20.0 { bestTriplet = (amountVal, priceVal, c.val) }
                            }
                        }
                    }
                }
            }
            
            if bestTriplet != nil || (self.type == .charge && explicitKwhAmount != nil) {
                self.didFindResult = true
                DispatchQueue.main.async {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.captureSession.stopRunning()
                    self.onResult?(bestTriplet, explicitKwhAmount)
                }
            }
        }
        
        request.recognitionLevel = .accurate
        // Obszar skanowania: środkowy pas ekranu
        request.regionOfInterest = CGRect(x: 0.05, y: 0.25, width: 0.9, height: 0.5)
        
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right).perform([request])
    }
}

// MARK: - POWRÓT DO KLASYCZNEGO INTERFEJSU (HUD)
struct LiveScannerHUD: View {
    let type: EntryType
    let onCancel: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geo in
        ZStack {
            // Delikatne przyciemnienie całego podglądu (bez dziur i masek)
            Color.black.opacity(0.3).ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // --- KLASYCZNY CELOWNIK ---
                ZStack {
                    // Poświata wewnątrz celownika
                    RoundedRectangle(cornerRadius: 12)
                        .foregroundColor(Color.green.opacity(0.15))
                        .blur(radius: isAnimating ? 8 : 4)
                    
                    // Pulsująca ramka
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green, lineWidth: 3)
                        .scaleEffect(isAnimating ? 1.03 : 0.97)
                        .opacity(isAnimating ? 1.0 : 0.5)
                }
                // Kwadratowy celownik (85% szerokości ekranu)
                .frame(width: geo.size.width * 0.85, height: geo.size.width * 0.85)
                
                // Tekst pod celownikiem
                Text(type == .fuel ? "Skieruj na licznik dystrybutora" : "Skieruj na dane ładowania")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 25)
                    .shadow(radius: 5)
                
                Spacer()
                
                // --- WIELKI, WYGODNY PRZYCISK ANULUJ ---
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onCancel()
                }) {
                    Text("Anuluj")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        // Szklany efekt pasujący do Twojego Dark Blue
                        .background(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .cornerRadius(14)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50) // Wyżej, żeby kciuk łatwo trafiał
            }
        }
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// POMOCNICZY KSZTAŁT DLA NAROŻNIKÓW
struct ScannerCorners: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let len: CGFloat = 20
        
        // Lewy górny
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        
        // Prawy górny
        path.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        
        // Lewy dolny
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - len))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        
        // Prawy dolny
        path.move(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        
        return path
    }
}
