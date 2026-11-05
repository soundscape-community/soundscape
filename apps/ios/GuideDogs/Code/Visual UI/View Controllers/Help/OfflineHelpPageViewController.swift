//
//  OfflineHelpPageViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

class OfflineHelpPageViewController: UIViewController {
    
    @IBOutlet weak var largeBannerContainerView: UIView!
    @IBOutlet var largeBannerContainerHeightConstraint: NSLayoutConstraint!

}

extension OfflineHelpPageViewController: LargeBannerContainerView {
    
    func setLargeBannerHeight(_ height: CGFloat) {
        largeBannerContainerHeightConstraint.constant = height
    }
    
}
