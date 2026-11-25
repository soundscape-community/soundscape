// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import CoreMotion
import SwiftUI
import UIKit

struct RequiredPermissionView: View {
    let service: PermissionRoute
    let onAuthorized: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var instructions: Instructions?
    @State private var didFinish = false

    private struct Instructions {
        let title: String
        let image: String
        let description: [String]
        let button: String
        var requestsAuthorization = false
    }

    var body: some View {
        OnboardingContainer {
            if let instructions {
                GDLocalizedTextView(instructions.title)
                    .onboardingHeaderTextStyle()
                    .accessibilityAddTraits(.isHeader)

                Image(instructions.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 120)
                    .accessibilityHidden(true)

                ForEach(instructions.description, id: \.self) { key in
                    GDLocalizedTextView(key)
                        .onboardingTextStyle()
                }

                Button {
                    performAction(requestsAuthorization: instructions.requestsAuthorization)
                } label: {
                    GDLocalizedTextView(instructions.button)
                        .onboardingButtonTextStyle()
                }
            }
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        guard !didFinish else { return }
        switch service {
        case .location:
            let location = AppContext.shared.geolocationManager
            if !location.coreLocationServicesEnabled {
                instructions = .init(title: "general.error.location_services_enable", image: "map-marker-radius",
                                     description: ["general.error.location_services_enable_description", "general.error.location_services_enable_instructions.2"],
                                     button: "general.alert.open_settings")
                return
            }

            switch location.coreLocationAuthorizationStatus {
            case .fullAccuracyLocationAuthorized:
                finish()
            case .notDetermined:
                instructions = .init(title: "location", image: "permissions-location",
                                     description: ["first_launch.location.text", "first_launch.permission_required"],
                                     button: "first_launch.location.enable_location", requestsAuthorization: true)
            case .reducedAccuracyLocationAuthorized:
                instructions = .init(title: "general.error.location_services.authorize.title", image: "map-marker-radius",
                                     description: ["general.error.location_services.authorize.description", "general.error.location_services.precise_location.instructions"],
                                     button: "general.alert.open_settings")
            default:
                instructions = .init(title: "general.error.location_services.authorize.title", image: "map-marker-radius",
                                     description: ["general.error.location_services.authorize.description", "general.error.location_services.authorize.instructions"],
                                     button: "general.alert.open_settings")
            }
        case .motion:
            switch CMMotionActivityManager.authorizationStatus() {
            case .authorized:
                finish()
            case .notDetermined:
                instructions = .init(title: "first_launch.device_motion", image: "permissions-device",
                                     description: ["first_launch.device_motion.text", "first_launch.permission_required"],
                                     button: "device_motion.authorize.title", requestsAuthorization: true)
            case .restricted:
                instructions = .init(title: "device_motion.enable.title", image: "map-marker-radius",
                                     description: ["device_motion.enable.description", "device_motion.enable.instructions"],
                                     button: "general.alert.open_settings")
            default:
                instructions = .init(title: "device_motion.authorize.title", image: "map-marker-radius",
                                     description: ["device_motion.authorize.description", "device_motion.authorize.instructions"],
                                     button: "general.alert.open_settings")
            }
        }
    }

    private func performAction(requestsAuthorization: Bool) {
        if requestsAuthorization {
            switch service {
            case .location:
                AppContext.shared.geolocationManager.requestCoreLocationAuthorization()
            case .motion:
                MotionActivityContext.requestAuthorization { _, _ in refresh() }
            }
        } else if let settings = URL(string: UIApplication.openSettingsURLString) {
            openURL(settings)
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onAuthorized()
    }
}
