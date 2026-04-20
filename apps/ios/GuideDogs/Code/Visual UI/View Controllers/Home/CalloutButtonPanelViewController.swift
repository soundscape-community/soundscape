//
//  CalloutButtonViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

extension Notification.Name {
    static let didToggleLocate = Notification.Name("DidToggleLocate")
    static let didToggleOrientate = Notification.Name("DidToggleOrientate")
    static let didToggleLookAhead = Notification.Name("DidToggleLookAhead")
    static let didToggleMarkedPoints = Notification.Name("DidToggleMarkedPoints")
}

class CalloutButtonPanelViewController: UIHostingController<CalloutButtonPanelView> {

    private let model: CalloutButtonPanelModel

    var logContext: String? {
        get {
            model.logContext
        }
        set {
            model.logContext = newValue
        }
    }

    // MARK: Initialization

    init() {
        let model = CalloutButtonPanelModel()
        self.model = model

        super.init(rootView: CalloutButtonPanelView(model: model))

        view.backgroundColor = .clear
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        let model = CalloutButtonPanelModel()
        self.model = model

        super.init(coder: aDecoder, rootView: CalloutButtonPanelView(model: model))

        view.backgroundColor = .clear
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(self.handleDidToggleLocateNotification), name: Notification.Name.didToggleLocate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleDidToggleOrientateNotification), name: Notification.Name.didToggleOrientate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleDidToggleLookAheadNotification), name: Notification.Name.didToggleLookAhead, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleDidToggleMarkedPointsNotification), name: Notification.Name.didToggleMarkedPoints, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let width = preferredContentSize.width
        let height = UIView.preferredContentHeightCompressedHeight(for: view)

        preferredContentSize = CGSize(width: width, height: height)
    }

    // MARK: Notifications

    @objc func handleDidToggleLocateNotification(_ notification: Notification) {
        model.perform(.locate, sender: notification.object as AnyObject?)
    }

    @objc func handleDidToggleOrientateNotification(_ notification: Notification) {
        model.perform(.aroundMe, sender: notification.object as AnyObject?)
    }

    @objc func handleDidToggleLookAheadNotification(_ notification: Notification) {
        model.perform(.aheadOfMe, sender: notification.object as AnyObject?)
    }

    @objc func handleDidToggleMarkedPointsNotification(_ notification: Notification) {
        model.perform(.nearbyMarkers, sender: notification.object as AnyObject?)
    }

}

final class CalloutButtonPanelModel: ObservableObject {

    @Published var activeAction: CalloutButtonPanelAction?

    var logContext: String?

    func perform(_ action: CalloutButtonPanelAction, sender: AnyObject? = nil) {
        activeAction = action

        let completion: (Bool) -> Void = { [weak self] _ in
            DispatchQueue.main.async {
                guard self?.activeAction == action else {
                    return
                }

                self?.activeAction = nil
            }
        }

        let event: Event

        if action == .locate,
           let preview = AppContext.shared.eventProcessor.activeBehavior as? PreviewBehavior<IntersectionDecisionPoint> {
            event = PreviewMyLocationEvent(current: preview.currentDecisionPoint.value, completionHandler: completion)
        } else {
            event = ExplorationModeToggled(action.mode, sender: sender, logContext: logContext, completion: completion)
        }

        AppContext.process(event)
    }

}

enum CalloutButtonPanelAction: CaseIterable, Identifiable {
    case locate
    case aroundMe
    case aheadOfMe
    case nearbyMarkers

    var id: Self {
        self
    }

    var mode: ExplorationGenerator.Mode {
        switch self {
        case .locate:
            return .locate
        case .aroundMe:
            return .aroundMe
        case .aheadOfMe:
            return .aheadOfMe
        case .nearbyMarkers:
            return .nearbyMarkers
        }
    }

    var title: String {
        switch self {
        case .locate:
            return GDLocalizedString("ui.action_button.my_location")
        case .aroundMe:
            return GDLocalizedString("ui.action_button.around_me")
        case .aheadOfMe:
            return GDLocalizedString("ui.action_button.ahead_of_me")
        case .nearbyMarkers:
            return GDLocalizedString("ui.action_button.nearby_markers")
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .locate:
            return GDLocalizedString("directions.my_location")
        case .aroundMe:
            return GDLocalizedString("help.orient.page_title")
        case .aheadOfMe:
            return GDLocalizedString("help.explore.page_title")
        case .nearbyMarkers:
            return GDLocalizedString("callouts.nearby_markers")
        }
    }

    var accessibilityHint: String {
        switch self {
        case .locate:
            return GDLocalizedString("ui.action_button.my_location.acc_hint")
        case .aroundMe:
            return GDLocalizedString("ui.action_button.around_me.acc_hint")
        case .aheadOfMe:
            return GDLocalizedString("ui.action_button.ahead_of_me.acc_hint")
        case .nearbyMarkers:
            return GDLocalizedString("ui.action_button.nearby_markers.acc_hint")
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .locate:
            return "btn.mylocation"
        case .aroundMe:
            return "btn.aroundme"
        case .aheadOfMe:
            return "btn.aheadofme"
        case .nearbyMarkers:
            return "btn.nearbymarkers"
        }
    }

    var imageName: String {
        switch self {
        case .locate:
            return "my_location_32px"
        case .aroundMe:
            return "ic_open_with_white_new"
        case .aheadOfMe:
            return "ic_track_changes_white_new"
        case .nearbyMarkers:
            return "ic_markers_32px"
        }
    }
}

struct CalloutButtonPanelView: View {

    @ObservedObject var model: CalloutButtonPanelModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(GDLocalizedString("callouts.panel.title").uppercasedWithAppLocale())
                .font(.caption)
                .foregroundColor(.primaryForeground)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            HStack(spacing: 0) {
                ForEach(CalloutButtonPanelAction.allCases) { action in
                    CalloutButton(
                        action: action,
                        isActive: model.activeAction == action
                    ) {
                        model.perform(action)
                    }
                }
            }
            .padding(.top, 4)
        }
        .background(Color.clear)
    }

}

private struct CalloutButton: View {

    let action: CalloutButtonPanelAction
    let isActive: Bool
    let perform: () -> Void

    var body: some View {
        Button(action: perform) {
            VStack(spacing: 4) {
                ZStack {
                    Image(action.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .opacity(isActive ? 0.0 : 1.0)

                    if isActive {
                        CalloutActivityIndicator()
                            .frame(width: 28, height: 28)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: 32, height: 32)

                Text(action.title)
                    .font(.footnote)
                    .foregroundColor(.primaryForeground)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(action.accessibilityLabel))
        .accessibilityHint(Text(action.accessibilityHint))
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }

}

private struct CalloutActivityIndicator: View {

    private let beginTimes: [TimeInterval] = [0.77, 0.29, 0.28, 0.74]
    private let durations: [TimeInterval] = [1.26, 0.43, 1.01, 0.73]
    private let barWidth: CGFloat = 4.0

    var body: some View {
        TimelineView(.animation) { timeline in
            HStack(spacing: barWidth) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: barWidth / 2.0)
                        .fill(Color.primaryForeground)
                        .frame(width: barWidth, height: 28.0)
                        .scaleEffect(scale(for: index, at: timeline.date))
                }
            }
            .frame(width: 28.0, height: 28.0)
        }
    }

    private func scale(for index: Int, at date: Date) -> CGFloat {
        let duration = durations[index]
        let shiftedTime = date.timeIntervalSinceReferenceDate - beginTimes[index]
        let progress = positiveRemainder(shiftedTime, dividedBy: duration) / duration
        let easedProgress = (1.0 - cos(progress * 2.0 * .pi)) / 2.0

        return 1.0 - CGFloat(easedProgress * 0.5)
    }

    private func positiveRemainder(_ value: TimeInterval, dividedBy divisor: TimeInterval) -> TimeInterval {
        let remainder = value.truncatingRemainder(dividingBy: divisor)
        return remainder >= 0.0 ? remainder : remainder + divisor
    }

}
