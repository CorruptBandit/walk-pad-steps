//
//  CalibrationView.swift
//  WalkPadSteps Watch App
//

import SwiftUI

private nonisolated enum WizardStep: Equatable {
    case introA, timingA, entryA
    case introB, timingB, entryB
    case done
}

private let calibrationDuration: TimeInterval = 30
private let suggestedSpeedA = 1.0
private let suggestedSpeedB = 4.0

struct CalibrationView: View {
    @ObservedObject var calibration: CalibrationStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: WizardStep = .introA
    @State private var speedKmh: Double = suggestedSpeedA
    @State private var startDate: Date?
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var timer: Timer?
    @State private var stepsEntered: Int = 60

    var body: some View {
        VStack(spacing: 6) {
            switch step {
            case .introA: intro(number: 1) { begin(next: .timingA) }
            case .introB: intro(number: 2) { begin(next: .timingB) }
            case .timingA: timing
            case .timingB: timing
            case .entryA: entry { save(slot: .a, next: .introB, resetSpeed: suggestedSpeedB) }
            case .entryB: entry { save(slot: .b, next: .done, resetSpeed: nil) }
            case .done: doneScreen
            }
        }
        .padding(.horizontal, 4)
        .navigationBarBackButtonHidden(step != .introA)
    }

    @ViewBuilder
    private func intro(number: Int, onBegin: @escaping () -> Void) -> some View {
        Text("Point \(number)")
            .font(.caption)
            .foregroundStyle(.secondary)
        Text("Set pad to")
            .font(.caption2)
        Text(String(format: "%.1f km/h", speedKmh))
            .font(.title3)
        Text("Tap Start, then walk for 30 sec")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        Button("Start") { onBegin() }
            .tint(.green)
            .controlSize(.small)
    }

    @ViewBuilder
    private var timing: some View {
        Text(String(format: "%.1f km/h", speedKmh))
            .font(.caption2)
            .foregroundStyle(.secondary)
        Text(formattedTime)
            .font(.system(size: 26, weight: .medium, design: .rounded))
        ProgressView(value: min(elapsedSeconds, calibrationDuration), total: calibrationDuration)
            .tint(.green)
        Text("Keep walking...")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func entry(onSave: @escaping () -> Void) -> some View {
        Text("Steps taken?")
            .font(.caption2)
        HStack(spacing: 10) {
            Button { stepsEntered = max(0, stepsEntered - 1) } label: { Image(systemName: "minus") }
                .controlSize(.mini)
            Text("\(stepsEntered)")
                .font(.title3)
                .frame(minWidth: 40)
            Button { stepsEntered += 1 } label: { Image(systemName: "plus") }
                .controlSize(.mini)
        }
        Button("Save") { onSave() }
            .tint(.green)
            .controlSize(.small)
    }

    private var doneScreen: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title2)
            Text("Calibration complete")
                .font(.caption)
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .controlSize(.small)
        }
    }

    private var formattedTime: String {
        let total = Int(elapsedSeconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func begin(next: WizardStep) {
        elapsedSeconds = 0
        startDate = Date()
        step = next
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard let startDate else { return }
            elapsedSeconds = Date().timeIntervalSince(startDate)
            if elapsedSeconds >= calibrationDuration {
                finishTiming(next: next == .timingA ? .entryA : .entryB)
            }
        }
    }

    private func finishTiming(next: WizardStep) {
        timer?.invalidate()
        timer = nil
        if let startDate {
            elapsedSeconds = min(Date().timeIntervalSince(startDate), calibrationDuration * 2)
        }
        stepsEntered = Int(elapsedSeconds / 60 * 100)
        step = next
    }

    private func save(slot: CalibrationStore.Slot, next: WizardStep, resetSpeed: Double?) {
        let minutes = max(elapsedSeconds / 60, 1.0 / 60)
        let cadence = Double(stepsEntered) / minutes
        calibration.save(slot: slot, speedKmh: speedKmh, cadenceStepsPerMinute: cadence)
        if let resetSpeed {
            speedKmh = resetSpeed
        }
        step = next
    }
}
