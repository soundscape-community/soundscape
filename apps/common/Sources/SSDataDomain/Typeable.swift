// Copyright (c) Soundscape Community Contributers.

import Foundation

public protocol Typeable {
    func isOfType(_ type: PrimaryType) -> Bool
    func isOfType(_ type: SecondaryType) -> Bool
}
