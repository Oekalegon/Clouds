//
//  CloudCoverDialTests.swift
//  CloudsTests
//
//  Created by Dieudonné Willems on 07/07/2026.
//

import Foundation
import Testing
@testable import Clouds

struct CloudCoverDialTests {
    private let center = CGPoint(x: 100, y: 100)

    @Test func fractionIsZeroAtTop() {
        let fraction = CloudCoverDialGeometry.fraction(for: CGPoint(x: 100, y: 0), center: center)
        #expect(abs(fraction) < 0.0001)
    }

    @Test func fractionIsQuarterAtRight() {
        let fraction = CloudCoverDialGeometry.fraction(for: CGPoint(x: 200, y: 100), center: center)
        #expect(abs(fraction - 0.25) < 0.0001)
    }

    @Test func fractionIsHalfAtBottom() {
        let fraction = CloudCoverDialGeometry.fraction(for: CGPoint(x: 100, y: 200), center: center)
        #expect(abs(fraction - 0.5) < 0.0001)
    }

    @Test func fractionIsThreeQuartersAtLeft() {
        let fraction = CloudCoverDialGeometry.fraction(for: CGPoint(x: 0, y: 100), center: center)
        #expect(abs(fraction - 0.75) < 0.0001)
    }

    @Test func snapsToNearestEighth() {
        #expect(CloudCoverDialGeometry.eighths(forFraction: 0.0) == 0)
        #expect(CloudCoverDialGeometry.eighths(forFraction: 0.05) == 0)
        #expect(CloudCoverDialGeometry.eighths(forFraction: 0.07) == 1)
        #expect(CloudCoverDialGeometry.eighths(forFraction: 0.25) == 2)
        #expect(CloudCoverDialGeometry.eighths(forFraction: 0.5) == 4)
        #expect(CloudCoverDialGeometry.eighths(forFraction: 0.99) == 8)
    }

    @Test func clampsToFullWhenCrossingTopClockwise() {
        // Knob at 7/8, drag just past 12 o'clock: without the clamp the
        // snapped value would wrap to 0.
        #expect(CloudCoverDialGeometry.eighths(forFraction: 0.01, previous: 7) == 8)
    }

    @Test func clampsToZeroWhenCrossingTopCounterclockwise() {
        // Knob at 1/8, drag just before 12 o'clock: without the clamp the
        // snapped value would wrap to 8.
        #expect(CloudCoverDialGeometry.eighths(forFraction: 0.99, previous: 1) == 0)
    }

    @Test func touchOnRingIsAccepted() {
        // Dial of radius 100: the outer edge and just inside the tolerance
        // band both count as the ring.
        #expect(CloudCoverDialGeometry.isOnRing(
            CGPoint(x: 200, y: 100), center: center, radius: 100, tolerance: 39
        ))
        #expect(CloudCoverDialGeometry.isOnRing(
            CGPoint(x: 100, y: 38), center: center, radius: 100, tolerance: 39
        ))
    }

    @Test func touchInCentreIsRejected() {
        #expect(!CloudCoverDialGeometry.isOnRing(
            CGPoint(x: 100, y: 100), center: center, radius: 100, tolerance: 39
        ))
        #expect(!CloudCoverDialGeometry.isOnRing(
            CGPoint(x: 130, y: 120), center: center, radius: 100, tolerance: 39
        ))
    }

    @Test func normalDragMovesFreely() {
        #expect(CloudCoverDialGeometry.eighths(forFraction: 0.5, previous: 2) == 4)
        #expect(CloudCoverDialGeometry.eighths(forFraction: 0.25, previous: 6) == 2)
    }
}
