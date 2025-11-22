//
//  OnboardingViewModel.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import SwiftUI

@MainActor
class OnboardingViewModel: ObservableObject {
    
    // MARK: Properties
    
    var dismiss: () -> Void
    
    // MARK: Initialization
    
    init(dismiss: @escaping () -> Void = { }) {
        self.dismiss = dismiss
    }
    
}
