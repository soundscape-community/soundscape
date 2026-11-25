//
//  OfflineBannerViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

class OfflineBannerViewController: ConnectivityBannerViewController {
    
    // MARK: `OfflineBannerViewController` State
    
    enum State {
        case `default`
        case searchTableView
        case nearbyTableView
        case offlineHelpView
        
        var message: String {
            switch self {
            case .default: return "banner.offline_default.message"
            case .searchTableView, .nearbyTableView: return "banner.offline_search.message"
            case .offlineHelpView: return "banner.offline_help.message"
            }
        }

        var segue: ViewControllerRepresentable? {
            switch self {
            case .default: return AnyViewControllerRepresentable.offlineHelp
            case .searchTableView: return AnyViewControllerRepresentable.offlineHelp
            case .nearbyTableView: return AnyViewControllerRepresentable.offlineHelp
            case .offlineHelpView: return nil
            }
        }
        
        init(in viewController: UIViewController) {
            if viewController is SearchTableViewController || viewController is SearchResultsViewController {
                self = .searchTableView
            } else if (viewController as? NavigationBanner.Controller)?.isNearby == true {
                self = .nearbyTableView
            } else if viewController is OfflineHelpPageViewController {
                self = .offlineHelpView
            } else {
                self = .default
            }
        }
    }
    
    // MARK: Properties
    
    let segue: ViewControllerRepresentable?

    init(in viewController: UIViewController) {
        let state = State(in: viewController)
        let segue = state.segue
        self.segue = segue
        super.init(message: state.message, opensHelp: segue != nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(in:)")
    }
}
