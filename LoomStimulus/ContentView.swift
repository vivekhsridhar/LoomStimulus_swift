//
//  ContentView.swift
//  LoomStimulus
//
//  Created by Vivek Hari Sridhar on 1/30/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var model = LoomModel()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                ZStack {
                    Color.white.ignoresSafeArea()

                    if model.trigger {
                        Circle()
                            .fill(Color.black)
                            .frame(width: model.radius * 2,
                                   height: model.radius * 2)
                            .position(x: geo.size.width / 2,
                                      y: geo.size.height / 2)
                    }
                }
                .onChange(of: timeline.date) {
                    model.tick(now: timeline.date.timeIntervalSince1970)
                }
            }
        }
        .statusBarHidden(true)
    }
}

@MainActor
final class LoomModel: ObservableObject {
    // Loom parameters
    @Published var size: Double = 100.0       // "physical size" * projection scale
    @Published var dist: Double = 100.0       // distance from eye
    @Published var speed: Double = 5.0        // distance units per second
    @Published var radius: Double = 0.0       // projected radius

    // Triggering / timing
    @Published var trigger: Bool = false
    var lag: Double = -1.0                    // delay to prevent app from scheduling the first stimulus instantly
    var timeInterval: Double = 10.0           // mean waiting time between successive looms
    var maxInterval: Double = 60.0            // maximum waiting time between successive looms

    // Internal clock state
    private var startTime: Double?
    private var lastNow: Double?
    private var nextTriggerTime: Double?

    private func drawTruncatedExponential(mean: Double, tMax: Double) -> Double {
        let u = Double.random(in: 0..<1)
        return min(-mean * log(1.0 - u), tMax)
    }

    func tick(now: Double) {
        if startTime == nil { startTime = now }
        let elapsed = now - (startTime ?? now)

        // Compute dt (seconds since last frame)
        let dt: Double
        if let last = lastNow {
            dt = max(0.0, min(now - last, 0.1)) // clamp to avoid huge jumps
        } else {
            dt = 0.0
        }
        lastNow = now

        // Poisson-based triggering (only when no stimulus is active)
        if !trigger {
            if nextTriggerTime == nil {
                // First draw (after lag)
                if elapsed > lag {
                    nextTriggerTime = now + drawTruncatedExponential(mean: timeInterval, tMax: maxInterval)
                }
            } else if now >= nextTriggerTime! {
                trigger = true
                nextTriggerTime = nil   // will be redrawn after this stimulus ends
            }
        }

        guard trigger else { return }

        // Loom approach
        if dist > Double.leastNonzeroMagnitude {
            dist -= speed * dt
            if dist <= Double.leastNonzeroMagnitude {
                dist = Double.leastNonzeroMagnitude
            }
        }

        // Projected radius (looming geometry)
        radius = size / dist

        // Reset and schedule next poisson trigger
        if dist <= Double.leastNonzeroMagnitude {
            dist = 100.0
            trigger = false
            radius = 0.0

            nextTriggerTime = now + drawTruncatedExponential(mean: timeInterval, tMax: maxInterval)
        }
    }
}

