//
//  UIBarButtonItem+Extensions.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit

extension UIBarButtonItem {
    
    static var defaultBackBarButtonItem: UIBarButtonItem {
        let item = UIBarButtonItem(title: GDLocalizedString("ui.back_button.title"), style: .plain, target: nil, action: nil)

        item.configureSoundscapeNavigationButton()

        return item
    }

    static func soundscapeBackButton(target: AnyObject?, action: Selector) -> UIBarButtonItem? {
        guard #available(iOS 26.0, *) else {
            return nil
        }

        let title = GDLocalizedString("ui.back_button.title")
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "chevron.left")
        configuration.imagePadding = 4.0
        configuration.title = title
        configuration.baseForegroundColor = Colors.Foreground.primary ?? .white
        button.configuration = configuration
        button.addTarget(target, action: action, for: .touchUpInside)
        button.sizeToFit()

        let item = UIBarButtonItem(customView: button)

        item.accessibilityIdentifier = "BackButton"
        item.accessibilityLabel = title
        item.configureSoundscapeNavigationButton()

        return item
    }

    func configureSoundscapeNavigationButton() {
        if #available(iOS 26.0, *) {
            hidesSharedBackground = true
            sharesBackground = false
        }
    }
    
}
