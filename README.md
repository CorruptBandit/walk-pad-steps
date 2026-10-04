# WalkPad Steps

Standalone watchOS app (no companion iPhone app required) for estimating and
logging steps while walking on a treadmill/walking pad at a desk, where the
Watch's own motion-based step counting isn't reliable.

This is especially useful with a standing desk: your arms stay mostly still
on the keyboard while you walk, so the Watch's motion sensors often don't
register the steps at all - this app estimates them from speed and elapsed
time instead, independent of arm movement.

Not published - for personal use, installed directly from Xcode.

## How it works

- Set the pad's speed, tap **Start**. The app runs an `HKWorkoutSession`
  (activity type `.walking`, indoor) so it keeps counting with the screen
  off, and collects live heart rate + active energy from the Watch's
  sensors.
- Step count is estimated from a **cadence-vs-speed model**, calibrated by
  you (tap the gear icon -> calibrate two speed points), since stride length
  isn't constant across walking speeds. Between calibrated points, cadence
  is linearly interpolated/extrapolated.
- On **Stop**, the workout (with heart rate/calories) and the estimated step
  count are saved to Apple Health.

## Controls

- **Digital Crown** - adjust speed in 0.5 km/h steps (1.0-10 km/h), can be
  turned mid-walk.
- **Double tap** (Apple Watch Series 9+ hardware gesture) - Start/Stop,
  without touching the screen.
- **Gear icon** - open calibration.

## Requirements

- Xcode with a watchOS 10+ deployment target
- A personal (free) or paid Apple Developer account for on-device signing
- Developer Mode enabled on the paired Apple Watch

## Setup

1. Open `WalkPadSteps.xcodeproj` in Xcode.
2. Select the `WalkPadSteps Watch App` target - Signing & Capabilities -
   set your Team (Automatically manage signing).
3. Do the same for the `WalkPadSteps` container target.
4. Select your paired Watch as the run destination and hit Run.

## Redeploying

A free Apple ID's provisioning profile expires after 7 days. Run
`./deploy.sh` (needs full Xcode, not just Command Line Tools) to
rebuild and reinstall onto your paired Watch - it auto-detects the device,
so it can also be scheduled via cron for unattended redeploys.

## Known limitations

- watchOS only allows one active `HKWorkoutSession` system-wide - starting
  a separate real workout (e.g. in Fitness) while this is running will
  interrupt it. This app is intended to be *the* workout for a walking pad
  session, not to run alongside another one.
- Step counts are an estimate based on your calibration, not a direct
  sensor measurement.
