// Copyright (c) Soundscape Community Contributers.

import Foundation

public struct CompoundPredicate: FilterPredicate {
    private enum PredicateOperator {
        case not
        case and
        case or
    }

    private let subpredicates: [any FilterPredicate]
    private let predicateOperator: PredicateOperator

    public init(notPredicateWithSubpredicate predicate: any FilterPredicate) {
        subpredicates = [predicate]
        predicateOperator = .not
    }

    public init(andPredicatesWithSubpredicates predicates: [any FilterPredicate]) {
        subpredicates = predicates
        predicateOperator = .and
    }

    public init(orPredicateWithSubpredicates predicates: [any FilterPredicate]) {
        subpredicates = predicates
        predicateOperator = .or
    }

    public func isIncluded(_ poi: any POI) -> Bool {
        switch predicateOperator {
        case .not:
            notIsIncluded(poi, predicates: subpredicates)
        case .and:
            andIsIncluded(poi, predicates: subpredicates)
        case .or:
            orIsIncluded(poi, predicates: subpredicates)
        }
    }

    private func notIsIncluded(_ poi: any POI, predicates: [any FilterPredicate]) -> Bool {
        guard let predicate = predicates.first else {
            return false
        }

        return predicate.isIncluded(poi) == false
    }

    private func andIsIncluded(_ poi: any POI, predicates: [any FilterPredicate]) -> Bool {
        for predicate in predicates {
            guard predicate.isIncluded(poi) else {
                return false
            }
        }

        return true
    }

    private func orIsIncluded(_ poi: any POI, predicates: [any FilterPredicate]) -> Bool {
        predicates.contains(where: { $0.isIncluded(poi) })
    }
}
