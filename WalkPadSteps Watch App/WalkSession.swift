//
//  WalkSession.swift
//  WalkPadSteps Watch App
//

import Foundation
import Combine
import HealthKit

enum SessionStatus {
    case idle
    case running
    case interrupted   // ended early, e.g. another workout session took over
}

final class WalkSession: NSObject, ObservableObject {
    @Published var speedKmh: Double = 1.0 {
        didSet {
            guard status == .running, oldValue != speedKmh else { return }
            closeSegment(atSpeedKmh: oldValue, end: Date())
        }
    }
    @Published var status: SessionStatus = .idle
    @Published var elapsedSeconds: TimeInterval = 0
    @Published var lastSavedSteps: Int? = nil
    @Published var heartRate: Double? = nil
    @Published var activeCalories: Double? = nil
    @Published var errorMessage: String? = nil

    let calibration = CalibrationStore()
    private let healthKit = HealthKitManager()

    private var uiTimer: Timer?
    private var startDate: Date?
    private var segmentStartDate: Date?
    private var accumulatedSteps: Double = 0
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    var isRunning: Bool { status == .running }

    /// Adds the steps walked so far at `speedKmh` to `accumulatedSteps`, then
    /// starts a fresh segment — called whenever the speed changes mid-walk,
    /// since cadence varies by speed and can't be applied retroactively.
    private func closeSegment(atSpeedKmh speed: Double, end: Date) {
        guard let segmentStart = segmentStartDate else { return }
        let minutes = end.timeIntervalSince(segmentStart) / 60
        accumulatedSteps += calibration.cadence(atSpeedKmh: speed) * minutes
        segmentStartDate = end
    }

    override init() {
        super.init()
        healthKit.requestAuthorization { [weak self] granted in
            if !granted {
                self?.errorMessage = "Health access not granted. Enable it in Settings > Privacy > Health."
            }
        }
    }

    var estimatedSteps: Int {
        guard status == .running, let segmentStart = segmentStartDate else {
            return Int(accumulatedSteps)
        }
        let currentSegmentMinutes = Date().timeIntervalSince(segmentStart) / 60
        let currentSegmentSteps = calibration.cadence(atSpeedKmh: speedKmh) * currentSegmentMinutes
        return Int(accumulatedSteps + currentSegmentSteps)
    }

    func start() {
        guard status != .running else { return }
        errorMessage = nil
        lastSavedSteps = nil
        heartRate = nil
        activeCalories = nil

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthKit.store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            session.delegate = self
            builder.delegate = self

            let dataSource = HKLiveWorkoutDataSource(healthStore: healthKit.store, workoutConfiguration: configuration)
            dataSource.enableCollection(for: healthKit.heartRateType, predicate: nil)
            dataSource.enableCollection(for: healthKit.activeEnergyType, predicate: nil)
            builder.dataSource = dataSource

            self.workoutSession = session
            self.builder = builder

            let now = Date()
            startDate = now
            segmentStartDate = now
            accumulatedSteps = 0
            elapsedSeconds = 0
            status = .running

            session.startActivity(with: now)
            builder.beginCollection(withStart: now) { [weak self] success, error in
                if let error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Couldn't start session: \(error.localizedDescription)"
                    }
                }
            }

            startUITimer()
        } catch {
            errorMessage = "Couldn't start workout session: \(error.localizedDescription)"
        }
    }

    func stop() {
        guard status == .running, let start = startDate else { return }
        finalize(start: start, end: Date(), reachedStatus: .idle)
    }

    private func finalize(start: Date, end: Date, reachedStatus: SessionStatus) {
        stopUITimer()
        closeSegment(atSpeedKmh: speedKmh, end: end)
        elapsedSeconds = end.timeIntervalSince(start)
        let steps = Int(accumulatedSteps)
        let session = workoutSession
        let builder = self.builder

        healthKit.writeSteps(count: steps, start: start, end: end)
        lastSavedSteps = steps
        status = reachedStatus
        startDate = nil
        segmentStartDate = nil
        self.workoutSession = nil
        self.builder = nil

        session?.end()
        builder?.endCollection(withEnd: end) { success, error in
            builder?.finishWorkout { workout, error in
                if let error {
                    print("Failed to save workout: \(error)")
                }
            }
        }
    }

    private func startUITimer() {
        uiTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.startDate else { return }
            self.elapsedSeconds = Date().timeIntervalSince(start)
        }
    }

    private func stopUITimer() {
        uiTimer?.invalidate()
        uiTimer = nil
    }
}

extension WalkSession: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        if toState == .ended || toState == .stopped {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.status == .running, let start = self.startDate else { return }
                // Session ended without us calling stop() directly, e.g. interrupted by another workout.
                self.finalize(start: start, end: date, reachedStatus: .interrupted)
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = "Session failed: \(error.localizedDescription)"
        }
    }
}

extension WalkSession: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = workoutBuilder.statistics(for: quantityType) else { continue }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if quantityType == self.healthKit.heartRateType {
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    self.heartRate = statistics.mostRecentQuantity()?.doubleValue(for: unit)
                } else if quantityType == self.healthKit.activeEnergyType {
                    self.activeCalories = statistics.sumQuantity()?.doubleValue(for: .kilocalorie())
                }
            }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
