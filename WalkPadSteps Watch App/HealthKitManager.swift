//
//  HealthKitManager.swift
//  WalkPadSteps Watch App
//

import HealthKit

final class HealthKitManager {
    let store = HKHealthStore()
    let stepType = HKQuantityType(.stepCount)
    let heartRateType = HKQuantityType(.heartRate)
    let activeEnergyType = HKQuantityType(.activeEnergyBurned)
    let workoutType = HKObjectType.workoutType()

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        let toShare: Set<HKSampleType> = [stepType, heartRateType, activeEnergyType, workoutType]
        let toRead: Set<HKObjectType> = [stepType, heartRateType, activeEnergyType, workoutType]
        store.requestAuthorization(toShare: toShare, read: toRead) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }

    func writeSteps(count: Int, start: Date, end: Date) {
        guard count > 0 else { return }
        let quantity = HKQuantity(unit: .count(), doubleValue: Double(count))
        let sample = HKQuantitySample(type: stepType, quantity: quantity, start: start, end: end)
        store.save(sample) { success, error in
            if let error {
                print("HealthKit save failed: \(error)")
            }
        }
    }
}
