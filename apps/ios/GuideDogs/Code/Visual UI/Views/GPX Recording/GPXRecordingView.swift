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
    @Environment(\.presentationMode) private var presentationMode
    @State private var showDiscardConfirmation = false

    var body: some View {
        List {
            Section {
                Text(GDLocalizedString("gpx_recording.explanation"))
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text(GDLocalizedString("gpx_recording.status"))
                    Spacer()
                    Text(statusText)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("gpx-recording-status")
                }

                if controller.pointCount > 0 {
                    Text(String(format: GDLocalizedString("gpx_recording.point_count"), controller.pointCount))
                        .foregroundColor(.secondary)
                }

                controls
            }

            if let error = controller.error {
                Section {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .accessibilityLabel(String(format: GDLocalizedString("gpx_recording.error.accessibility"), error.localizedDescription))
                }
            }

            if controller.failedCloudSave {
                Section(header: Text(GDLocalizedString("gpx_recording.save_options"))) {
                    Button(GDLocalizedString("gpx_recording.retry_icloud")) {
                        controller.retryCloudSave()
                    }
                    Button(GDLocalizedString("gpx_recording.save_local")) {
                        controller.saveLocally()
                    }
                    Button(GDLocalizedString("gpx_recording.discard"), role: .destructive) {
                        showDiscardConfirmation = true
                    }
                }
            }

            Section(header: Text(GDLocalizedString("gpx_recording.saved"))) {
                if controller.recordings.isEmpty {
                    Text(GDLocalizedString("gpx_recording.saved.empty"))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(controller.recordings) { file in
                        Button {
                            controller.share(file)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.displayName)
                                    .foregroundColor(.primary)
                                Text(file.storageLocation.localizedName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .accessibilityHint(GDLocalizedString("gpx_recording.share.hint"))
                    }
                }
            }
        }
        .navigationTitle(GDLocalizedString("gpx_recording.title"))
        .refreshable {
            await controller.refresh()
        }
        .onAppear {
            controller.screenAppeared()
        }
        .fullScreenCover(isPresented: namingPresented) {
            NavigationView {
                Form {
                    Section(header: Text(GDLocalizedString("gpx_recording.name.prompt"))) {
                        TextField(GDLocalizedString("gpx_recording.name"), text: $controller.proposedName)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }
                    if let error = controller.error {
                        Text(error.localizedDescription)
                            .foregroundColor(.red)
                    }
                    if controller.failedCloudSave {
                        Section(header: Text(GDLocalizedString("gpx_recording.save_options"))) {
                            Button(GDLocalizedString("gpx_recording.retry_icloud")) {
                                controller.retryCloudSave()
                            }
                            Button(GDLocalizedString("gpx_recording.save_local")) {
                                controller.saveLocally()
                            }
                        }
                    }
                }
                .navigationTitle(GDLocalizedString("gpx_recording.name.title"))
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
                Spacer()
            }
            .accessibilityLabel(statusText)
        case .idle:
            Button(GDLocalizedString("gpx_recording.start")) {
                controller.start()
            }
            .buttonStyle(.borderedProminent)
        case .recording, .paused:
            Button(GDLocalizedString("gpx_recording.stop"), role: .destructive) {
                controller.stop()
            }
            .buttonStyle(.borderedProminent)
        case .recoverableInterruption:
            Button(GDLocalizedString("gpx_recording.recover.save")) {
                controller.prepareRecoveredDraftForSaving()
            }
            Button(GDLocalizedString("gpx_recording.discard"), role: .destructive) {
                showDiscardConfirmation = true
            }
        case .awaitingName:
            EmptyView()
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

final class GPXRecordingHostingController: UIHostingController<GPXRecordingView> {
    @MainActor
    convenience init() {
        self.init(controller: .shared)
    }

    @MainActor
    init(controller: GPXRecordingController) {
        super.init(rootView: GPXRecordingView(controller: controller))
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
