//
//  GPXRecordingView.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

struct GPXRecordingView: View {
    @ObservedObject var controller: GPXRecordingController
    @State private var showDiscardConfirmation = false

    var body: some View {
        List {
            Section {
                Text(GDLocalizedString("gpx_recording.explanation"))
                    .foregroundColor(.primaryForeground)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text(GDLocalizedString("gpx_recording.status"))
                        .foregroundColor(.primaryForeground)
                    Spacer()
                    Text(statusText)
                        .foregroundColor(statusColor)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("gpx-recording-status")
                }

                if controller.pointCount > 0 {
                    Text(String(format: GDLocalizedString("gpx_recording.point_count"), controller.pointCount))
                        .foregroundColor(.secondaryForeground)
                }

                controls
            }
            .listRowBackground(Color.primaryBackground)
            .listRowSeparatorTint(Color.secondaryBackground)

            if let error = controller.error {
                Section {
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.primaryForeground)
                        .accessibilityLabel(String(format: GDLocalizedString("gpx_recording.error.accessibility"), error.localizedDescription))
                }
                .listRowBackground(Color.errorBackground)
            }

            Section(header: GPXRecordingSectionHeader(text: GDLocalizedString("gpx_recording.saved"))) {
                if controller.recordings.isEmpty {
                    Text(GDLocalizedString("gpx_recording.saved.empty"))
                        .foregroundColor(.secondaryForeground)
                } else {
                    ForEach(controller.recordings) { file in
                        Button {
                            controller.share(file)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(file.displayName)
                                        .foregroundColor(.primaryForeground)
                                    Text(GDLocalizedString("gpx_recording.storage.local"))
                                        .font(.caption)
                                        .foregroundColor(.secondaryForeground)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.tertiaryForeground)
                                    .accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(GDLocalizedString("gpx_recording.share.hint"))
                    }
                }
            }
            .listRowBackground(Color.primaryBackground)
            .listRowSeparatorTint(Color.secondaryBackground)
        }
        .settingsListBackground()
        .background(Color.quaternaryBackground.ignoresSafeArea())
        .listStyle(.plain)
        .tint(.primaryForeground)
        .navigationTitle(GDLocalizedString("gpx_recording.title"))
        .navigationBarStyle(style: .darkBlue)
        .refreshable {
            await controller.refresh()
        }
        .onAppear {
            controller.screenAppeared()
        }
        .fullScreenCover(isPresented: namingPresented) {
            NavigationView {
                Form {
                    Section(header: GPXRecordingSectionHeader(text: GDLocalizedString("gpx_recording.name.prompt"))) {
                        TextField(GDLocalizedString("gpx_recording.name"), text: $controller.proposedName)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(.quaternaryBackground)
                    }
                    .listRowBackground(Color.primaryBackground)
                    .listRowSeparatorTint(Color.secondaryBackground)

                    if let error = controller.error {
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.primaryForeground)
                            .listRowBackground(Color.errorBackground)
                    }
                }
                .settingsListBackground()
                .background(Color.quaternaryBackground.ignoresSafeArea())
                .listStyle(.plain)
                .tint(.primaryForeground)
                .navigationTitle(GDLocalizedString("gpx_recording.name.title"))
                .navigationBarStyle(style: .darkBlue)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(GDLocalizedString("gpx_recording.discard"), role: .destructive) {
                            showDiscardConfirmation = true
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(GDLocalizedString("gpx_recording.save")) {
                            controller.save()
                        }
                        .disabled(controller.state == .saving)
                    }
                }
                .interactiveDismissDisabled()
                .confirmationDialog(GDLocalizedString("gpx_recording.discard.confirm"),
                                    isPresented: $showDiscardConfirmation,
                                    titleVisibility: .visible) {
                    Button(GDLocalizedString("gpx_recording.discard"), role: .destructive) {
                        controller.discard()
                    }
                    Button(GDLocalizedString("general.alert.cancel"), role: .cancel) {}
                }
            }
            .navigationViewStyle(.stack)
        }
        .confirmationDialog(GDLocalizedString("gpx_recording.discard.confirm"),
                            isPresented: $showDiscardConfirmation,
                            titleVisibility: .visible) {
            Button(GDLocalizedString("gpx_recording.discard"), role: .destructive) {
                controller.discard()
            }
            Button(GDLocalizedString("general.alert.cancel"), role: .cancel) {}
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch controller.state {
        case .loading, .starting, .saving:
            HStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .primaryForeground))
                Spacer()
            }
            .accessibilityLabel(statusText)
        case .idle:
            GPXRecordingActionButton(
                title: GDLocalizedString("gpx_recording.start"),
                systemImage: "record.circle",
                backgroundColor: .primaryForeground,
                foregroundColor: .primaryBackground
            ) {
                controller.start()
            }
        case .recording, .paused:
            GPXRecordingActionButton(
                title: GDLocalizedString("gpx_recording.stop"),
                systemImage: "stop.fill",
                backgroundColor: .errorBackground,
                foregroundColor: .primaryForeground
            ) {
                controller.stop()
            }
        case .recoverableInterruption:
            GPXRecordingActionButton(
                title: GDLocalizedString("gpx_recording.recover.save"),
                systemImage: "square.and.arrow.down",
                backgroundColor: .primaryForeground,
                foregroundColor: .primaryBackground
            ) {
                controller.prepareRecoveredDraftForSaving()
            }
            GPXRecordingActionButton(
                title: GDLocalizedString("gpx_recording.discard"),
                systemImage: "trash",
                backgroundColor: .errorBackground,
                foregroundColor: .primaryForeground
            ) {
                showDiscardConfirmation = true
            }
        case .awaitingName:
            EmptyView()
        }
    }

    private var statusColor: Color {
        switch controller.state {
        case .recording:
            return .yellowHighlight
        case .paused, .recoverableInterruption:
            return .tertiaryForeground
        default:
            return .secondaryForeground
        }
    }

    private var statusText: String {
        switch controller.state {
        case .loading:
            return GDLocalizedString("gpx_recording.status.loading")
        case .idle:
            return GDLocalizedString("gpx_recording.status.idle")
        case .starting:
            return GDLocalizedString("gpx_recording.status.starting")
        case .recording:
            return GDLocalizedString("gpx_recording.status.recording")
        case .paused:
            return GDLocalizedString("gpx_recording.status.paused")
        case .awaitingName:
            return GDLocalizedString("gpx_recording.status.awaiting_name")
        case .saving:
            return GDLocalizedString("gpx_recording.status.saving")
        case .recoverableInterruption:
            return GDLocalizedString("gpx_recording.status.recovered")
        }
    }

    private var namingPresented: Binding<Bool> {
        Binding(
            get: { controller.state == .awaitingName || controller.state == .saving },
            set: { _ in }
        )
    }
}

private struct GPXRecordingSectionHeader: View {
    let text: String

    var body: some View {
        Text(text.localizedUppercase)
            .font(.caption)
            .foregroundColor(.primaryForeground)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct GPXRecordingActionButton: View {
    let title: String
    let systemImage: String
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.body.bold())
                .foregroundColor(foregroundColor)
                .roundedBackground(backgroundColor)
        }
        .buttonStyle(.plain)
    }
}

final class GPXRecordingHostingController: UIHostingController<GPXRecordingView> {
    @MainActor
    convenience init() {
        self.init(controller: .shared)
    }

    @MainActor
    init(controller: GPXRecordingController) {
        super.init(rootView: GPXRecordingView(controller: controller))
        view.backgroundColor = Colors.Background.quaternary
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
