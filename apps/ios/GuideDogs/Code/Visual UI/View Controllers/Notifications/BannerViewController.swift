//
//  BannerViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

class BannerViewController: ConfigurableViewController {
    
    // MARK: Properties
    
    weak var delegate: BannerViewControllerDelegate?
    
    @IBOutlet weak var contentView: UIView!
    
    // MARK: Initialization
    
    convenience init(nibName: String, configurationHandler: ((UIViewController) -> Void)? = nil) {
        let bundle = Bundle(for: BannerViewController.self)
        self.init(nibName: nibName, bundle: bundle)
        configurator = configurationHandler
    }
    
    // MARK: Actions
    
    @IBAction func onTouchUpInside() {
        
        delegate?.didSelect(self)
    }
    
}
