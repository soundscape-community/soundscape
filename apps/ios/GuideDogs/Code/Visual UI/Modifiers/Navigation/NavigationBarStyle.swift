//
//  NavigationBarStyle.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI
import UIKit

enum NavigationBarStyle {
    case transparent(foregroundColor: Color)
    case darkBlue
}

extension NavigationBarStyle {
    
    var foregroundColor: Color {
        switch self {
        case .transparent(let foregroundColor): return foregroundColor
        case .darkBlue: return .white
        }
    }
    
    var foregroundUIColor: UIColor {
        switch self {
        case .transparent(let foregroundColor):
            guard let cgForegroundColor = foregroundColor.cgColor else {
                return .white
            }
            
            return UIColor(cgColor: cgForegroundColor)
        case .darkBlue: return .white
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .transparent: return .clear
        case .darkBlue: return Color.Theme.darkBlue
        }
    }
    
    var backgroundUIColor: UIColor {
        switch self {
        case .transparent: return .clear
        case .darkBlue: return UIColor.Theme.darkBlue
        }
    }
    
    var toolbarBackgroundVisibility: Visibility {
        switch self {
        case .transparent: return .hidden
        case .darkBlue: return .visible
        }
    }
    
    var toolbarColorScheme: ColorScheme? {
        switch self {
        case .transparent: return nil
        case .darkBlue: return .dark
        }
    }
    
    var isTranslucent: Bool {
        switch self {
        case .transparent: return true
        case .darkBlue: return false
        }
    }
}

private struct NavigationBarStyleModifier: ViewModifier {
    
    let style: NavigationBarStyle
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(style.backgroundColor, for: .navigationBar)
                .toolbarBackground(style.toolbarBackgroundVisibility, for: .navigationBar)
                .toolbarColorScheme(style.toolbarColorScheme, for: .navigationBar)
                .tint(style.foregroundColor)
        } else {
            content
                .navigationBarTitleDisplayMode(.inline)
                .background(NavigationBarStyleConfigurator(style: style))
        }
    }
    
}

private struct NavigationBarStyleConfigurator: UIViewControllerRepresentable {
    
    let style: NavigationBarStyle
    
    func makeUIViewController(context: Context) -> NavigationBarStyleConfiguratorViewController {
        return NavigationBarStyleConfiguratorViewController(style: style)
    }
    
    func updateUIViewController(_ viewController: NavigationBarStyleConfiguratorViewController, context: Context) {
        viewController.style = style
    }
    
}

private class NavigationBarStyleConfiguratorViewController: UIViewController {
    
    var style: NavigationBarStyle {
        didSet {
            configureNavigationBar()
        }
    }
    
    init(style: NavigationBarStyle) {
        self.style = style
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        configureNavigationBar()
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        
        configureNavigationBar()
    }
    
    private func configureNavigationBar() {
        guard let navigationBar = navigationController?.navigationBar else {
            DispatchQueue.main.async { [weak self] in
                self?.configureNavigationBarIfAvailable()
            }
            
            return
        }
        
        navigationBar.configureAppearance(for: style)
    }
    
    private func configureNavigationBarIfAvailable() {
        navigationController?.navigationBar.configureAppearance(for: style)
    }
    
}

private extension UINavigationBar {
    
    func configureAppearance(for style: NavigationBarStyle) {
        let appearance = UINavigationBarAppearance(for: style)
        
        standardAppearance = appearance
        scrollEdgeAppearance = appearance
        compactAppearance = appearance
        compactScrollEdgeAppearance = appearance
        
        tintColor = style.foregroundUIColor
        barTintColor = style.backgroundUIColor
        isTranslucent = style.isTranslucent
    }
    
}

private extension UINavigationBarAppearance {
    
    convenience init(for style: NavigationBarStyle) {
        self.init()
        
        switch style {
        case .transparent: configureWithTransparentBackground()
        case .darkBlue: configureWithOpaqueBackground()
        }
        
        backgroundColor = style.backgroundUIColor
        titleTextAttributes = [.foregroundColor: style.foregroundUIColor]
        
        let buttonAppearance = UIBarButtonItemAppearance(foregroundColor: style.foregroundUIColor)
        self.buttonAppearance = buttonAppearance
        backButtonAppearance = buttonAppearance
        doneButtonAppearance = buttonAppearance
        configureBackIndicator(foregroundColor: style.foregroundUIColor)
    }

    func configureBackIndicator(foregroundColor: UIColor) {
        guard #available(iOS 26.0, *),
              let image = UIImage(systemName: "chevron.left")?.withTintColor(foregroundColor, renderingMode: .alwaysOriginal) else {
            return
        }

        setBackIndicatorImage(image, transitionMaskImage: image)
    }
    
}

private extension UIBarButtonItemAppearance {
    
    convenience init(foregroundColor: UIColor) {
        self.init()
        
        let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: foregroundColor]
        normal.titleTextAttributes = attributes
        highlighted.titleTextAttributes = attributes
        focused.titleTextAttributes = attributes
        disabled.titleTextAttributes = [.foregroundColor: foregroundColor.withAlphaComponent(0.35)]
    }
    
}

extension View {
    
    func navigationBarStyle(style: NavigationBarStyle) -> some View {
        modifier(NavigationBarStyleModifier(style: style))
    }
    
}
