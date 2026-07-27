//
//  SettingsListBackground.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

extension View {
    @ViewBuilder
    func settingsListBackground() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            background(SettingsListBackgroundConfigurator())
        }
    }
}

private struct SettingsListBackgroundConfigurator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        clearTableBackground(from: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        clearTableBackground(from: uiView)
    }

    private func clearTableBackground(from view: UIView) {
        DispatchQueue.main.async {
            view.enclosingTableView()?.backgroundColor = .clear
        }
    }
}

private extension UIView {
    func enclosingTableView() -> UITableView? {
        var currentView: UIView? = self

        while let view = currentView {
            if let tableView = view as? UITableView {
                return tableView
            }

            if let tableView = view.firstSubview(of: UITableView.self) {
                return tableView
            }

            currentView = view.superview
        }

        return nil
    }

    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        for subview in subviews {
            if let matchingSubview = subview as? T {
                return matchingSubview
            }

            if let matchingSubview = subview.firstSubview(of: type) {
                return matchingSubview
            }
        }

        return nil
    }
}
