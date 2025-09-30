//
//  HomeViewController+AccessibleLayout.swift
//  Soundscape - Add this as an extension file
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import UIKit

extension HomeViewController {
    
    /// Call this method in viewDidLoad to setup accessible layout
    func setupAccessibleLayout() {
        // Override storyboard constraints with accessible layout
        
        // Hide original containers temporarily and reconfigure
        view.setNeedsLayout()
        
        // Make callout panel container larger
        calloutPanelContainerHeightConstraint.constant = 400 // Increased from default
        
        // Adjust card container to use remaining space efficiently
        cardContainerTopConstraints.forEach { constraint in
            constraint.constant = 20 // Increase spacing
        }
        
        // Make search bar more accessible
        if let searchBar = navigationItem.searchController?.searchBar {
            searchBar.searchTextField.font = UIFont.preferredFont(forTextStyle: .body)
            searchBar.searchTextField.adjustsFontForContentSizeCategory = true
        }
        
        // Add accessibility adjustments to sleep button
        configureSleepButton()
        
        // Apply to view
        view.layoutIfNeeded()
    }
    
    private func configureSleepButton() {
        // Make sleep button larger and more accessible
        sleepButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .title3)
        sleepButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        // Ensure proper accessibility traits
        sleepButton.accessibilityLabel = GDLocalizedString("sleep_mode.title")
        sleepButton.accessibilityHint = "Double tap to enter sleep mode and pause location updates"
        sleepButton.accessibilityTraits = .button
        
        // Make sleep icon more visible
        sleepIcon.tintColor = .label
        
        // Increase minimum touch target
        let minTouchSize: CGFloat = 60
        sleepButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sleepButton.heightAnchor.constraint(greaterThanOrEqualToConstant: minTouchSize),
            sleepButton.widthAnchor.constraint(greaterThanOrEqualToConstant: minTouchSize)
        ])
    }
    
    /// Override viewDidLayoutSubviews to ensure accessible spacing
    func applyAccessibleSpacing() {
        // Ensure minimum spacing between interactive elements
        let minSpacing: CGFloat = 16
        
        // Adjust banner heights for better visibility
        if largeBannerContainerView.subviews.count > 0 {
            largeBannerContainerHeightConstraint.constant = max(largeBannerContainerHeightConstraint.constant, 80)
        }
        
        if smallBannerContainerView.subviews.count > 0 {
            smallBannerContainerHeightConstraint.constant = max(smallBannerContainerHeightConstraint.constant, 60)
        }
    }
}

// MARK: - Add to existing HomeViewController.viewDidLoad()
/*
 Add these lines to your existing viewDidLoad() method after super.viewDidLoad():
 
 // Setup accessible layout
 setupAccessibleLayout()
 
 // Register for accessibility notifications
 NotificationCenter.default.addObserver(
     self,
     selector: #selector(voiceOverStatusChanged),
     name: UIAccessibility.voiceOverStatusDidChangeNotification,
     object: nil
 )
 
 // Apply VoiceOver-specific adjustments if enabled
 if UIAccessibility.isVoiceOverRunning {
     applyVoiceOverOptimizations()
 }
*/

// MARK: - VoiceOver Optimizations
extension HomeViewController {
    
    @objc func voiceOverStatusChanged() {
        if UIAccessibility.isVoiceOverRunning {
            applyVoiceOverOptimizations()
        } else {
            removeVoiceOverOptimizations()
        }
    }
    
    func applyVoiceOverOptimizations() {
        // Increase spacing when VoiceOver is active
        cardContainerTopConstraints.forEach { $0.constant = 24 }
        calloutPanelContainerHeightConstraint.constant = 420
        
        // Group related elements for better navigation
        navigationItem.searchController?.searchBar.accessibilityElementsHidden = false
        
        // Set accessibility order
        view.accessibilityElements = [
            navigationItem.searchController?.searchBar as Any,
            largeBannerContainerView as Any,
            smallBannerContainerView as Any,
            view.viewWithTag(1000) as Any, // Callout button panel (set tag in storyboard)
            view.viewWithTag(2000) as Any, // Card container (set tag in storyboard)
            sleepButton as Any
        ].compactMap { $0 }
        
        view.layoutIfNeeded()
    }
    
    func removeVoiceOverOptimizations() {
        // Reset to normal spacing
        cardContainerTopConstraints.forEach { $0.constant = 16 }
        calloutPanelContainerHeightConstraint.constant = 400
        
        view.accessibilityElements = nil
        view.layoutIfNeeded()
    }
}

// MARK: - Accessibility Container Management
extension HomeViewController {
    
    /// Configure all container views for better accessibility
    func configureAccessibleContainers() {
        // Callout button container
        if let calloutContainer = view.viewWithTag(1000) {
            calloutContainer.accessibilityLabel = "Action buttons"
            calloutContainer.accessibilityHint = "Contains location and navigation callout buttons"
            calloutContainer.shouldGroupAccessibilityChildren = true
        }
        
        // Card container
        if let cardContainer = view.viewWithTag(2000) {
            cardContainer.accessibilityLabel = "Current activity"
            cardContainer.accessibilityHint = "Shows active beacon or route information"
            cardContainer.shouldGroupAccessibilityChildren = true
        }
        
        // Banner containers
        largeBannerContainerView.shouldGroupAccessibilityChildren = true
        smallBannerContainerView.shouldGroupAccessibilityChildren = true
        
        // Search container
        searchContainerHeightConstraint.constant = max(searchContainerHeightConstraint.constant, 60)
    }
}
