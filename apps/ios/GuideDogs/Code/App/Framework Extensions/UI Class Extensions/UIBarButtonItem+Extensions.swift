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
        UIBarButtonItem(title: GDLocalizedString("ui.back_button.title"), style: .plain, target: nil, action: nil)
    }

    func configureSoundscapeNavigationButton() {
        if #available(iOS 26.0, *) {
            hidesSharedBackground = true
            sharesBackground = false
        }
    }
    
}
