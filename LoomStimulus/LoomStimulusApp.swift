//
//  LoomStimulusApp.swift
//  LoomStimulus
//
//  Created by Vivek Hari Sridhar on 1/30/26.
//

import SwiftUI
import UIKit

@main
struct LoomStimulusApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Prevent dimming and automatic locking
                UIApplication.shared.isIdleTimerDisabled = true
            } else {
                // Restore normal locking when the app is inactive
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }
}
