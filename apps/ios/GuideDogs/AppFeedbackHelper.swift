//
//  AppFeedbackHelper.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation
import UIKit

class AppFeedbackHelper {

    // MARK: Properties

    static let minimumAppUsesBeforePrompt = 5

    // MARK: Methods

    /// Show a feedback prompt with rating and optional comment field.
    /// - Returns: If the prompt has been shown
    @discardableResult
    static func promptFeedbackIfNeeded(from viewController: UIViewController) -> Bool {
        let defaults = UserDefaults.standard
        let hasSeenFeedback = defaults.bool(forKey: "hasSeenFeedbackPopup")

        guard SettingsContext.shared.appUseCount >= minimumAppUsesBeforePrompt,
              !hasSeenFeedback else {
            return false
        }

        let alert = UIAlertController(
            title: "We’d love your feedback!",
            message: "How would you rate the 'Vicinity Distance' feature?",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Optional feedback"
        }

        for rating in 1...5 {
            alert.addAction(UIAlertAction(title: "\(rating)", style: .default) { _ in
                let feedbackText = alert.textFields?.first?.text ?? ""
                let subject = "Feedback on Vicinity Distance"
                let body = "Rating: \(rating)\nComment: \(feedbackText)"
                
                let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let email = "feedback@example.com" // TODO: Replace with actual email

                if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)"),
                   UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }

                defaults.set(true, forKey: "hasSeenFeedbackPopup")
            })
        }

        alert.addAction(UIAlertAction(title: "No thanks", style: .cancel) { _ in
            defaults.set(true, forKey: "hasSeenFeedbackPopup")
        })

        viewController.present(alert, animated: true)

        return true
    }
}
