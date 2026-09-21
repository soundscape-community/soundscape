//
//  BeaconSelectionView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

struct BeaconSelectionView: View {
    
    let beaconDemo = BeaconDemoHelper()
    
    @State var isPresented: Bool = false
    @State var selectedBeaconKey: String
    @State var areMelodiesEnabled: Bool
    @State var arrivalDistance: Double
    @State var beaconRingingAngle: Double
    
    let initialBeacon: String
    let initialMelodies: Bool
    
    init() {
        _selectedBeaconKey = State(initialValue: SettingsContext.shared.selectedBeacon)
        _areMelodiesEnabled = State(initialValue: SettingsContext.shared.playBeaconStartAndEndMelodies)
        _arrivalDistance = State(initialValue: SettingsContext.shared.enterImmediateVicinityDistance)
        _beaconRingingAngle = State(initialValue: SettingsContext.shared.beaconRingingAngle)
        initialBeacon = SettingsContext.shared.selectedBeacon
        initialMelodies = SettingsContext.shared.playBeaconStartAndEndMelodies
    }
    
    var body: some View {
        ZStack {
            Color.quaternaryBackground.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 0) {
                    Toggle(GDLocalizedString("beacon.settings.melodies"), isOn: $areMelodiesEnabled)
                        .locationNameTextFormat()
                        .padding()
                        .background(Color.primaryBackground)
                        .onChange(of: areMelodiesEnabled, perform: { _ in
                            SettingsContext.shared.playBeaconStartAndEndMelodies = areMelodiesEnabled
                            beaconDemo.play(styleChanged: true)
                        })

                    SettingStepper(
                        value: $arrivalDistance,
                        titleLocalization: "beacon.settings.arrival_distance",
                        unitsLocalization: "distance.format.meters",
                        stepSize: SettingsContext.ArrivalDistance.step,
                        minValue: SettingsContext.ArrivalDistance.minimum,
                        maxValue: SettingsContext.ArrivalDistance.maximum
                    )
                    .onChange(of: arrivalDistance, perform: { _ in
                        SettingsContext.shared.enterImmediateVicinityDistance = arrivalDistance
                    })

                    HStack(spacing: 0) {
                        GDLocalizedTextView("beacon.settings.arrival_distance.explanation")
                            .font(.caption)
                            .foregroundColor(.primaryForeground)
                            .padding()

                        Spacer()
                    }

                    BeaconAngleSlider(current: beaconRingingAngle) { newValue in
                        beaconRingingAngle = newValue
                        SettingsContext.shared.beaconRingingAngle = newValue
                    }

                    HStack(spacing: 0) {
                        GDLocalizedTextView("beacon.settings.ringing_angle.explanation")
                            .font(.caption)
                            .foregroundColor(.primaryForeground)
                            .padding()

                        Spacer()
                    }

                    TableHeaderCell(text: GDLocalizedString("beacon.settings.style"))

                    HStack(spacing: 0) {
                        GDLocalizedTextView("beacon.settings.explanation")
                            .font(.caption)
                            .foregroundColor(.primaryForeground)
                            .padding()
                        
                        Spacer()
                    }
                    
                    ForEach(BeaconOption.allAvailableCases(for: .standard)) { details in
                        BeaconOptionCell(type: details.id,
                                         displayName: details.localizedName,
                                         selectedType: $selectedBeaconKey) {
                            beaconDemo.play(styleChanged: true, shouldTimeOut: false)
                        }
                    }
                    
                    if let beacons = BeaconOption.allAvailableCases(for: .haptic) as? [BeaconOption], !beacons.isEmpty {
                        TableHeaderCell(text: GDLocalizedString("beacon.settings.style.haptic"))
                        
                        HStack(spacing: 0) {
                            GDLocalizedTextView("beacon.settings.style.haptic.explanation")
                                .font(.caption)
                                .foregroundColor(.primaryForeground)
                                .padding()
                            
                            Spacer()
                        }
                        
                        ForEach(beacons) { details in
                            BeaconOptionCell(type: details.id,
                                             displayName: details.localizedName,
                                             selectedType: $selectedBeaconKey) {
                                beaconDemo.play(styleChanged: true, shouldTimeOut: false)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(GDLocalizedString("beacon.settings_title"))
        .onAppear {
            beaconDemo.prepare(disableMelodies: false)
            
            GDATelemetry.trackScreenView("beacon_settings")
            
            isPresented = true
        }
        .onDisappear(perform: {
            if SettingsContext.shared.selectedBeacon != initialBeacon {
                let props = [
                    "from": initialBeacon,
                    "to": selectedBeaconKey
                ]
                
                GDATelemetry.track("beacon.style_changed", with: props)
            }
            
            if SettingsContext.shared.playBeaconStartAndEndMelodies != initialMelodies {
                if initialMelodies {
                    GDATelemetry.track("beacon.melodiesDisabled")
                } else {
                    GDATelemetry.track("beacon.melodiesEnabled")
                }
            }
            
            beaconDemo.restoreState()
            
            isPresented = false
        })
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            guard isPresented else {
                return
            }
            
            beaconDemo.prepare(disableMelodies: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            guard isPresented else {
                return
            }
            
            beaconDemo.restoreState()
        }
    }
}

struct BeaconSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        BeaconSelectionView()
            
    }
}
