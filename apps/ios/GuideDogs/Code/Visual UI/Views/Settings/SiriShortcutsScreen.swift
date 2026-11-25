//
//  SiriShortcutsScreen.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import CocoaLumberjackSwift
import IntentsUI
import SwiftUI

struct SiriShortcutsScreen: View {
    @State private var voiceShortcuts: [INVoiceShortcut] = []
    @State private var selection: ShortcutRow?
    @State private var pendingResult: Result<Void, Error>?
    @State private var errorMessage: String?
    @ScaledMetric private var minimumRowHeight = 44.0

    private let appShortcuts = UserActionManager.appShortcuts

    var body: some View {
        VStack(spacing: 0) {
            NavigationBanner()
            List {
                Section {
                    ForEach(rows) { row in
                        Button {
                            selection = row
                        } label: {
                            ViewThatFits(in: .horizontal) {
                                HStack {
                                    Text(verbatim: row.title)
                                    Spacer(minLength: 12)
                                    actionLabel(row)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(verbatim: row.title)
                                    actionLabel(row)
                                }
                            }
                            .frame(minHeight: minimumRowHeight, alignment: .leading)
                            .foregroundStyle(Color.primaryForeground)
                        }
                        .accessibilityElement(children: .combine)
                        .listRowBackground(Color.primaryBackground)
                        .listRowSeparatorTint(Color.secondaryBackground)
                    }
                } header: {
                    GDLocalizedTextView("siri_shortcuts.description")
                        .textCase(nil)
                        .foregroundStyle(Color.secondaryForeground)
                }
            }
            .settingsListBackground()
        }
        .background(Color.quaternaryBackground.ignoresSafeArea())
        .navigationTitle(GDLocalizedString("siri_shortcuts.title.beta"))
        .navigationBarStyle(style: .darkBlue)
        .toolbar(.visible, for: .navigationBar)
        .onAppear(perform: reloadShortcuts)
        .onReceive(NotificationCenter.default.publisher(for: .appWillEnterForeground)) { _ in reloadShortcuts() }
        .sheet(item: $selection, onDismiss: finishEditing) { row in
            ShortcutEditor(row: row) { result in
                pendingResult = result
                selection = nil
            }
        }
        .alert(GDLocalizedString("general.error.error_occurred"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(GDLocalizedString("general.alert.dismiss"), role: .cancel) {}
        } message: {
            Text(verbatim: errorMessage ?? "")
        }
    }

    private var rows: [ShortcutRow] {
        appShortcuts.flatMap { shortcut -> [ShortcutRow] in
            guard let activity = shortcut.userActivity else { return [] }
            let added = voiceShortcuts.filter { $0.shortcut.userActivity?.activityType == activity.activityType }
                .sorted {
                    if $0.invocationPhraseEqualToSuggested != $1.invocationPhraseEqualToSuggested {
                        return $0.invocationPhraseEqualToSuggested
                    }
                    return $0.invocationPhrase < $1.invocationPhrase
                }
            return added.isEmpty
                ? [ShortcutRow(id: activity.activityType, appShortcut: shortcut, voiceShortcut: nil)]
                : added.map { ShortcutRow(id: $0.identifier.uuidString, appShortcut: shortcut, voiceShortcut: $0) }
        }
    }

    private func actionLabel(_ row: ShortcutRow) -> some View {
        Group {
            if let shortcut = row.voiceShortcut {
                if shortcut.invocationPhraseEqualToSuggested {
                    GDLocalizedTextView("general.alert.edit")
                } else {
                    Text(verbatim: GDLocalizedString("general.text.string_with_quotation_marks", shortcut.invocationPhrase))
                }
            } else {
                Image(systemName: "plus")
                    .accessibilityLabel(GDLocalizedTextView("general.alert.add"))
            }
        }
        .foregroundStyle(Color(red: 0.67, green: 0.96, blue: 0.96))
    }

    private func reloadShortcuts() {
        INVoiceShortcutCenter.shared.getAllVoiceShortcuts { shortcuts, error in
            if let shortcuts {
                DispatchQueue.main.async { voiceShortcuts = shortcuts }
            } else if let error {
                DDLogError("Error getting voice shortcuts: \(error.localizedDescription)")
            }
        }
    }

    private func finishEditing() {
        defer { pendingResult = nil }
        switch pendingResult {
        case .success: reloadShortcuts()
        case .failure(let error): errorMessage = error.localizedDescription
        case nil: break
        }
    }
}

private struct ShortcutRow: Identifiable {
    let id: String
    let appShortcut: INShortcut
    let voiceShortcut: INVoiceShortcut?

    var title: String { appShortcut.userActivity?.title ?? "" }
}

private struct ShortcutEditor: UIViewControllerRepresentable {
    let row: ShortcutRow
    let finish: (Result<Void, Error>?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(finish: finish) }

    func makeUIViewController(context: Context) -> UIViewController {
        if let shortcut = row.voiceShortcut {
            let editor = INUIEditVoiceShortcutViewController(voiceShortcut: shortcut)
            editor.delegate = context.coordinator
            return editor
        }
        let editor = INUIAddVoiceShortcutViewController(shortcut: row.appShortcut)
        editor.delegate = context.coordinator
        return editor
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    final class Coordinator: NSObject, INUIAddVoiceShortcutViewControllerDelegate, INUIEditVoiceShortcutViewControllerDelegate {
        private let finish: (Result<Void, Error>?) -> Void

        init(finish: @escaping (Result<Void, Error>?) -> Void) {
            self.finish = finish
        }

        func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController,
                                            didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?) {
            finish(error.map { .failure($0) } ?? .success(()))
        }

        func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
            finish(nil)
        }

        func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController,
                                             didUpdate voiceShortcut: INVoiceShortcut?, error: Error?) {
            finish(error.map { .failure($0) } ?? .success(()))
        }

        func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController,
                                             didDeleteVoiceShortcutWithIdentifier identifier: UUID) {
            finish(.success(()))
        }

        func editVoiceShortcutViewControllerDidCancel(_ controller: INUIEditVoiceShortcutViewController) {
            finish(nil)
        }
    }
}

extension INVoiceShortcut {
    /// Returns whether the invocation phrase matches the app's suggestion.
    var invocationPhraseEqualToSuggested: Bool {
        shortcut.userActivity?.suggestedInvocationPhrase == invocationPhrase
    }
}
