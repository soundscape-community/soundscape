//
//  UIAlertController+Extensions.swift
//  Openscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

enum MailClient: String, CaseIterable {
    
    // TODO: Add Mail Clients that you would like to support
    // These applications must also be defined in 'Queried URL Schemes' in Info.plist
    // https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html#//apple_ref/doc/plist/info/LSApplicationQueriesSchemes
    case systemMail
    case gmail
    case outlook
    case protonMail
    // https://github.com/ProtonMail/ios-mail/issues/27
    case airmail
    case dispatch
    case fastmail
    case spark
    case yahooMail

    var localizedTitle: String {
        // TODO: Return a localized title string for each mail client
        
        switch self {
        case .systemMail: return "System default mail client"
        case .gmail: return "Gmail"
        case .outlook: return "Microsoft Outlook"
        case .fastmail: return "Fastmail"
        case .protonMail: return "Proton Mail"
        case .spark: return "Spark"
        case .airmail: return "Airmail"
        case .yahooMail: return "Yahoo Mail"
        case .dispatch: return "Dispatch"
        }
    }
    
    func url(email: String, subject: String) -> URL? {
        let deviceInfo = "iOS \(UIDevice.current.systemVersion), \(UIDevice.current.modelName), \(LocalizationContext.currentAppLocale.identifierHyphened), v\(AppContext.appVersion).\(AppContext.appBuild)"
        let escapedSubject = "\(subject) (\(deviceInfo))".addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed) ?? GDLocalizedString("settings.feedback.subject")
        // TODO: Return appropriate URL for each mail client
        print("Email: \(email)")
        print("escaped Subject: \(escapedSubject)")
        switch self {
            case .systemMail: return URL(string: "mailto:\(email)?subject=\(escapedSubject)")
            case .gmail: return URL(string: "googlegmail:///co?to=\(email)&subject=\(escapedSubject)")
            case .outlook: return URL(string: "ms-outlook://compose?to=\(email)&subject=\(escapedSubject)")
            case .protonMail: return URL(string: "protonmail://mailto:foobar@\(email)?subject=\(escapedSubject)")
            case .spark: return URL(string: "readdle-spark://compose?recipient=\(email)&subject=\(subject)")
            case .airmail: return URL(string: "airmail://compose?to=\(email)&subject=\(subject)")
            case .dispatch: return URL(string: "x-dispatch:///compose?to=\(email)&subject=\(subject)")
            case .fastmail: return URL(string: "fastmail://mail/compose?to=\(email)&subject=\(subject)")
            case .yahooMail: return  URL(string: "ymail://mail/compose?to=\(email)&subject=\(subject)")
        }
    }
}

extension UIAlertController {
    /// Create and return a `UIAlertController` that is able to send an email with external email clients
    convenience init(email: String, subject: String, preferredStyle: UIAlertController.Style, handler: ((MailClient?) -> Void)? = nil) {

        // Create alert actions from mail clients
        let actions = MailClient.allCases.compactMap { (client) -> UIAlertAction? in
            print("Processing client: \(client)")
            guard let url = client.url(email: email, subject: subject) else {
                print("Unable to construct URL for feedback email compose")
                return nil 
            }
            print("Got URL: \(url)")
            return UIAlertAction(title: client.localizedTitle, url: url) {
                handler?(client)
            }
        }
        
        if actions.isEmpty {
            self.init(title: GDLocalizedString("general.error.error_occurred"),
                      message: GDLocalizedString("settings.feedback.no_mail_client_error"),
                      preferredStyle: .alert)
        } else {
            self.init(title: GDLocalizedString("settings.feedback.choose_email_app"),
                      message: nil,
                      preferredStyle: preferredStyle)
            
            actions.forEach({ action in
                self.addAction(action)
            })
        }
        
        self.addAction(UIAlertAction(title: GDLocalizedString("general.alert.cancel"), style: .cancel, handler: nil))
    }
}
