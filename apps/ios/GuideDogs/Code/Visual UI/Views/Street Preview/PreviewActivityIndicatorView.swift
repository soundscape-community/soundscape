//
//  PreviewActivityIndicatorView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

final class PreviewLoadingState: ObservableObject {
    enum Phase {
        case activating(progress: Progress?)
        case deactivating
    }

    @Published var phase: Phase = .activating(progress: nil)
    @Published var isVisible = true
}

struct PreviewActivityIndicatorView: View {
    @ObservedObject var state: PreviewLoadingState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if state.isVisible {
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
            }
            .frame(maxHeight: .infinity)
            .foregroundStyle(Color.yellowHighlight)
            .background(Color.tertiaryBackground.ignoresSafeArea())
        }
    }

    private var content: some View {
        VStack(spacing: 36) {
            TimelineView(.animation(minimumInterval: 0.25, paused: reduceMotion)) { context in
                let frame = reduceMotion ? 1 : Int(context.date.timeIntervalSinceReferenceDate * 4) % 4 + 2
                Image("travel\(frame)")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 102, height: 102)
                    .accessibilityHidden(true)
            }

            switch state.phase {
            case .activating(let progress):
                if let progress {
                    PreviewDownloadProgress(progress: progress)
                        .id(ObjectIdentifier(progress))
                } else {
                    loadingLabel("general.loading.start")
                }
            case .deactivating:
                loadingLabel("general.loading.end")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
    }

    private func loadingLabel(_ key: String) -> some View {
        ProgressView {
            GDLocalizedTextView(key)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("label.getting_things_ready")
        }
        .tint(Color.yellowHighlight)
    }
}

private struct PreviewDownloadProgress: View {
    let progress: Progress
    @State private var fraction = 0.0

    var body: some View {
        ProgressView(value: fraction) {
            GDLocalizedTextView("general.loading.start")
                .font(.footnote)
                .accessibilityIdentifier("label.getting_things_ready")
        }
        .tint(Color.yellowHighlight)
        .onReceive(progress.publisher(for: \.fractionCompleted).receive(on: DispatchQueue.main)) {
            fraction = $0
        }
    }
}
