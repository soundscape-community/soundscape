//
//  UINavigationBar+Extentions.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit

extension UINavigationBar {
    
    enum Style {
        // Navigation bar appearance used by most of the app's views
        case `default`
        // Transparent background with light (white) foreground
        case transparentLightTitle
    }
    
    func configureAppearance(for style: Style) {
        switch style {
        case .default: configureDefaultAppearance()
        case .transparentLightTitle: configureTransparentAppearance()
        }
    }
    
    private func configureDefaultAppearance() {
        let color = Colors.Foreground.primary ?? UIColor.white
        let buttonAppearance = makeButtonAppearance(foregroundColor: color)
        
        let appearance = UINavigationBarAppearance()
        
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Colors.Background.primary
        appearance.titleTextAttributes = [.foregroundColor: color]
        appearance.buttonAppearance = buttonAppearance
        appearance.backButtonAppearance = buttonAppearance
        appearance.doneButtonAppearance = buttonAppearance
        appearance.configureBackIndicator(foregroundColor: color)
        
        apply(appearance)
        
        tintColor = color
        barTintColor = Colors.Background.primary
        isTranslucent = false
    }
    
    private func configureTransparentAppearance() {
        let color = Colors.Foreground.primary ?? UIColor.white
        let buttonAppearance = makeButtonAppearance(foregroundColor: color)
        
        let appearance = UINavigationBarAppearance()
        
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: color]
        appearance.buttonAppearance = buttonAppearance
        appearance.backButtonAppearance = buttonAppearance
        appearance.doneButtonAppearance = buttonAppearance
        appearance.configureBackIndicator(foregroundColor: color)
        
        apply(appearance)
        
        tintColor = color
        barTintColor = .clear
        isTranslucent = true
    }

    private func makeButtonAppearance(foregroundColor: UIColor) -> UIBarButtonItemAppearance {
        let appearance = UIBarButtonItemAppearance()
        let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: foregroundColor]

        appearance.normal.titleTextAttributes = attributes
        appearance.highlighted.titleTextAttributes = attributes
        appearance.focused.titleTextAttributes = attributes
        appearance.disabled.titleTextAttributes = [.foregroundColor: foregroundColor.withAlphaComponent(0.35)]

        return appearance
    }

    private func apply(_ appearance: UINavigationBarAppearance) {
        // Apply the given appearance
        standardAppearance = appearance
        scrollEdgeAppearance = appearance
        compactAppearance = appearance
        compactScrollEdgeAppearance = appearance
        
        // Set the back button
        items?.forEach {
            $0.backBarButtonItem = UIBarButtonItem.defaultBackBarButtonItem
            $0.leftBarButtonItem?.configureSoundscapeNavigationButton()
            $0.rightBarButtonItem?.configureSoundscapeNavigationButton()
            $0.leftBarButtonItems?.forEach { $0.configureSoundscapeNavigationButton() }
            $0.rightBarButtonItems?.forEach { $0.configureSoundscapeNavigationButton() }
        }
    }
    
}

private extension UINavigationBarAppearance {

    func configureBackIndicator(foregroundColor: UIColor) {
        guard #available(iOS 26.0, *),
              let image = UIImage(systemName: "chevron.left")?.withTintColor(foregroundColor, renderingMode: .alwaysOriginal) else {
            return
        }

        setBackIndicatorImage(image, transitionMaskImage: image)
    }

}
