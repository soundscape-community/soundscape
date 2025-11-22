//
//  NotificationContainerManager.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

class NotificationContainerManager<T: NotificationProtocol> {
    
    private var currentViewController: UIViewController?
    private let server: NotificationServer<T>
    private var container: NotificationContainer
    
    @MainActor
    init(_ notifications: [T]) {
        self.server = NotificationServer(notifications)
        self.container = T.container
        
        // Initialize `NotificationServerDelegate`
        server.delegate = self
    }
    
    @MainActor
    func viewControllerWillChange(_ viewController: UIViewController) {
        self.currentViewController = viewController
        
        updateContainer(in: viewController)
    }
    
    @MainActor
    private func updateContainer(in viewController: UIViewController) {
        self.container.dismiss(animated: true) { [weak self] in
            guard let notificationViewController = self?.server.requestNotification(in: viewController) else {
                return
            }
            
            self?.container.present(notificationViewController, presentingViewController: viewController)
        }
    }
    
}

extension NotificationContainerManager: NotificationServerDelegate {
    
    @MainActor
    func stateDidChange<T>(_ server: NotificationServer<T>) where T: NotificationProtocol {
        guard let viewController = currentViewController else {
            return
        }
        
        updateContainer(in: viewController)
    }
    
    func performSegue<T>(_ server: NotificationServer<T>, destination: ViewControllerRepresentable) where T: NotificationProtocol {
        guard let navigationController: NavigationController = currentViewController?.navigationController as? NavigationController else {
            return
        }
        
        navigationController.performSegue(destination)
    }
    
    func popToRootViewController<T>(_ server: NotificationServer<T>) where T: NotificationProtocol {
        currentViewController?.navigationController?.popToRootViewController(animated: true)
    }
    
}
