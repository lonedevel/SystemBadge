import SwiftUI

struct PercentBarView: View {
    let percentage: Double
    let fontName: String
    let fontSize: CGFloat
    let barForeground: Color
    let barBackground: Color

    init(percentage: Double, fontName: String = "EnhancedDotDigital-7", fontSize: CGFloat = 18,
         barForeground: Color = .green, barBackground: Color = .gray) {
        self.percentage = max(0, min(100, percentage))
        self.fontName = fontName
        self.fontSize = fontSize
        self.barForeground = barForeground
        self.barBackground = barBackground
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(barBackground.opacity(0.25))
                    .frame(width: geometry.size.width, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(barBackground.opacity(0.5), lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: 4)
                    .fill(barForeground.opacity(0.85))
                    .frame(width: geometry.size.width * (percentage / 100.0), height: 24)
                    .animation(.easeInOut(duration: 0.3), value: percentage)

                Text(String(format: "%.0f%%", percentage))
                    .font(.custom(fontName, size: fontSize))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2, x: 0, y: 0)
                    .frame(width: geometry.size.width)
            }
        }
        .frame(height: 24)
    }
}

struct RatePairView: View {
    let downValue: Double
    let upValue: Double
    let unit: String
    let metricColor: Color
    let labelColor: Color

    private var maxValue: Double {
        max(downValue, upValue, 0.1)
    }

    var body: some View {
        HStack(spacing: 16) {
            rateRow(icon: "arrow.down", value: downValue)
            rateRow(icon: "arrow.up", value: upValue)
        }
    }

    private func rateRow(icon: String, value: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(labelColor)
            Text(String(format: "%.1f %@", value, unit))
                .font(.custom("EnhancedDotDigital-7", size: 18))
                .foregroundColor(metricColor)
                .bold()
                .italic()
            RoundedRectangle(cornerRadius: 4)
                .fill(metricColor.opacity(0.7))
                .frame(width: 120 * CGFloat(value / maxValue), height: 9)
                .animation(.easeInOut(duration: 0.25), value: value)
        }
    }
}

struct SparklineView: View {
    let history: [Double]
    let lineColor: Color
    let labelColor: Color
    let scaleMode: SparklineScaleMode

    var body: some View {
        GeometryReader { geometry in
            let grid = dotMatrixPoints(in: geometry.size)
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(labelColor.opacity(0.12))
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                labelColor.opacity(0.18),
                                labelColor.opacity(0.04)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                ForEach(grid.backgroundDots.indices, id: \.self) { index in
                    Circle()
                        .fill(labelColor.opacity(0.32))
                        .frame(width: grid.dotSize, height: grid.dotSize)
                        .position(grid.backgroundDots[index])
                }
                ForEach(grid.activeDots.indices, id: \.self) { index in
                    Circle()
                        .fill(lineColor)
                        .shadow(color: lineColor.opacity(0.85), radius: grid.dotSize * 0.7, x: 0, y: 0)
                        .shadow(color: lineColor.opacity(0.6), radius: grid.dotSize * 1.1, x: 0, y: 0)
                        .frame(width: grid.dotSize, height: grid.dotSize)
                        .position(grid.activeDots[index])
                }
            }
        }
        .frame(height: 24)
    }

    private func dotMatrixPoints(in size: CGSize) -> (backgroundDots: [CGPoint], activeDots: [CGPoint], dotSize: CGFloat) {
        let rows = 10
        let gap: CGFloat = 1.0
        let dotSize = min(4.0, max(2.0, (size.height - (CGFloat(rows - 1) * gap)) / CGFloat(rows)))
        let ySpacing = dotSize + gap
        let columns = max(2, Int((size.width - dotSize) / (dotSize + gap)) + 1)
        let xSpacing = dotSize + gap

        var background: [CGPoint] = []
        background.reserveCapacity(columns * rows)
        for col in 0..<columns {
            for row in 0..<rows {
                let x = CGFloat(col) * xSpacing + dotSize / 2
                let y = CGFloat(row) * ySpacing + dotSize / 2
                background.append(CGPoint(x: x, y: y))
            }
        }

        let smoothed = applySmoothing(to: history, mode: scaleMode)
        guard smoothed.count > 1 else {
            return (background, [], dotSize)
        }

        let rangeValues = scaleRange(for: smoothed, mode: scaleMode)
        let minValue = rangeValues.min
        let maxValue = rangeValues.max
        let range = max(maxValue - minValue, 0.001)
        let samples = resampleHistory(smoothed, to: columns)

        var active: [CGPoint] = []
        active.reserveCapacity(samples.count * rows)
        for (index, value) in samples.enumerated() {
            let normalized = (value - minValue) / range
            let clamped = max(0, min(1, normalized))
            let row = Int(round((1.0 - clamped) * Double(rows - 1)))
            let x = CGFloat(index) * xSpacing + dotSize / 2
            for fillRow in row..<rows {
                let y = CGFloat(fillRow) * ySpacing + dotSize / 2
                active.append(CGPoint(x: x, y: y))
            }
        }

        return (background, active, dotSize)
    }

    private func resampleHistory(_ input: [Double], to columns: Int) -> [Double] {
        guard input.count > 1, columns > 1 else {
            return Array(input.prefix(columns))
        }
        if input.count == columns {
            return input
        }
        var values: [Double] = []
        values.reserveCapacity(columns)
        let maxIndex = Double(input.count - 1)
        for col in 0..<columns {
            let t = Double(col) / Double(columns - 1)
            let position = t * maxIndex
            let lower = Int(floor(position))
            let upper = Int(ceil(position))
            if lower == upper {
                values.append(input[lower])
            } else {
                let fraction = position - Double(lower)
                let interpolated = input[lower] + (input[upper] - input[lower]) * fraction
                values.append(interpolated)
            }
        }
        return values
    }

    private func applySmoothing(to input: [Double], mode: SparklineScaleMode) -> [Double] {
        switch mode {
        case .fixedPercent, .fixedRange:
            return input
        case .autoSmoothed(let window):
            guard input.count > 1, window > 1 else { return input }
            var smoothed: [Double] = []
            smoothed.reserveCapacity(input.count)
            let half = window / 2
            for idx in input.indices {
                let start = max(0, idx - half)
                let end = min(input.count - 1, idx + half)
                let slice = input[start...end]
                let avg = slice.reduce(0, +) / Double(slice.count)
                smoothed.append(avg)
            }
            return smoothed
        }
    }

    private func scaleRange(for input: [Double], mode: SparklineScaleMode) -> (min: Double, max: Double) {
        switch mode {
        case .fixedPercent:
            return (0, 100)
        case .autoSmoothed:
            let minValue = input.min() ?? 0
            let maxValue = input.max() ?? 1
            return (minValue, maxValue)
        case .fixedRange(let min, let max):
            return (min, max)
        }
    }
}

struct SparklineMetricView: View {
    let valueText: String
    let history: [Double]
    let lineColor: Color
    let labelColor: Color
    let unit: String
    let scaleOverride: SparklineScaleMode?

    var body: some View {
        HStack(spacing: 12) {
            Text(valueText)
                .font(.custom("EnhancedDotDigital-7", size: 18))
                .foregroundColor(lineColor)
                .bold()
                .italic()
                .frame(width: 160, alignment: .leading)
            SparklineView(
                history: history,
                lineColor: lineColor,
                labelColor: labelColor,
                scaleMode: scaleOverride ?? (unit == "%" ? .fixedPercent : .autoSmoothed(window: 5))
            )
        }
    }
}

enum SparklineScaleMode {
    case fixedPercent
    case autoSmoothed(window: Int)
    case fixedRange(min: Double, max: Double)
}

#if DEBUG
#Preview("Metric Views") {
    VStack(spacing: 16) {
        PercentBarView(percentage: 42)
            .frame(width: 420)
        RatePairView(downValue: 12.4, upValue: 2.1, unit: "MB/s", metricColor: .green, labelColor: .secondary)
            .frame(width: 420)
        SparklineMetricView(valueText: "37%", history: [10, 20, 30, 25, 40, 35, 50, 45], lineColor: .green, labelColor: .secondary, unit: "%", scaleOverride: nil)
            .frame(width: 420)
    }
    .padding()
}
#endif
