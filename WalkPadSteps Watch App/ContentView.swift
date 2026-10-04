//
//  ContentView.swift
//  WalkPadSteps Watch App
//

import SwiftUI

struct ContentView: View {
    @StateObject private var session = WalkSession()
    @FocusState private var crownFocused: Bool
    @State private var crownValue: Double = 1.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                HStack {
                    Text(String(format: "%.1f", session.speedKmh))
                        .font(.title3)
                    Text("km/h")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button {
                        session.speedKmh = max(1.0, session.speedKmh - 0.5)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .controlSize(.mini)

                    Button {
                        session.speedKmh = min(10, session.speedKmh + 0.5)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .controlSize(.mini)
                }

                Button(session.isRunning ? "Stop" : "Start") {
                    session.isRunning ? session.stop() : session.start()
                }
                .tint(session.isRunning ? .red : .green)
                .controlSize(.mini)
                // Maps the Apple Watch's hardware "Double Tap" gesture
                // (Series 9+) to this button, instead of a custom
                // onTapGesture, which was conflicting with the system's
                // own double-tap handling and showing a repeat hint.
                .handGestureShortcut(.primaryAction)

                Text(formattedTime)
                    .font(.system(size: 18, weight: .medium, design: .rounded))

                HStack(spacing: 10) {
                    Text("\(session.estimatedSteps) steps")
                    Label(heartRateText, systemImage: "heart.fill")
                        .foregroundStyle(.red)
                    Label(caloriesText, systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                }
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                Text(statusText)
                    .font(.system(size: 10))
                    .foregroundStyle(session.errorMessage != nil ? .red : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 22)
            }
            .padding(.horizontal, 2)
            .focusable(true)
            .focused($crownFocused)
            .digitalCrownRotation(
                $crownValue,
                from: 1.0,
                through: 10,
                by: 0.5,
                sensitivity: .low,
                isContinuous: false,
                isHapticFeedbackEnabled: true
            )
            // `by:` on digitalCrownRotation doesn't reliably snap the
            // reported value to that step size, so we round it ourselves
            // and only push whole 0.5 increments into the session.
            .onChange(of: crownValue) { _, newValue in
                let rounded = (newValue * 2).rounded() / 2
                if session.speedKmh != rounded {
                    session.speedKmh = rounded
                }
                crownValue = rounded
            }
            .onAppear {
                crownFocused = true
                crownValue = session.speedKmh
            }
            // Keep the crown's tracked value in sync when speed changes via
            // the +/- buttons, so the next crown turn continues from there.
            .onChange(of: session.speedKmh) { _, newValue in
                if crownValue != newValue {
                    crownValue = newValue
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        CalibrationView(calibration: session.calibration)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .disabled(session.isRunning)
                }
            }
        }
    }

    private var formattedTime: String {
        let total = Int(session.elapsedSeconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var heartRateText: String {
        session.heartRate.map { "\(Int($0))" } ?? "--"
    }

    private var caloriesText: String {
        session.activeCalories.map { "\(Int($0))" } ?? "--"
    }

    private var statusText: String {
        if let error = session.errorMessage { return error }
        if let saved = session.lastSavedSteps {
            return session.status == .interrupted ? "Stopped early, saved \(saved)" : "Saved \(saved) steps"
        }
        return " "
    }
}

#Preview {
    ContentView()
}
