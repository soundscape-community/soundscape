//
//  ThirdPartyNoticesViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit
import WebKit
import SafariServices
import CocoaLumberjackSwift

class ThirdPartyNoticesViewController: UIViewController {

    // MARK: Properties

    private let webview = WKWebView()
    let largeBannerContainerView: UIView! = UIView()
    private lazy var largeBannerContainerHeightConstraint = largeBannerContainerView.heightAnchor.constraint(equalToConstant: 0)

    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor(named: "Background Base")
        view.tintColor = UIColor(named: "Foreground 1")

        let stack = UIStackView(arrangedSubviews: [largeBannerContainerView, webview])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            largeBannerContainerHeightConstraint,
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = GDLocalizedString("settings.about.title.copyright")
        webview.navigationDelegate = self
        webview.scrollView.indicatorStyle = .white
        
        loadLicenses()
    }

    // MARK: Actions
    
    private func loadLicenses() {
        if let licensesPath = Bundle.main.path(forResource: "licenses", ofType: "html") {
            let url = URL(fileURLWithPath: licensesPath)
            webview.loadFileURL(url, allowingReadAccessTo: url)
        } else {
            DDLogWarn("no licenses HTML file found")
        }
    }
}

extension ThirdPartyNoticesViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        
        // If we are loading the initial licenses HTML file
        guard !url.absoluteString.contains("licenses.html") else {
            decisionHandler(.allow)
            return
        }
        
        let safariVC = SFSafariViewController(url: url)
        safariVC.preferredBarTintColor = Colors.Background.primary
        safariVC.preferredControlTintColor = Colors.Foreground.primary
        
        present(safariVC, animated: true, completion: nil)
        
        decisionHandler(.cancel)
    }
}

extension ThirdPartyNoticesViewController: LargeBannerContainerView {
    
    func setLargeBannerHeight(_ height: CGFloat) {
        largeBannerContainerHeightConstraint.constant = height
    }
    
}
