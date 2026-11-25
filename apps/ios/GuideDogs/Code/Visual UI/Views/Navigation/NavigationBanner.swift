// Copyright (c) Soundscape Community Contributors.
// Licensed under the MIT License.

import SwiftUI
import UIKit

struct NavigationBanner: View {
    var isNearby = false
    @StateObject private var size = Size()

    var body: some View {
        BannerHost(size: size, isNearby: isNearby)
            .frame(height: size.height)
            .clipped()
            .accessibilityHidden(size.height == 0)
    }

    fileprivate final class Size: ObservableObject {
        @Published var height: CGFloat = 0
    }

    private struct BannerHost: UIViewControllerRepresentable {
        let size: Size
        let isNearby: Bool

        func makeUIViewController(context: Context) -> Controller {
            Controller(size: size, isNearby: isNearby)
        }

        func updateUIViewController(_ controller: Controller, context: Context) {}
    }

    final class Controller: UIViewController, LargeBannerContainerView {
        private let size: Size
        let isNearby: Bool
        var largeBannerContainerView: UIView! { view }

        fileprivate init(size: Size, isNearby: Bool) {
            self.size = size
            self.isNearby = isNearby
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            NotificationController.shared.screenWillShow(self)
        }

        func setLargeBannerHeight(_ height: CGFloat) {
            DispatchQueue.main.async { [weak size] in
                size?.height = height
            }
        }
    }
}
