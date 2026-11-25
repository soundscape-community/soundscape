//
//  LoadingModalView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

struct LoadingModalView: View {
    let message: String

    var body: some View {
        ProgressView {
            Text(verbatim: message)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .controlSize(.large)
        .tint(.primaryForeground)
        .foregroundStyle(Color.primaryForeground)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background Shadow").ignoresSafeArea())
    }
}
