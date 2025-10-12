import SwiftUI

/// A text-based linear graph for battery percentage using block characters and inverse color for the percent label.
struct BatteryBarView: View {
    let percentage: Double // 0...100
    let barWidth: Int
    let fontName: String
    let fontSize: CGFloat
    let barForeground: Color
    let barBackground: Color
    let inverseLabelColor: Color
    
    init(percentage: Double, barWidth: Int = 20, fontName: String = "EnhancedDotDigital-7", fontSize: CGFloat = 18,
         barForeground: Color = .green, barBackground: Color = .gray, inverseLabelColor: Color = .black) {
        self.percentage = percentage
        self.barWidth = barWidth
        self.fontName = fontName
        self.fontSize = fontSize
        self.barForeground = barForeground
        self.barBackground = barBackground
        self.inverseLabelColor = inverseLabelColor
    }

    var body: some View {
        let filledBlocks = Int(round((percentage / 100.0) * Double(barWidth)))
        let emptyBlocks = barWidth - filledBlocks
        let bar = String(repeating: "█", count: filledBlocks) + String(repeating: "░", count: emptyBlocks)
        // Center the percentage label inside the bar
        let percentStr = String(format: "%g%%", percentage.rounded())
        let barWithPercent = insertLabel(in: bar, label: percentStr)
        
        // Render the bar. The percent label in inverse color, rest uses the block color
        Text(barWithPercent)
            .font(.custom(fontName, size: fontSize))
            .foregroundColor(barForeground)
            .background(
                Text(bar)
                    .font(.custom(fontName, size: fontSize))
                    .foregroundColor(barBackground)
            )
            .overlay(
                inverseLabelView(in: bar, label: percentStr)
            )
    }
    
    /// Inserts the percent label into the bar string, centered.
    private func insertLabel(in bar: String, label: String) -> AttributedString {
        var attrBar = AttributedString(bar)
        let barCount = bar.count
        let labelCount = label.count
        let labelStart = max((barCount - labelCount) / 2, 0)
        
        // Apply inverse foreground color to the percent text
        let range = attrBar.index(attrBar.startIndex, offsetBy: labelStart)..<attrBar.index(attrBar.startIndex, offsetBy: labelStart+labelCount)
        attrBar.replaceSubrange(range, with: AttributedString(label))
        return attrBar
    }

    /// Create a view that overlays the label with inverseLabelColor at the correct position.
    @ViewBuilder
    private func inverseLabelView(in bar: String, label: String) -> some View {
        let barCount = bar.count
        let labelCount = label.count
        let labelStart = max((barCount - labelCount) / 2, 0)

        HStack(spacing: 0) {
            Text(String(bar.prefix(labelStart)))
                .font(.custom(fontName, size: fontSize))
                .hidden()
            Text(label)
                .font(.custom(fontName, size: fontSize))
                .foregroundColor(inverseLabelColor)
                .background(barForeground)
            Text(String(bar.suffix(barCount - labelStart - labelCount)))
                .font(.custom(fontName, size: fontSize))
                .hidden()
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        BatteryBarView(percentage: 90)
        BatteryBarView(percentage: 56)
        BatteryBarView(percentage: 10, barForeground: .red, inverseLabelColor: .white)
    }
    .padding()
    .background(Color.black)
}
#endif
