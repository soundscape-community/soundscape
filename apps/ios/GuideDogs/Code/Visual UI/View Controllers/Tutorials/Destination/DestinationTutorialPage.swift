//
//  DestinationTutorialPage.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import AVFoundation
import SwiftUI
import UIKit

enum DestinationTutorialAction: Equatable {
    case setBeacon
}

final class DestinationTutorialViewState: ObservableObject {
    @Published private(set) var title: String
    @Published private(set) var image: UIImage
    @Published private(set) var text: String
    @Published private(set) var actionTitle: String?
    @Published private(set) var action: DestinationTutorialAction?
    @Published private(set) var isActionVisible: Bool
    @Published private(set) var exitTitle: String

    init(title: String,
         image: UIImage,
         text: String,
         actionTitle: String? = nil,
         action: DestinationTutorialAction? = nil,
         exitTitle: String = GDLocalizedString("tutorial.exit")) {
        self.title = title
        self.image = image
        self.text = text
        self.actionTitle = actionTitle
        self.action = action
        self.isActionVisible = actionTitle != nil && action != nil
        self.exitTitle = exitTitle
    }

    func updateText(_ text: String) {
        self.text = text
    }

    func setActionVisible(_ isVisible: Bool) {
        isActionVisible = isVisible && actionTitle != nil && action != nil
    }
}

struct DestinationTutorialPageView: View {
    @ObservedObject var state: DestinationTutorialViewState
    let onAction: (DestinationTutorialAction) -> Void
    let onExit: () -> Void

    private let backgroundColor = Color(Colors.Background.tutorial)

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 20) {
                ScrollView {
                    VStack(spacing: 20) {
                        Text(state.title)
                            .font(.title)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        Image(uiImage: state.image)
                            .resizable()
                            .aspectRatio(125.0 / 53.0, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .accessibilityHidden(true)

                        Text(state.text)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity)
                }

                if state.isActionVisible,
                   let actionTitle = state.actionTitle,
                   let action = state.action {
                    Button(actionTitle) {
                        onAction(action)
                    }
                    .font(.body)
                    .frame(maxWidth: .infinity, minHeight: 45)
                    .background(.white)
                    .foregroundColor(backgroundColor)
                    .cornerRadius(5)
                    .accessibilityHint(GDLocalizedString("tutorial.beacon.set_a_beacon.acc_hint"))
                    .padding(.horizontal, 32)
                }

                Button(state.exitTitle, action: onExit)
                    .font(.callout)
                    .frame(maxWidth: .infinity, minHeight: 45)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(5)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: state.text)
    }
}

protocol DestinationTutorialPageDelegate: AnyObject {
    func getEntityKey() -> String?
    func pauseBackgroundTrack(_ completion: (() -> Void)?)
    func resumeBackgroundTrack()
    func pageComplete()
    func tutorialComplete()
    func exitTutorial()
}

class DestinationTutorialPage: BaseTutorialViewController {
    let viewState: DestinationTutorialViewState
    private var hostingController: UIHostingController<DestinationTutorialPageView>?
    
    weak var delegate: DestinationTutorialPageDelegate?
    
    var entity: ReferenceEntity? {
        guard let key = delegate?.getEntityKey() else {
            return nil
        }
        
        return SpatialDataCache.referenceEntityByKey(key)
    }

    init(title: String, imageName: String, text: String,
         actionTitle: String? = nil, action: DestinationTutorialAction? = nil) {
        viewState = DestinationTutorialViewState(title: title,
                                                 image: UIImage(named: imageName)!,
                                                 text: text,
                                                 actionTitle: actionTitle,
                                                 action: action)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Destination tutorial pages must be created programmatically")
    }

    override func loadView() {
        let rootView = DestinationTutorialPageView(
            state: viewState,
            onAction: { [weak self] action in self?.perform(action) },
            onExit: { [weak self] in self?.exitPage() }
        )
        let hostingController = UIHostingController(rootView: rootView)
        addChild(hostingController)
        view = UIView()
        view.backgroundColor = Colors.Background.tutorial
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

    func perform(_ action: DestinationTutorialAction) {}

    func exitPage() {
        delegate?.exitTutorial()
    }
    
    // MARK: BaseTutorialViewController Overrides
    
    override internal func play(delay: TimeInterval = 0.0, text: String, _ completion: ((Bool) -> Void)? = nil) {
        let textToPlay = resolvedText(text, destinationName: entity?.name)
        
        super.play(delay: delay, text: textToPlay, completion)
    }

    func resolvedText(_ text: String, destinationName: String?) -> String {
        text.replacingOccurrences(of: "@!destination!!",
                                  with: destinationName ?? GDLocalizedString("tutorial.beacon.your_destination"))
    }

    override internal func updatePageText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.viewState.updateText(text)
        }
    }
}
