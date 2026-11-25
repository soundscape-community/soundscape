//
//  PreviewControlView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI
import UIKit

protocol PreviewControlDelegate: AnyObject {
    func previewControl(_ viewController: PreviewControlViewController, didSelect edge: RoadAdjacentDataView?)
}

class PreviewControlViewController: UIHostingController<PreviewControlView> {
    typealias State = VirtualLocationViewController.State

    private let model = PreviewControlModel()
    private var headingSubscriber: Heading?
    weak var delegate: PreviewControlDelegate?

    var currentState: State {
        get { model.state }
        set {
            guard model.state != newValue else { return }
            model.state = newValue
            if case .orientation = newValue {
                model.heading = headingSubscriber?.value ?? 0
            }
        }
    }

    init() {
        super.init(rootView: PreviewControlView(model: model))
        model.select = { [weak self] in
            guard let self else { return }
            if case .edge(let edge) = self.currentState {
                self.delegate?.previewControl(self, didSelect: edge)
            } else {
                self.delegate?.previewControl(self, didSelect: nil)
            }
        }
        sizingOptions = .preferredContentSize
    }

    @available(*, unavailable)
    required dynamic init?(coder: NSCoder) { fatalError("Use init()") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        headingSubscriber = AppContext.shared.geolocationManager.heading(orderedBy: [.device])
        model.heading = headingSubscriber?.value ?? 0
        headingSubscriber?.onHeadingDidUpdate { [weak self] heading in
            guard let value = heading?.value else { return }
            DispatchQueue.main.async {
                guard let self, case .orientation = self.currentState else { return }
                self.model.heading = value
            }
        }
    }

    deinit {
        headingSubscriber?.onHeadingDidUpdate(nil)
    }
}

final class PreviewControlModel: ObservableObject {
    @Published var state: VirtualLocationViewController.State = .orientation
    @Published var heading = 0.0
    var select: () -> Void = {}

    var labels: (title: String, subtitle: String, spoken: String?) {
        switch state {
        case .orientation:
            let instructions = GDLocalizedString("preview.callout.road_finder.instructions")
            guard FeatureFlag.isEnabled(.developerTools) else { return (instructions, " ", instructions) }
            let degrees = String(Int(heading.rounded(.toNearestOrEven)))
            if let direction = CardinalDirection(direction: heading) {
                let title = GDLocalizedString("preview.content.orientation.text.with_cardinal", degrees, direction.localizedAbbreviatedString)
                let spoken = GDLocalizedString("preview.content.orientation.text.with_cardinal", degrees, direction.localizedString)
                return (title, " ", spoken)
            }
            let title = GDLocalizedString("preview.content.orientation.text.without_cardinal", degrees)
            return (title, " ", title)
        case .edge(let edge):
            let road = edge.direction.road.localizedName
            let subtitle = GDLocalizedString("preview.next_intersection.label", edge.endpoint.localizedName)
            guard let direction = CardinalDirection(direction: edge.direction.bearing) else {
                return (road, subtitle, road + "\n" + subtitle)
            }
            let title = GDLocalizedString("preview.content.edge.text", direction.localizedAbbreviatedString, road)
            let spoken = GDLocalizedString("preview.content.edge.text", direction.localizedString, road)
            return (title, subtitle, spoken + "\n" + subtitle)
        case .transition:
            return (" ", " ", nil)
        }
    }
}

struct PreviewControlView: View {
    @ObservedObject var model: PreviewControlModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let labels = model.labels
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(verbatim: labels.title)
                    .foregroundStyle(Color("Foreground 1"))
                Text(verbatim: labels.subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color("Foreground 3"))
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: labels.spoken ?? ""))
            .accessibilityHidden(labels.spoken == nil)

            Button(action: model.select) {
                arrow
                    .frame(width: 88, height: 88)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(GDLocalizedTextView("preview.go.title"))
            .accessibilityHint(GDLocalizedTextView("preview.content.edge.text.accessibility_hint"))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var arrow: some View {
        switch model.state {
        case .orientation:
            image("preview_arrow").rotationEffect(.degrees(model.heading))
        case .edge:
            animatedArrow(prefix: "go_animation")
        case .transition:
            animatedArrow(prefix: "travel")
        }
    }

    private func animatedArrow(prefix: String) -> some View {
        TimelineView(.animation(minimumInterval: 0.25, paused: reduceMotion)) { timeline in
            let frame = reduceMotion ? 1 : 2 + Int(timeline.date.timeIntervalSinceReferenceDate * 4) % 4
            image(prefix + String(frame))
        }
    }

    private func image(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}
