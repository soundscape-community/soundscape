//
//  NavigationController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

class NavigationController: UINavigationController {
    
    // MARK: Properties
    
    private var notificationController = NotificationController.shared
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.delegate = notificationController
        
        // Default navigation bar
        navigationBar.configureAppearance(for: .default)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let first = viewControllers.first, first.isViewLoaded else {
            return
        }
        
        // If the navigation controller is appearing, but the top view controller has
        // already been loaded, then manually notify the notification controller
        notificationController.navigationController(self, willShow: first, animated: true)
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        configureNavigationButton(for: viewController, shouldShowBackButton: viewControllers.isEmpty == false)

        super.pushViewController(viewController, animated: animated)

        DispatchQueue.main.async { [weak self, weak viewController] in
            guard let self, let viewController else {
                return
            }

            self.configureNavigationButton(for: viewController, shouldShowBackButton: self.viewControllers.first !== viewController)
        }
    }

    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        for (index, viewController) in viewControllers.enumerated() {
            configureNavigationButton(for: viewController, shouldShowBackButton: index > 0)
        }

        super.setViewControllers(viewControllers, animated: animated)
    }

    private func configureNavigationButton(for viewController: UIViewController, shouldShowBackButton: Bool) {
        guard #available(iOS 26.0, *) else {
            return
        }

        if shouldShowBackButton {
            viewController.navigationItem.hidesBackButton = true
            viewController.navigationItem.leftItemsSupplementBackButton = false
        }

        if viewController.navigationItem.leftBarButtonItem == nil,
           shouldShowBackButton,
           let backButton = UIBarButtonItem.soundscapeBackButton(target: self, action: #selector(popCurrentViewController)) {
            viewController.navigationItem.leftBarButtonItem = backButton
        } else {
            viewController.navigationItem.leftBarButtonItem?.configureSoundscapeNavigationButton()
        }
    }

    @objc private func popCurrentViewController() {
        popViewController(animated: true)
    }
    
}

extension NavigationController {
    
    func performSegue(_ destination: ViewControllerRepresentable) {
        guard let viewController = destination.makeViewController() else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else {
                return
            }
            
            self.pushViewController(viewController, animated: true)
        }
    }
    
}
