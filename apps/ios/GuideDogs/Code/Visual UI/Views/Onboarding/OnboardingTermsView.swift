//
//  OnboardingTermsView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

struct OnboardingTermsView: View {
    
    @EnvironmentObject private var viewModel: OnboardingViewModel

    var body: some View {
        FirstLaunchTermsView {
            viewModel.open(.finish)
        }
    }
}

struct FirstLaunchTermsView_Previews: PreviewProvider {
    
    static var previews: some View {
        OnboardingTermsView().environmentObject(OnboardingViewModel())
    }
    
}
