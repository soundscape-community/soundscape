//
//  CalloutButtonPanelView.swift
//  Soundscape
//
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

struct CalloutButtonPanelView: View {

    private let logContext: String?

    @State private var activeAction: CalloutButtonPanelAction?

    init(logContext: String?) {
        self.logContext = logContext
    }

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
                        isActive: activeAction == action
                    ) {
                        perform(action)
                    }
                }
            }
            .padding(.top, 4)
        }
        .background(Color.clear)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.didToggleLocate)) { notification in
            perform(.locate, sender: notification.object as AnyObject?)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.didToggleOrientate)) { notification in
            perform(.aroundMe, sender: notification.object as AnyObject?)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.didToggleLookAhead)) { notification in
            perform(.aheadOfMe, sender: notification.object as AnyObject?)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.didToggleMarkedPoints)) { notification in
            perform(.nearbyMarkers, sender: notification.object as AnyObject?)
        }
    }

    private func perform(_ action: CalloutButtonPanelAction, sender: AnyObject? = nil) {
        activeAction = action

        let completion: (Bool) -> Void = { _ in
            DispatchQueue.main.async {
                guard activeAction == action else {
                    return
                }

                activeAction = nil
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

private enum CalloutButtonPanelAction: CaseIterable, Identifiable {
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
