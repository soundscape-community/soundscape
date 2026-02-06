import Foundation
import Testing

@testable import SSDataStructures

struct SSDataStructuresTests {

    @Test
    func boundedStackRespectsBoundAndOrder() {
        var stack = BoundedStack<Int>(bound: 2)
        stack.push(1)
        stack.push(2)
        stack.push(3)

        #expect(stack.count == 2)
        #expect(stack.elements == [2, 3])
        #expect(stack.peek() == 3)
    }

    @Test
    func boundedStackBulkPushTrimAndRemove() {
        var stack = BoundedStack<Int>(bound: 3)
        stack.push(contentsOf: [1, 2, 3, 4])

        #expect(stack.elements == [2, 3, 4])

        let removed = stack.remove { $0 % 2 == 0 }
        #expect(removed == [2, 4])
        #expect(stack.elements == [3])

        stack.clear()
        #expect(stack.isEmpty)
    }

    @Test
    func queueProvidesFIFOAndEmptyBehavior() {
        var queue = Queue<Int>()

        #expect(queue.isEmpty)
        #expect(queue.dequeue() == nil)

        queue.enqueue(10)
        queue.enqueue(20)
        queue.enqueue(30)

        #expect(queue.count == 3)
        #expect(queue.peek() == 10)
        #expect(queue.dequeue() == 10)
        #expect(queue.dequeue() == 20)
        #expect(queue.dequeue() == 30)
        #expect(queue.dequeue() == nil)
        #expect(queue.isEmpty)
    }

    @Test
    func circularQuantityNormalizesAndConverts() {
        let over = CircularQuantity(valueInDegrees: 370).normalized()
        let under = CircularQuantity(valueInDegrees: -10).normalized()
        let pi = CircularQuantity(valueInRadians: .pi)

        #expect(abs(over.valueInDegrees - 10.0) < 0.000_001)
        #expect(abs(under.valueInDegrees - 350.0) < 0.000_001)
        #expect(abs(pi.valueInDegrees - 180.0) < 0.000_001)

        let sum = CircularQuantity(valueInDegrees: 350) + CircularQuantity(valueInDegrees: 20)
        #expect(abs(sum.valueInDegrees - 10.0) < 0.000_001)

        let difference = CircularQuantity(valueInDegrees: 10) - CircularQuantity(valueInDegrees: 20)
        #expect(abs(difference.valueInDegrees - 350.0) < 0.000_001)
    }

    @Test
    func threadSafeValueEventuallyPublishesWrites() async {
        let value = ThreadSafeValue<Int>(qos: .userInitiated)
        value.value = 42

        let observed = await eventually(timeout: 1.0) { value.value }
        #expect(observed == 42)
    }

    @Test
    func threadSafeValueHandlesConcurrentWrites() async {
        let value = ThreadSafeValue<Int>(qos: .userInitiated)
        let group = DispatchGroup()

        for i in 0 ..< 100 {
            DispatchQueue.global(qos: .userInitiated).async(group: group) {
                value.value = i
            }
        }

        await withCheckedContinuation { continuation in
            group.notify(queue: .global(qos: .userInitiated)) {
                continuation.resume()
            }
        }

        let observed = await eventually(timeout: 1.0) { value.value }
        #expect(observed != nil)

        if let observed {
            #expect((0 ..< 100).contains(observed))
        }
    }

    @Test
    func tokenSortsDeterministicallyAndIntersects() {
        let a = Token(string: "b a a", separatedBy: " ")
        let b = Token(string: "c b", separatedBy: " ")
        let intersection = a.intersection(other: b)

        #expect(a.tokenizedString == "a b")
        #expect(b.tokenizedString == "b c")
        #expect(intersection.tokenizedString == "b")
    }

    @Test
    func circularQuantityArrayStatsComputeExpectedValues() {
        let values: [CircularQuantity] = [
            CircularQuantity(valueInDegrees: 350),
            CircularQuantity(valueInDegrees: 10),
        ]

        let mean = values.meanInDegrees()
        let stdev = values.stdevInDegrees()

        #expect(mean != nil)
        #expect(stdev != nil)

        if let mean {
            #expect(abs(mean - 0.0) < 0.000_001)
        }

        if let stdev {
            #expect(stdev > 9.9)
            #expect(stdev < 10.1)
        }
    }

    private func eventually<T>(timeout: TimeInterval, value: @escaping () -> T?) async -> T? {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if let current = value() {
                return current
            }

            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        return value()
    }
}
