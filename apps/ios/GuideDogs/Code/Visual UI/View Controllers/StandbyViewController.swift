//
//  StandbyViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI
import UIKit

class StandbyViewController: UIHostingController<StandbyView> {
    weak var delegate: DismissableViewControllerDelegate?
    private var didSleep = false

    init() {
        super.init(rootView: StandbyView())
    }

    required dynamic init?(coder: NSCoder) {
        fatalError("Use init()")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didSleep else { return }
        didSleep = true

        view.accessibilityViewIsModal = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onAppOperationStateDidChange),
            name: .appOperationStateDidChange,
            object: nil
        )
        AppContext.shared.goToSleep()
    }

    @objc private func onAppOperationStateDidChange() {
        guard AppContext.shared.state == .normal else { return }
        NotificationCenter.default.removeObserver(self, name: .appOperationStateDidChange, object: nil)
        dismiss(animated: true) {
            self.delegate?.onDismissed(self)
        }
    }
}

struct StandbyView: View {
    @State private var isSnoozing = false
    @AccessibilityFocusState private var titleIsFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                GDLocalizedTextView(isSnoozing ? "sleep.snoozing" : "sleep.sleeping")
                    .font(.largeTitle)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleIsFocused)

                Image(isSnoozing ? "snooze_Illustration" : "sleeping_Illustration")
                    .accessibilityHidden(true)

                GDLocalizedTextView(isSnoozing ? "sleep.snoozing.message" : "sleep.sleeping.message")

                VStack(spacing: 12) {
                    if !isSnoozing {
                        Button {
                            AppContext.shared.snooze()
                            isSnoozing = true
                            titleIsFocused = true
                        } label: {
                            GDLocalizedTextView("sleep.ui.wake_on_leave")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .accessibilityLabel(Text(verbatim: GDLocalizedString("sleep.wake_up_when_i_leave")))
                    }

                    Button {
                        AppContext.shared.wakeUp()
                    } label: {
                        GDLocalizedTextView("sleep.ui.wake_up_now")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .accessibilityLabel(Text(verbatim: GDLocalizedString("sleep.wake_up_now")))
                }
                .buttonStyle(.borderedProminent)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(32)
        }
        .foregroundStyle(.white)
        .background(Color("Background 2").ignoresSafeArea())
        .accessibilityIgnoresInvertColors()
    }
}
