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
        let appearance = UINavigationBarAppearance.soundscapeAppearance(for: style)

        tintColor = style.foregroundColor
        barTintColor = style.backgroundColor
        isTranslucent = style.isTranslucent
        overrideUserInterfaceStyle = .dark

        apply(appearance)
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
            $0.leftBarButtonItem?.configureSoundscapeNavigationButton(foregroundColor: tintColor)
            $0.rightBarButtonItem?.configureSoundscapeNavigationButton(foregroundColor: tintColor)
            $0.leftBarButtonItems?.forEach { $0.configureSoundscapeNavigationButton(foregroundColor: tintColor) }
            $0.rightBarButtonItems?.forEach { $0.configureSoundscapeNavigationButton(foregroundColor: tintColor) }
        }
    }
    
}

extension UINavigationBar.Style {

    var foregroundColor: UIColor {
        Colors.Foreground.primary ?? .white
    }

    var backgroundColor: UIColor {
        switch self {
        case .default: return Colors.Background.primary ?? UIColor.Theme.darkBlue
        case .transparentLightTitle: return .clear
        }
    }

    var isTranslucent: Bool {
        switch self {
        case .default: return false
        case .transparentLightTitle: return true
        }
    }

    var usesTransparentBackground: Bool {
        switch self {
        case .default: return false
        case .transparentLightTitle: return true
        }
    }

}

extension UINavigationBarAppearance {

    static func soundscapeAppearance(for style: UINavigationBar.Style) -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        let foregroundColor = style.foregroundColor

        if style.usesTransparentBackground {
            appearance.configureWithTransparentBackground()
        } else {
            appearance.configureWithOpaqueBackground()
        }

        appearance.backgroundColor = style.backgroundColor
        appearance.titleTextAttributes = [.foregroundColor: foregroundColor]

        let buttonAppearance = UIBarButtonItemAppearance.soundscapeNavigationAppearance(foregroundColor: foregroundColor)
        appearance.buttonAppearance = buttonAppearance
        appearance.backButtonAppearance = buttonAppearance
        appearance.doneButtonAppearance = buttonAppearance
        appearance.configureSoundscapeBackIndicator(foregroundColor: foregroundColor)

        return appearance
    }

    func configureSoundscapeBackIndicator(foregroundColor: UIColor) {
        guard #available(iOS 26.0, *),
              let image = UIImage(systemName: "chevron.left")?.withTintColor(foregroundColor, renderingMode: .alwaysOriginal) else {
            return
        }

        setBackIndicatorImage(image, transitionMaskImage: image)
    }

}

extension UIBarButtonItemAppearance {

    static func soundscapeNavigationAppearance(foregroundColor: UIColor) -> UIBarButtonItemAppearance {
        let appearance = UIBarButtonItemAppearance()
        let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: foregroundColor]

        appearance.normal.titleTextAttributes = attributes
        appearance.highlighted.titleTextAttributes = attributes
        appearance.focused.titleTextAttributes = attributes
        appearance.disabled.titleTextAttributes = [.foregroundColor: foregroundColor.withAlphaComponent(0.35)]

        return appearance
    }

}
