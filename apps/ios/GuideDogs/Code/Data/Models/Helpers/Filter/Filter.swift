//
//  Filter.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import CoreLocation

struct Filter {
    static func superCategory(expected: SuperCategory) -> FilterPredicate {
        return SuperCategoryPredicate(expected: expected)
    }

    static func superCategories(orExpected expected: [SuperCategory]) -> CompoundPredicate {
        let subpredicates = expected.map({ return SuperCategoryPredicate(expected: $0) })
        return CompoundPredicate(orPredicateWithSubpredicates: subpredicates)
    }

    static func type(expected: PrimaryType) -> FilterPredicate {
        return TypePredicate(expected: expected)
    }

    static func type(expected: SecondaryType) -> FilterPredicate {
        return TypePredicate(expected: expected)
    }

    static func types(orExpected expected: [PrimaryType]) -> CompoundPredicate {
        let subpredicates = expected.map({ return TypePredicate(expected: $0) })
        return CompoundPredicate(orPredicateWithSubpredicates: subpredicates)
    }

    static func types(orExpected expected: [SecondaryType]) -> CompoundPredicate {
        let subpredicates = expected.map({ return TypePredicate(expected: $0) })
        return CompoundPredicate(orPredicateWithSubpredicates: subpredicates)
    }

    static func location(expected: CLLocation) -> FilterPredicate {
        return LocationPredicate(expected: expected)
    }
}
