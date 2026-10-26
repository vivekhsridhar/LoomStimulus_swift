
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
                            .frame(
                                width: model.radius * 2,
                                height: model.radius * 2
                            )
                            .position(
                                x: geo.size.width / 2,
                                y: geo.size.height / 2
                            )
                    }
                }
                .onChange(of: timeline.date) {
                    model.tick(
                        now: timeline.date.timeIntervalSince1970
                    )
                }
            }
        }
    }
}

@MainActor
final class LoomModel: ObservableObject {

    // ---------------------------------------------------------
    // Loom parameters
    // ---------------------------------------------------------
    @Published var size: Double = 100.0
    @Published var dist: Double = 100.0
    @Published var speed: Double = 5.0

    var minSpeed: Double = 3.0
    var maxSpeed: Double = 8.0

    @Published var radius: Double = 0.0

    // ---------------------------------------------------------
    // Triggering / timing
    // ---------------------------------------------------------
    @Published var trigger: Bool = false

    var lag: Double = 300.0

    // Choose the waiting-time distribution
    enum WaitingTimeDistribution {
        case exponential
        case uniform
    }

    var waitingTimeDistribution: WaitingTimeDistribution = .uniform

    // Exponential distribution parameters
    var timeInterval: Double = 10.0
    var maxInterval: Double = 60.0

    // Uniform distribution parameters
    var uniformMinInterval: Double = 0.0
    var uniformMaxInterval: Double = 60.0

    // ---------------------------------------------------------
    // Internal clock state
    // ---------------------------------------------------------
    private var startTime: Double?
    private var lastNow: Double?
    private var nextTriggerTime: Double?

    private var currentInterStimulusInterval: Double?

    // ---------------------------------------------------------
    // Output logging
    // ---------------------------------------------------------
    private var outputURL: URL?
    private var loomStartTime: Date?
    private var loomNumber: Int = 0

    // ---------------------------------------------------------
    // Initialization
    // ---------------------------------------------------------
    init() {
        createOutputFile()
    }

    // ---------------------------------------------------------
    // Create a unique CSV file for this app session
    // ---------------------------------------------------------
    private func createOutputFile() {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        let timestamp = formatter.string(from: Date())

        let filename = "loom_session_\(timestamp)_\(UUID().uuidString.prefix(6)).csv"

        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        outputURL = documents.appendingPathComponent(filename)

        let header = "loom,start_time,end_time,speed,inter_stimulus_interval\n"

        do {
            try header.write(
                to: outputURL!,
                atomically: true,
                encoding: .utf8
            )

            print("Created output file:")
            print(outputURL!.path)

        } catch {
            print("Could not create output file: \(error)")
        }
    }

    // ---------------------------------------------------------
    // Draw exponential waiting time
    // ---------------------------------------------------------
    private func drawTruncatedExponential(
        mean: Double,
        tMax: Double
    ) -> Double {

        let u = Double.random(in: 0..<1)
        return min(-mean * log(1.0 - u), tMax)
    }

    // ---------------------------------------------------------
    // Draw uniform waiting time
    // ---------------------------------------------------------
    private func drawUniformInterval(
        minInterval: Double,
        maxInterval: Double
    ) -> Double {

        return Double.random(in: minInterval...maxInterval)
    }

    // ---------------------------------------------------------
    // Select waiting-time distribution
    // ---------------------------------------------------------
    private func drawWaitingInterval() -> Double {

        switch waitingTimeDistribution {

        case .exponential:
            return drawTruncatedExponential(
                mean: timeInterval,
                tMax: maxInterval
            )

        case .uniform:
            return drawUniformInterval(
                minInterval: uniformMinInterval,
                maxInterval: uniformMaxInterval
            )
        }
    }

    // ---------------------------------------------------------
    // Write completed loom to CSV
    // ---------------------------------------------------------
    private func logLoom(endTime: Date) {

        guard let outputURL = outputURL,
              let startTime = loomStartTime else {
            return
        }

        loomNumber += 1

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        let isi = currentInterStimulusInterval ?? Double.nan

        let row = "\(loomNumber)," +
            "\(formatter.string(from: startTime))," +
            "\(formatter.string(from: endTime))," +
            "\(speed)," +
            "\(isi)\n"

        do {
            let handle = try FileHandle(
                forWritingTo: outputURL
            )

            try handle.seekToEnd()

            if let data = row.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }

            try handle.close()

        } catch {
            print("Could not write loom data: \(error)")
        }

        loomStartTime = nil
    }

    // ---------------------------------------------------------
    // Main animation / timing loop
    // ---------------------------------------------------------
    func tick(now: Double) {

        // Record when the app starts
        if startTime == nil {
            startTime = now
        }

        let elapsed = now - (startTime ?? now)

        // -----------------------------------------------------
        // Calculate time since previous frame
        // -----------------------------------------------------
        let dt: Double

        if let last = lastNow {
            dt = max(0.0, min(now - last, 0.1))
        } else {
            dt = 0.0
        }

        lastNow = now

        // -----------------------------------------------------
        // Schedule / trigger loom
        // -----------------------------------------------------
        if !trigger {

            if nextTriggerTime == nil {

                if elapsed > lag {

                    // Draw interval using selected distribution
                    let interval = drawWaitingInterval()

                    currentInterStimulusInterval = interval
                    nextTriggerTime = now + interval
                }

            } else if now >= nextTriggerTime! {

                // Draw a new speed for this loom
                speed = Double.random(in: minSpeed...maxSpeed)

                // Loom begins
                trigger = true
                loomStartTime = Date(timeIntervalSince1970: now)
                nextTriggerTime = nil
            }
        }

        guard trigger else {
            return
        }

        // -----------------------------------------------------
        // Loom approach
        // -----------------------------------------------------
        if dist > Double.leastNonzeroMagnitude {

            dist -= speed * dt

            if dist <= Double.leastNonzeroMagnitude {
                dist = Double.leastNonzeroMagnitude
            }
        }

        // -----------------------------------------------------
        // Project physical size onto screen
        // -----------------------------------------------------
        radius = size / dist

        // -----------------------------------------------------
        // Loom has reached the observer
        // -----------------------------------------------------
        if dist <= Double.leastNonzeroMagnitude {

            // Save completed loom
            logLoom(
                endTime: Date(timeIntervalSince1970: now)
            )

            // Reset loom
            dist = 100.0
            trigger = false
            radius = 0.0

            // Draw next inter-stimulus interval
            let interval = drawWaitingInterval()

            currentInterStimulusInterval = interval
            nextTriggerTime = now + interval
        }
    }
}
