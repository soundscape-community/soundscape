// Copyright (c) Soundscape Community Contributers.

import Foundation
import SSGeo

public struct Filter {
    public static func superCategory(expected: SuperCategory) -> any FilterPredicate {
        SuperCategoryPredicate(expected: expected)
    }

    public static func superCategories(orExpected expected: [SuperCategory]) -> CompoundPredicate {
        let subpredicates = expected.map { SuperCategoryPredicate(expected: $0) }
        return CompoundPredicate(orPredicateWithSubpredicates: subpredicates)
    }

    public static func type(expected: PrimaryType) -> any FilterPredicate {
        TypePredicate(expected: expected)
    }

    public static func type(expected: SecondaryType) -> any FilterPredicate {
        TypePredicate(expected: expected)
    }

    public static func types(orExpected expected: [PrimaryType]) -> CompoundPredicate {
        let subpredicates = expected.map { TypePredicate(expected: $0) }
        return CompoundPredicate(orPredicateWithSubpredicates: subpredicates)
    }

    public static func types(orExpected expected: [SecondaryType]) -> CompoundPredicate {
        let subpredicates = expected.map { TypePredicate(expected: $0) }
        return CompoundPredicate(orPredicateWithSubpredicates: subpredicates)
    }

    public static func location(expected: SSGeoLocation) -> any FilterPredicate {
        LocationPredicate(expected: expected)
    }
}
