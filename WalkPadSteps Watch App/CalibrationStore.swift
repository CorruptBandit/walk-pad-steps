//
//  CalibrationStore.swift
//  WalkPadSteps Watch App
//

import Foundation
import Combine

struct CalibrationPoint: Codable {
    var speedKmh: Double
    var cadenceStepsPerMinute: Double
}

/// Stores up to two (speed, cadence) points and derives a linear
/// cadence-vs-speed model from them, since stride length/cadence
/// isn't constant across walking speeds.
final class CalibrationStore: ObservableObject {
    @Published private(set) var pointA: CalibrationPoint?
    @Published private(set) var pointB: CalibrationPoint?

    private let defaultsKeyA = "calibration.pointA"
    private let defaultsKeyB = "calibration.pointB"

    // Reasonable defaults until the user calibrates for themselves.
    private let fallbackLow = CalibrationPoint(speedKmh: 1.0, cadenceStepsPerMinute: 60)
    private let fallbackHigh = CalibrationPoint(speedKmh: 5.0, cadenceStepsPerMinute: 100)

    init() {
        pointA = Self.load(key: defaultsKeyA)
        pointB = Self.load(key: defaultsKeyB)
    }

    var isCalibrated: Bool { pointA != nil && pointB != nil }

    func save(slot: Slot, speedKmh: Double, cadenceStepsPerMinute: Double) {
        let point = CalibrationPoint(speedKmh: speedKmh, cadenceStepsPerMinute: cadenceStepsPerMinute)
        switch slot {
        case .a:
            pointA = point
            Self.store(point, key: defaultsKeyA)
        case .b:
            pointB = point
            Self.store(point, key: defaultsKeyB)
        }
    }

    func clear() {
        pointA = nil
        pointB = nil
        UserDefaults.standard.removeObject(forKey: defaultsKeyA)
        UserDefaults.standard.removeObject(forKey: defaultsKeyB)
    }

    /// Cadence (steps/minute) at a given speed, via linear interpolation/
    /// extrapolation between the two calibration points.
    func cadence(atSpeedKmh speed: Double) -> Double {
        let low = pointA ?? fallbackLow
        let high = pointB ?? fallbackHigh
        let (p1, p2) = low.speedKmh <= high.speedKmh ? (low, high) : (high, low)

        guard p2.speedKmh != p1.speedKmh else { return p1.cadenceStepsPerMinute }

        let slope = (p2.cadenceStepsPerMinute - p1.cadenceStepsPerMinute) / (p2.speedKmh - p1.speedKmh)
        let cadence = p1.cadenceStepsPerMinute + slope * (speed - p1.speedKmh)
        return max(0, cadence)
    }

    enum Slot {
        case a, b
    }

    private static func load(key: String) -> CalibrationPoint? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CalibrationPoint.self, from: data)
    }

    private static func store(_ point: CalibrationPoint, key: String) {
        guard let data = try? JSONEncoder().encode(point) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
