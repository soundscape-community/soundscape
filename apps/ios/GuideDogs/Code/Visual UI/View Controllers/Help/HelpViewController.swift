//
//  HelpViewController.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import UIKit
import SwiftUI

class HelpPage {
    /// This should contain a localized String
    let id: String
    let title: String
    let index: IndexPath
    
    init(id: String, title: String, index: IndexPath) {
        self.id = id
        self.title = title
        self.index = index
    }
}

class TextHelpPage: HelpPage {
    let text: [String]
    
    init(id: String, title: String, text: [String], index: IndexPath) {
        self.text = text
        super.init(id: id, title: title, index: index)
    }
}

struct SectionedHelpPageDeepLink {
    let url: URL
    let title: String
}

/// What/When/How help page
class SectionedHelpPage: HelpPage {
    /// This should contain a localized String
    let what: [String]
    /// This should contain a localized String
    let when: [String]
    /// This should contain a localized String
    let how: [String]
    
    /// This is a URL for a deeplink to another app or additional documentation on the internet
    let link: SectionedHelpPageDeepLink?
    
    init(id: String, title: String, what: [String], when: [String], how: [String], link: SectionedHelpPageDeepLink? = nil, index: IndexPath) {
        self.what = what
        self.when = when
        self.how = how
        self.link = link
        super.init(id: id, title: title, index: index)
    }
}

struct FAQ: Identifiable {
    let id: String
    /// This should contain a localized String
    let question: String
    
    /// This should contain a localized String
    let answer: String
    
    init(_ key: String) {
        id = key
        self.question = GDLocalizedString(key + ".question")
        self.answer = GDLocalizedString(key + ".answer")
    }
}

struct FAQSection {
    /// This should contain a localized String
    let heading: String
    
    /// A list of localized FAQs
    let faqs: [FAQ]
}

class FAQListHelpPage: HelpPage {
    /// A list of localized FAQs
    let sections: [FAQSection]
    
    init(id: String, title: String, sections: [FAQSection], index: IndexPath) {
        self.sections = sections
        super.init(id: id, title: title, index: index)
    }
}

// MARK: -

struct HelpView: View {
    @ObservedObject var navigation: AppNavigationModel
    var route: HelpRoute? = nil
    
    // MARK: Properties
    
    private var helpPages = [
        
        // Configuration
        TextHelpPage(id: "voice.voices", title: GDLocalizedString("voice.voices"),
                     text: [GDLocalizedString("help.config.voices.content")],
                     index: IndexPath(row: 0, section: HelpSection.configuration)),
        
        // Audio AR Headsets - AirPods
        SectionedHelpPage(id: "help.using_headsets.airpods.title", title: GDLocalizedString("help.using_headsets.airpods.title"),
                          what: [GDLocalizedString("help.using_headsets.airpods.what")],
                          when: [GDLocalizedString("help.using_headsets.airpods.when")],
                          how: [GDLocalizedString("help.using_headsets.airpods.how.1"),
                                GDLocalizedString("help.using_headsets.airpods.how.2")],
                          index: IndexPath(row: 1, section: HelpSection.configuration)),

        // Audio AR Headsets - Bose Frames
        SectionedHelpPage(id: "help.using_headsets.bose_frames.title", title: GDLocalizedString("help.using_headsets.bose_frames.title"),
                          what: [GDLocalizedString("help.using_headsets.bose_frames.what")],
                          when: [GDLocalizedString("help.using_headsets.bose_frames.when")],
                          how: [GDLocalizedString("help.using_headsets.bose_frames.how.1"),
                                GDLocalizedString("help.using_headsets.bose_frames.how.2"),
                                GDLocalizedString("help.using_headsets.bose_frames.how.3"),
                                GDLocalizedString("help.using_headsets.bose_frames.how.4")],
                          index: IndexPath(row: 2, section: HelpSection.configuration)),
        
        // Using Media Controls
        SectionedHelpPage(id: "help.remote.page_title", title: GDLocalizedString("help.remote.page_title"),
                          what: [GDLocalizedString("help.text.remote_control.what")],
                          when: [GDLocalizedString("help.text.remote_control.when")],
                          how: [GDLocalizedString("help.text.remote_control.how")],
                          index: IndexPath(row: 3, section: HelpSection.configuration)),
        
        // Destination Beacons
        SectionedHelpPage(id: "beacon.audio_beacon", title: GDLocalizedString("beacon.audio_beacon"),
                          what: [GDLocalizedString("help.text.destination_beacons.what")],
                          when: [GDLocalizedString("help.text.destination_beacons.when")],
                          how: [GDLocalizedString("help.text.destination_beacons.how.1"),
                                GDLocalizedString("help.text.destination_beacons.how.2"),
                                GDLocalizedString("help.text.destination_beacons.how.3")],
                          index: IndexPath(row: 0, section: HelpSection.beaconsAndCallouts)),

        // Automatic Callouts
        SectionedHelpPage(id: "callouts.automatic_callouts", title: GDLocalizedString("callouts.automatic_callouts"),
                          what: [GDLocalizedString("help.text.automatic_callouts.what")],
                          when: [GDLocalizedString("help.text.automatic_callouts.when.1"),
                                 GDLocalizedString("help.text.automatic_callouts.when.2"),
                                 GDLocalizedString("help.text.automatic_callouts.when.3")],
                          how: [GDLocalizedString("help.text.automatic_callouts.how.1"),
                                GDLocalizedString("help.text.automatic_callouts.how.2")],
                          index: IndexPath(row: 1, section: HelpSection.beaconsAndCallouts)),
        
        // My Location
        SectionedHelpPage(id: "directions.my_location", title: GDLocalizedString("directions.my_location"),
                          what: [GDLocalizedString("help.text.my_location.what")],
                          when: [GDLocalizedString("help.text.my_location.when")],
                          how: [GDLocalizedString("help.text.my_location.how")],
                          index: IndexPath(row: 0, section: HelpSection.homeScreen)),
        
        // Around Me
        SectionedHelpPage(id: "help.orient.page_title", title: GDLocalizedString("help.orient.page_title"),
                          what: [GDLocalizedString("help.text.around_me.what")],
                          when: [GDLocalizedString("help.text.around_me.when")],
                          how: [GDLocalizedString("help.text.around_me.how")],
                          index: IndexPath(row: 1, section: HelpSection.homeScreen)),
        
        // Ahead of Me
        SectionedHelpPage(id: "help.explore.page_title", title: GDLocalizedString("help.explore.page_title"),
                          what: [GDLocalizedString("help.text.ahead_of_me.what")],
                          when: [GDLocalizedString("help.text.ahead_of_me.when")],
                          how: [GDLocalizedString("help.text.ahead_of_me.how")],
                          index: IndexPath(row: 2, section: HelpSection.homeScreen)),
        
        // Nearby Markers
        SectionedHelpPage(id: "callouts.nearby_markers", title: GDLocalizedString("callouts.nearby_markers"),
                          what: [GDLocalizedString("help.text.nearby_markers.what")],
                          when: [GDLocalizedString("help.text.nearby_markers.when")],
                          how: [GDLocalizedString("help.text.nearby_markers.how")],
                          index: IndexPath(row: 3, section: HelpSection.homeScreen)),
        
        // Markers
        TextHelpPage(id: "markers.title", title: GDLocalizedString("markers.title"),
                     text: [GDLocalizedString("help.text.markers.content.1"),
                            GDLocalizedString("help.text.markers.content.2"),
                            GDLocalizedString("help.text.markers.content.3")],
                     index: IndexPath(row: 0, section: HelpSection.markersAndRoutes)),
        
        // Routes
        SectionedHelpPage(id: "routes.title", title: GDLocalizedString("routes.title"),
                          what: [GDLocalizedString("help.text.routes.content.what")],
                          when: [GDLocalizedString("help.text.routes.content.when")],
                          how: [
                            GDLocalizedString("help.text.routes.content.how.1"),
                            GDLocalizedString("help.text.routes.content.how.1a"),
                           GDLocalizedString("help.text.routes.content.how.2"),
                            GDLocalizedString("help.text.routes.content.how.3")
                          ],
                          index: IndexPath(row: 1, section: HelpSection.markersAndRoutes)),
        
        // Creating Markers
        TextHelpPage(id: "help.creating_markers.page_title", title: GDLocalizedString("help.creating_markers.page_title"),
                     text: [GDLocalizedString("help.text.creating_markers.content.1"),
                            GDLocalizedString("help.text.creating_markers.content.2")],
                     index: IndexPath(row: 2, section: HelpSection.markersAndRoutes)),
        
        // Customizing Markers
        TextHelpPage(id: "help.edit_markers.page_title", title: GDLocalizedString("help.edit_markers.page_title"),
                     text: [GDLocalizedString("help.text.customizing_markers.content.1"),
                            GDLocalizedString("help.text.customizing_markers.content.2")],
                     index: IndexPath(row: 3, section: HelpSection.markersAndRoutes)),
        
        // Frequently Asked Questions
        FAQListHelpPage(id: "faq.title", title: GDLocalizedString("faq.title"),
                        sections: [FAQSection(heading: GDLocalizedString("faq.section.what_is_soundscape"),
                                              faqs: [FAQ("faq.when_to_use_soundscape"),
                                                     FAQ("faq.markers_function")]),
                                   FAQSection(heading: GDLocalizedString("faq.section.getting_the_best_experience"),
                                              faqs: [FAQ("faq.what_can_I_set"),
                                                     FAQ("faq.how_to_use_beacon"),
                                                     FAQ("faq.why_does_beacon_disappear"),
                                                     FAQ("faq.beacon_on_address"),
                                                     FAQ("faq.beacon_on_home"),
                                                     FAQ("faq.how_close_to_destination"),
                                                     FAQ("faq.turn_beacon_back_on"),
                                                     FAQ("faq.road_names"),
                                                     FAQ("faq.why_not_every_business"),
                                                     FAQ("faq.callouts_stopping_in_vehicle"),
                                                     FAQ("faq.miss_a_callout")]),
                                   FAQSection(heading: GDLocalizedString("faq.section.how_soundscape_works"),
                                              faqs: [FAQ("faq.supported_phones"),
                                                     FAQ("faq.supported_headsets"),
                                                     FAQ("faq.battery_impact"),
                                                     FAQ("faq.sleep_mode_battery"),
                                                     FAQ("faq.snooze_mode_battery"),
                                                     FAQ("faq.headset_battery_impact"),
                                                     FAQ("faq.background_battery_impact"),
                                                     FAQ("faq.mobile_data_use"),
                                                     FAQ("faq.difference_from_map_apps"),
                                                     FAQ("faq.use_with_wayfinding_apps"),
                                                     FAQ("faq.controlling_what_you_hear"),
                                                     FAQ("faq.holding_phone_flat"),
                                                     FAQ("faq.personalize_experience"),
                                                     FAQ("faq.what_is_osm")])],
                        index: IndexPath(row: 0, section: HelpSection.faq)),
        
        // Tips and Tricks
        TextHelpPage(id: "faq.tips.title", title: GDLocalizedString("faq.tips.title"),
                     text: [GDLocalizedString("faq.tip.beacon_quiet"),
                            GDLocalizedString("faq.tip.setting_beacon_on_address"),
                            GDLocalizedString("faq.tip.finding_bus_stops"),
                            GDLocalizedString("faq.tip.turning_beacon_off"),
                            GDLocalizedString("faq.tip.turning_off_auto_callouts"),
                            GDLocalizedString("faq.tip.hold_phone_flat"),
                            GDLocalizedString("faq.tip.create_marker_at_bus_stop"),
                            GDLocalizedString("faq.tip.two_finger_double_tap"),
                            GDLocalizedString("faq.tip.reverse_route")],
                     index: IndexPath(row: 1, section: HelpSection.faq))
    ]
    
    private struct HelpSection {
        static let configuration = 0
        static let beaconsAndCallouts = 1
        static let homeScreen = 2
        static let markersAndRoutes = 3
        static let faq = 4
    }

    @ViewBuilder
    var body: some View {
        switch route {
        case .none:
            VStack(spacing: 0) {
                NavigationBanner()
                helpList
            }
            .navigationTitle(GDLocalizedString("settings.help.title"))
            .navigationBarStyle(style: .darkBlue)
            .toolbar(.visible, for: .navigationBar)
        case .page(let id):
            if let page = helpPages.first(where: { $0.id == id }) {
                VStack(spacing: 0) {
                    NavigationBanner()
                    pageContent(page)
                }
                .navigationTitle(page.title)
                .navigationBarStyle(style: .darkBlue)
                .toolbar(.visible, for: .navigationBar)
            }
        case .answer(let id):
            if let answer = helpPages.compactMap({ $0 as? FAQListHelpPage })
                .flatMap({ $0.sections }).flatMap({ $0.faqs }).first(where: { $0.id == id }) {
                let paragraphs = answer.answer.split(separator: "\n").map(String.init)
                VStack(spacing: 0) {
                    NavigationBanner()
                    HelpContentView(sections: [.init(title: answer.question, paragraphs: paragraphs)])
                }
                .navigationTitle(GDLocalizedString("faq.title.abbreviated"))
                .navigationBarStyle(style: .darkBlue)
                .toolbar(.visible, for: .navigationBar)
            }
        case .offline:
            VStack(spacing: 0) {
                NavigationBanner(isOfflineHelp: true)
                OfflineHelpContentView()
            }
            .navigationTitle(GDLocalizedString("help.offline.section_title"))
            .navigationBarStyle(style: .darkBlue)
            .toolbar(.visible, for: .navigationBar)
        case .beaconTutorial:
            LegacyNavigationScreen {
                let controller = DestinationTutorialIntroViewController(source: nil, logContext: "help_screen")
                controller.onFinish = { navigation.close(.helpPage(.beaconTutorial)) }
                return controller
            }
        case .markerTutorial:
            LegacyNavigationScreen { MarkerTutorialViewController(logContext: "help_screen") }
        }
    }

    private var helpList: some View {
        List {
            SwiftUI.Section(GDLocalizedString("help.configuration.section.title")) {
                pages(in: HelpSection.configuration)
                helpLink(GDLocalizedString("first_launch.help.title")) { navigation.helpTutorial.wrappedValue = true }
            }
            SwiftUI.Section(GDLocalizedString("settings.help.section.beacons_and_pois")) {
                pages(in: HelpSection.beaconsAndCallouts)
            }
            SwiftUI.Section(GDLocalizedString("settings.help.section.home_screen_buttons")) {
                pages(in: HelpSection.homeScreen)
            }
            SwiftUI.Section(GDLocalizedString("search.view_markers")) {
                pages(in: HelpSection.markersAndRoutes)
            }
            SwiftUI.Section(GDLocalizedString("faq.title")) {
                pages(in: HelpSection.faq)
                helpLink(GDLocalizedString("help.offline.section_title")) {
                    navigation.open(.helpPage(.offline))
                }
            }
            SwiftUI.Section {
                Group {
                    helpLink(GDLocalizedString("tutorial.beacon.getting_started")) {
                        navigation.open(.helpPage(.beaconTutorial))
                    }
                    helpLink(GDLocalizedString("tutorial.markers.getting_started")) {
                        navigation.open(.helpPage(.markerTutorial))
                    }
                }
                .disabled(AppContext.shared.isRouteGuidanceActive)
            } header: {
                GDLocalizedTextView("tutorial.title.plural")
            } footer: {
                if AppContext.shared.isRouteGuidanceActive {
                    GDLocalizedTextView("help.tutorial.footer.disabled")
                }
            }
            SwiftUI.Section(GDLocalizedString("help.more_help.section_title")) {
                Link(destination: AppContext.Links.companySupportURL) {
                    GDLocalizedTextView("help.support")
                }
            }
        }
        .listStyle(.insetGrouped)
        .settingsListBackground()
        .background(Color.quaternaryBackground.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
    }

    private func pages(in section: Int) -> some View {
        ForEach(helpPages.filter { $0.index.section == section }, id: \.id) { page in
            helpLink(page.title) { navigation.open(.helpPage(.page(page.id))) }
        }
    }

    @ViewBuilder
    private func pageContent(_ page: HelpPage) -> some View {
        switch page {
        case let sectioned as SectionedHelpPage:
            HelpContentView(sections: [
                .init(title: GDLocalizedString("help.text.section_title.what"), paragraphs: sectioned.what),
                .init(title: GDLocalizedString("help.text.section_title.when"), paragraphs: sectioned.when),
                .init(title: GDLocalizedString("help.text.section_title.how"), paragraphs: sectioned.how)
            ], link: sectioned.link)
        case let text as TextHelpPage:
            HelpContentView(sections: [.init(paragraphs: text.text)])
        case let faq as FAQListHelpPage:
            List {
                ForEach(faq.sections.indices, id: \.self) { index in
                    let section = faq.sections[index]
                    SwiftUI.Section(section.heading) {
                        ForEach(section.faqs) { answer in
                            helpLink(answer.question) { navigation.open(.helpPage(.answer(answer.id))) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        default:
            EmptyView()
        }
    }

}

private func helpLink(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack {
            Text(verbatim: title)
            Spacer()
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(Color.primaryForeground)
    .listRowBackground(Color.primaryBackground)
    .listRowSeparatorTint(Color.secondaryBackground)
}

final class HelpScreenModel: ObservableObject {
    let banner = UIView()
    @Published var bannerHeight: CGFloat = 0
    @Published var content: AnyView

    init(content: AnyView) {
        self.content = content
    }
}

struct HelpScreen: View {
    @ObservedObject var model: HelpScreenModel

    var body: some View {
        VStack(spacing: 0) {
            EmbeddedView(content: model.banner)
                .frame(height: model.bannerHeight)
                .clipped()
                .accessibilityHidden(model.bannerHeight == 0)
            model.content
        }
    }
}

class HelpHostingController: UIHostingController<HelpScreen>, LargeBannerContainerView {
    private let model: HelpScreenModel

    var largeBannerContainerView: UIView! { model.banner }

    init(title: String, content: AnyView = AnyView(EmptyView())) {
        let model = HelpScreenModel(content: content)
        self.model = model
        super.init(rootView: HelpScreen(model: model))
        self.title = title
    }

    required dynamic init?(coder: NSCoder) {
        fatalError("Use init(title:content:)")
    }

    func setContent(_ content: AnyView) {
        model.content = content
    }

    func setLargeBannerHeight(_ height: CGFloat) {
        model.bannerHeight = height
    }
}

struct HelpContentView: View {
    struct ContentSection {
        var title: String?
        let paragraphs: [String]
    }

    let sections: [ContentSection]
    var link: SectionedHelpPageDeepLink?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(sections.indices, id: \.self) { index in
                    let section = sections[index]
                    VStack(alignment: .leading, spacing: 12) {
                        if index > sections.startIndex {
                            Divider().overlay(Color.secondaryBackground)
                        }
                        if let title = section.title {
                            Text(verbatim: title)
                                .font(index == sections.startIndex ? .title : .title3)
                                .foregroundStyle(index == sections.startIndex ? Color.primaryForeground : Color.secondaryForeground)
                                .accessibilityAddTraits(.isHeader)
                        }
                        if section.paragraphs.isEmpty {
                            GDLocalizedTextView("text.coming_soon")
                        } else {
                            ForEach(section.paragraphs.indices, id: \.self) { index in
                                let paragraph = section.paragraphs[index]
                                HelpParagraph(source: paragraph).id(paragraph)
                            }
                        }
                    }
                }
                if let link, UIApplication.shared.canOpenURL(link.url) {
                    Link(destination: link.url) {
                        Text(verbatim: link.title)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .foregroundStyle(Color.primaryForeground)
        .tint(.secondaryForeground)
        .background(Color.quaternaryBackground.ignoresSafeArea())
    }
}

private struct HelpParagraph: View {
    let source: String
    @State private var formatted: AttributedString?

    private var containsHTML: Bool {
        source.contains("<") || source.contains("&")
    }

    var body: some View {
        if containsHTML {
            Text(formatted ?? AttributedString())
                .task { await loadHTML() }
        } else {
            Text(verbatim: source)
        }
    }

    private func loadHTML() async {
        guard formatted == nil else { return }
        // The synchronous HTML importer spins the main run loop and can reenter SwiftUI layout.
        guard let (html, _) = try? await NSAttributedString.fromHTML(source) else {
            if !Task.isCancelled { formatted = AttributedString(source) }
            return
        }
        guard !Task.isCancelled else { return }

        var text = AttributedString(html)
        // Use the screen's body font and Dynamic Type while preserving emphasis.
        for run in text.runs {
            guard let font = run.uiKit.font else { continue }
            let traits = font.fontDescriptor.symbolicTraits
            var intent: InlinePresentationIntent = []
            if traits.contains(.traitBold) { intent.insert(.stronglyEmphasized) }
            if traits.contains(.traitItalic) { intent.insert(.emphasized) }
            text[run.range].inlinePresentationIntent = intent
            text[run.range].uiKit.font = nil
            text[run.range].uiKit.foregroundColor = nil
        }
        formatted = text
    }
}
