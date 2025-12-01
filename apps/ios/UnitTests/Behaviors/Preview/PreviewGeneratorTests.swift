import XCTest
import CoreLocation
@testable import Soundscape

@MainActor
final class PreviewGeneratorTests: XCTestCase {
    func testHandlePlaysCallouts() async {
        let generator = PreviewGenerator<MockDecisionPoint>()
        let delegate = MockBehaviorDelegate()
        let expectation = expectation(description: "playCallouts invoked")
        delegate.playCalloutsHandler = { group in
            XCTAssertEqual(group.logContext, "preview.start")
            expectation.fulfill()
            return true
        }

        let start = MockDecisionPoint.sample()
        let origin = LocationDetail(location: CLLocation(latitude: 47.0, longitude: -122.0))
        let event = PreviewStartedEvent(at: start, from: origin)

        let result = await generator.handle(event: event, verbosity: .normal, delegate: delegate)
        XCTAssertNil(result)
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(delegate.playCalloutsCount, 1)
    }

    func testHandleSkipsUnsupportedEvent() async {
        let generator = PreviewGenerator<MockDecisionPoint>()
        let delegate = MockBehaviorDelegate()
        let unsupported = BehaviorActivatedEvent()

        let result = await generator.handle(event: unsupported, verbosity: .normal, delegate: delegate)
        XCTAssertNil(result)
        XCTAssertEqual(delegate.playCalloutsCount, 0)
    }
}

// MARK: - Test Doubles

@MainActor
private final class MockBehaviorDelegate: BehaviorDelegate {
    var playCalloutsCount = 0
    var lastPlayedGroup: CalloutGroup?
    var playCalloutsHandler: ((CalloutGroup) async -> Bool)?

    func interruptCurrent(clearQueue: Bool, playHush: Bool) { }

    func process(_ event: Event) { }

    func playCallouts(_ group: CalloutGroup) async -> Bool {
        playCalloutsCount += 1
        lastPlayedGroup = group
        if let handler = playCalloutsHandler {
            return await handler(group)
        }
        return true
    }
}

@MainActor
private struct MockDecisionPoint: RootedPreviewGraph {
    struct Node: Equatable, Locatable, Localizable {
        let id = UUID()
        let localizedName: String
        let location: CLLocation
    }

    @MainActor
    struct Edge: AdjacentDataView {
        typealias Path = MockDirection
        typealias Adjacent = String
        typealias DecisionPoint = MockDecisionPoint

        var endpoint: Node
        var direction: MockDirection
        var adjacent: [String] = []
        var isSupported: Bool = true

        func decisionPointForEndpoint() -> MockDecisionPoint {
            MockDecisionPoint(node: endpoint)
        }

        func makeCalloutsForAdjacents() -> [CalloutProtocol] {
            [StringCallout(.preview, "adjacent")]
        }

        func makeCalloutsForFocusEvent() -> [CalloutProtocol] {
            [StringCallout(.preview, "focus")]
        }

        func makeCalloutsForLongFocusEvent(from: Node) -> [CalloutProtocol] {
            [StringCallout(.preview, "long focus")]
        }

        func makeCalloutsForSelectedEvent(from previousEdgeData: Edge) -> [CalloutProtocol] {
            [StringCallout(.preview, "selected")]
        }
    }

    typealias Root = Node
    typealias EdgeData = Edge

    var node: Node
    var edges: [Edge]

    init(node: Node) {
        self.node = node
        self.edges = []
    }

    func makeCallouts(previous: MockDecisionPoint) -> [CalloutProtocol] {
        [StringCallout(.preview, "callout from \(previous.node.localizedName)")]
    }

    func makeInitialCallouts(resumed: Bool) -> [CalloutProtocol] {
        let message = resumed ? "resume" : "start"
        return [StringCallout(.preview, message)]
    }

    func refreshed() -> MockDecisionPoint {
        self
    }

    static func sample(name: String = "start", latitude: CLLocationDegrees = 47.0, longitude: CLLocationDegrees = -122.0) -> MockDecisionPoint {
        let node = Node(localizedName: name, location: CLLocation(latitude: latitude, longitude: longitude))
        return MockDecisionPoint(node: node)
    }
}

private struct MockDirection: Orientable, Equatable {
    var bearing: CLLocationDirection
    init(bearing: CLLocationDirection = 0.0) {
        self.bearing = bearing
    }
}
