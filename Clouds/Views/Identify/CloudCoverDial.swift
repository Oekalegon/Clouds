//
//  CloudCoverDial.swift
//  Clouds
//
//  Created by Dieudonné Willems on 07/07/2026.
//

import SwiftUI

/// Pure geometry for the dial, separated from the view so the angle → okta
/// mapping (including snapping and the anti-wrap clamp at the top of the
/// dial) is unit-testable.
enum CloudCoverDialGeometry {
    static let steps = 8

    /// Fraction (0...1) of a full clockwise turn from 12 o'clock for a
    /// touch location.
    static func fraction(for location: CGPoint, center: CGPoint) -> Double {
        let dx = location.x - center.x
        let dy = location.y - center.y
        // atan2(dx, -dy) is 0 pointing up and grows clockwise, matching how
        // the filled arc is drawn.
        let angle = atan2(dx, -dy)
        let fraction = angle / (2 * .pi)
        return fraction < 0 ? fraction + 1 : fraction
    }

    /// Snaps a turn fraction to whole eighths. Both 0/8 and 8/8 sit at
    /// 12 o'clock, so a drag crossing the top would jump between them;
    /// when the snapped value is more than half the dial away from the
    /// previous one, the drag is clamped to the endpoint it came from
    /// instead of wrapping.
    static func eighths(forFraction fraction: Double, previous: Int? = nil) -> Int {
        let snapped = Int((fraction * Double(steps)).rounded())
        guard let previous else { return snapped }
        if snapped - previous > steps / 2 { return 0 }
        if previous - snapped > steps / 2 { return steps }
        return snapped
    }
}

/// A round slider recording total cloud cover in eighths of the sky
/// (oktas): drag the knob around the ring to fill 0/8...8/8.
struct CloudCoverDial: View {
    @Binding var eighths: Int
    /// When the dial is disabled (sky obscured) the parent shows its own
    /// overlay in the centre, so the value label is hidden to keep the two
    /// from overlapping.
    @Environment(\.isEnabled) private var isEnabled

    private let diameter: CGFloat = 240
    private let lineWidth: CGFloat = 26

    private var fraction: Double {
        Double(eighths) / Double(CloudCoverDialGeometry.steps)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.2), style: StrokeStyle(lineWidth: lineWidth))

            ticks

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            knob

            if isEnabled {
                VStack(spacing: 4) {
                    Text("\(eighths)/8")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(SkyConditions.coverName(forEighths: eighths))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle().inset(by: -lineWidth))
        .gesture(drag)
        .animation(.snappy(duration: 0.15), value: eighths)
        .accessibilityElement()
        .accessibilityLabel("Cloud cover")
        .accessibilityValue("\(eighths) out of 8")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: eighths = min(eighths + 1, CloudCoverDialGeometry.steps)
            case .decrement: eighths = max(eighths - 1, 0)
            @unknown default: break
            }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: diameter / 2, y: diameter / 2)
                let fraction = CloudCoverDialGeometry.fraction(for: value.location, center: center)
                eighths = CloudCoverDialGeometry.eighths(forFraction: fraction, previous: eighths)
            }
    }

    private var ticks: some View {
        ForEach(0..<CloudCoverDialGeometry.steps, id: \.self) { step in
            Rectangle()
                .fill(.secondary.opacity(0.5))
                .frame(width: 2, height: 8)
                .offset(y: -diameter / 2)
                .rotationEffect(.degrees(Double(step) / Double(CloudCoverDialGeometry.steps) * 360))
        }
    }

    private var knob: some View {
        Circle()
            .fill(.background)
            .stroke(.tint, lineWidth: 3)
            .frame(width: lineWidth + 10, height: lineWidth + 10)
            .shadow(radius: 2)
            .offset(y: -diameter / 2)
            .rotationEffect(.degrees(fraction * 360))
    }
}

#Preview {
    @Previewable @State var eighths = 3
    CloudCoverDial(eighths: $eighths)
}
