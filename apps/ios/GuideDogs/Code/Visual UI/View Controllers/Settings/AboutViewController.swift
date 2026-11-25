//
//  AboutViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SafariServices
import SwiftUI

struct AboutScreen: View {
    let navigation: AppNavigationModel
    @State private var webPage: WebPage?

    var body: some View {
        VStack(spacing: 0) {
            NavigationBanner()
            List {
                VStack(spacing: 4) {
                    Image("launchScreenLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .padding(.bottom, 10)
                        .accessibilityHidden(true)
                    Text(verbatim: "Soundscape").font(.headline)
                    GDLocalizedTextView("settings.version.about.version", AppContext.appVersion, AppContext.appBuild)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
                .accessibilityElement(children: .combine)

                row(GDLocalizedString("settings.about.title.whats_new")) { navigation.open(.settingsPage(.versionHistory)) }
                link("settings.about.title.privacy_policy", AppContext.Links.privacyPolicyURL(for: LocalizationContext.currentAppLocale))
                link("settings.about.title.service_agreement", AppContext.Links.servicesAgreementURL(for: LocalizationContext.currentAppLocale))
                row(GDLocalizedString("settings.about.title.copyright")) { navigation.open(.settingsPage(.notices)) }
                link("settings.about.title.youtube_channel", AppContext.Links.youtubeURL(for: LocalizationContext.currentAppLocale))
                if LocalizationContext.currentAppLocale == .frFr {
                    row("Accessibilité: partiellement conforme") {
                        webPage = WebPage(url: AppContext.Links.accessibilityFrance)
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(GDLocalizedString("settings.section.about"))
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $webPage) { page in
            SafariPage(url: page.url).ignoresSafeArea()
        }
    }

    private func link(_ title: String, _ url: URL) -> some View {
        row(GDLocalizedString(title)) { webPage = WebPage(url: url) }
    }

    private func row(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(verbatim: title)
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
    }

    private struct WebPage: Identifiable {
        let url: URL
        var id: URL { url }
    }

    private struct SafariPage: UIViewControllerRepresentable {
        let url: URL

        func makeUIViewController(context: Context) -> SFSafariViewController {
            let controller = SFSafariViewController(url: url)
            controller.preferredBarTintColor = Colors.Background.primary
            controller.preferredControlTintColor = Colors.Foreground.primary
            return controller
        }

        func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
    }
}
