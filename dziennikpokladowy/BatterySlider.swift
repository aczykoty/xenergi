import SwiftUI
import Combine
import UIKit

struct BatterySlider: View {
    @Binding var percentage: Double // 0.0 do 1.0
    let label: String
    let isDark: Bool
    
    // Dynamiczny kolor baterii zależny od naładowania
    private var batteryColor: Color {
        if percentage < 0.2 { return .red }
        if percentage < 0.5 { return .orange }
        return .green
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.5)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int(percentage * 100))%")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(batteryColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 1. OBRYS BATERII
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 2)
                        .background(RoundedRectangle(cornerRadius: 12).fill(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.02)))
                    
                    // 2. WYPEŁNIENIE BATERII
                    RoundedRectangle(cornerRadius: 9)
                        .fill(
                            LinearGradient(
                                colors: [batteryColor, batteryColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: max(0, CGFloat(percentage) * (geometry.size.width - 8)))
                        .padding(4)
                        .shadow(color: batteryColor.opacity(0.5), radius: 6, x: 0, y: 0)
                    
                    // 3. CYPEL BATERII (Positive terminal)
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.1))
                            .frame(width: 6, height: 20)
                            .offset(x: 10)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newValue = Double(value.location.x / geometry.size.width)
                            self.percentage = min(max(newValue, 0), 1.0)
                            
                            // Delikatny feedback haptyczny przy zmianie co 1%
                            if Int(newValue * 100) % 5 == 0 {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                )
            }
            .frame(height: 50)
        }
        .padding(.vertical, 10)
    }
}
