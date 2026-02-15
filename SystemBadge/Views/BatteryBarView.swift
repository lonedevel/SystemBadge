import SwiftUI

/// A modern battery percentage graph using SwiftUI shapes with proper layout and color coding.
struct BatteryBarView: View {
    let percentage: Double // 0...100
    let fontName: String
    let fontSize: CGFloat
    let barForeground: Color
    let barBackground: Color
    let inverseLabelColor: Color
    
    // Computed properties for dynamic styling
    private var fillColor: Color {
        if percentage > 50 {
            return .green
        } else if percentage > 20 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var percentageText: String {
        String(format: "%.0f%%", percentage)
    }
    
    init(percentage: Double, barWidth: Int = 20, fontName: String = "EnhancedDotDigital-7", fontSize: CGFloat = 18,
         barForeground: Color = .green, barBackground: Color = .gray, inverseLabelColor: Color = .black) {
        self.percentage = max(0, min(100, percentage)) // Clamp to 0-100
        self.fontName = fontName
        self.fontSize = fontSize
        self.barForeground = barForeground
        self.barBackground = barBackground
        self.inverseLabelColor = inverseLabelColor
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background bar (empty portion)
                RoundedRectangle(cornerRadius: 4)
                    .fill(barBackground.opacity(0.3))
                    .frame(width: geometry.size.width, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(barBackground.opacity(0.5), lineWidth: 1)
                    )
                
                // Filled bar (battery level)
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [fillColor, fillColor.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * (percentage / 100.0), height: 24)
                    .animation(.easeInOut(duration: 0.3), value: percentage)
                
                // Percentage text overlay with high contrast
                ZStack {
                    // Multiple shadow layers for strong outline effect
                    ForEach(0..<8, id: \.self) { index in
                        Text(percentageText)
                            .font(.custom(fontName, size: fontSize))
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .offset(
                                x: cos(Double(index) * .pi / 4.0) * 2,
                                y: sin(Double(index) * .pi / 4.0) * 2
                            )
                    }
                    
                    // Main text with white color for maximum contrast
                    Text(percentageText)
                        .font(.custom(fontName, size: fontSize))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2, x: 0, y: 0)
                }
                .frame(width: geometry.size.width)
            }
        }
        .frame(height: 24)
    }
}

#if DEBUG
#Preview("Battery Levels") {
    VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
            Text("High Battery (90%)")
                .font(.caption)
                .foregroundColor(.secondary)
            BatteryBarView(percentage: 90)
                .frame(width: 400)
        }
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Medium Battery (56%)")
                .font(.caption)
                .foregroundColor(.secondary)
            BatteryBarView(percentage: 56)
                .frame(width: 400)
        }
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Low Battery (15%)")
                .font(.caption)
                .foregroundColor(.secondary)
            BatteryBarView(percentage: 15)
                .frame(width: 400)
        }
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Critical Battery (5%)")
                .font(.caption)
                .foregroundColor(.secondary)
            BatteryBarView(percentage: 5)
                .frame(width: 400)
        }
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Full Battery (100%)")
                .font(.caption)
                .foregroundColor(.secondary)
            BatteryBarView(percentage: 100)
                .frame(width: 400)
        }
    }
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))
}
#endif

