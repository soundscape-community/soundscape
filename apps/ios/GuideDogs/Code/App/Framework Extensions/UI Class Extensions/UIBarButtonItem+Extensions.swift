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

    func configureSoundscapeNavigationButton(foregroundColor: UIColor? = nil) {
        if let foregroundColor {
            tintColor = foregroundColor
            image = image?.withRenderingMode(.alwaysTemplate)
        }

        if #available(iOS 26.0, *) {
            hidesSharedBackground = true
            sharesBackground = false
        }
    }
    
}
