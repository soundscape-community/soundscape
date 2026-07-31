//
//  PreviewTutorialViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SDWebImageSwiftUI
import SwiftUI
import UIKit

protocol PreviewTutorialDelegate: AnyObject {
    func previewTutorialDidComplete()
}

struct PreviewTutorialView: View {
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Image("Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 48) {
                        section(title: GDLocalizedString("preview.tutorial.title.1"),
                                content: GDLocalizedString("preview.tutorial.content.1"),
                                imageName: "Welcome1.gif",
                                titleFont: .largeTitle)
                        section(title: GDLocalizedString("preview.tutorial.title.2"),
                                content: GDLocalizedString("preview.tutorial.content.2"),
                                imageName: "Welcome2.gif",
                                titleFont: .title)

                        VStack(spacing: 24) {
                            heading(GDLocalizedString("preview.tutorial.title.3"), font: .title)
                            content(GDLocalizedString("preview.tutorial.content.3"))
                            content(GDLocalizedString("preview.tutorial.content.4"))
                                .padding(.top, 24)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 20)
                }

                Button(GDLocalizedString("general.alert.done"), action: onDone)
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(Color(Colors.Background.quaternary ?? .black).opacity(0.9))
                    .accessibilityHint(GDLocalizedString("preview.tutorial.done.hint"))
                    .padding(.horizontal, 20)
                    .background(Color.black.opacity(0.3).ignoresSafeArea())
            }
        }
    }

    private func section(title: String,
                         content: String,
                         imageName: String,
                         titleFont: Font) -> some View {
        VStack(spacing: 24) {
            heading(title, font: titleFont)
            self.content(content)
            AnimatedImage(name: imageName)
                .resizable()
                .aspectRatio(355.0 / 163.0, contentMode: .fit)
                .cornerRadius(10)
                .accessibilityHidden(true)
                .padding(.top, 24)
        }
    }

    private func heading(_ text: String, font: Font) -> some View {
        Text(text)
            .font(font)
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity)
    }

    private func content(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
    }
}

class PreviewTutorialViewController: UIViewController {
    private weak var delegate: PreviewTutorialDelegate?
    private var didMuteCallouts = false
    private var hostingController: UIHostingController<PreviewTutorialView>?

    init(delegate: PreviewTutorialDelegate) {
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("PreviewTutorialViewController must be created programmatically")
    }

    override func loadView() {
        let hostingController = UIHostingController(rootView: PreviewTutorialView { [weak self] in
            self?.completeTutorial()
        })
        addChild(hostingController)
        view = UIView()
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if SettingsContext.shared.automaticCalloutsEnabled {
            didMuteCallouts = true
            SettingsContext.shared.automaticCalloutsEnabled = false
            AppContext.shared.eventProcessor.hush(playSound: false)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        restoreCalloutsIfNeeded()
    }

    func completeTutorial() {
        restoreCalloutsIfNeeded()
        FirstUseExperience.setDidComplete(for: .previewTutorial)
        delegate?.previewTutorialDidComplete()
    }

    func restoreCalloutsIfNeeded() {
        guard didMuteCallouts else { return }
        didMuteCallouts = false
        SettingsContext.shared.automaticCalloutsEnabled = true
    }
}
