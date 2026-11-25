// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import SwiftUI
import UIKit

// The hosting controller remains responsible for containment of any UIKit children.
struct EmbeddedView: UIViewRepresentable {
    let content: UIView

    func makeUIView(context: Context) -> UIView { content }

    func updateUIView(_ view: UIView, context: Context) {}
}
