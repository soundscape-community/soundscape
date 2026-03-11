//
//  RouteStore.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributers.
//  Licensed under the MIT License.
//

import SwiftUI
import Combine

class RouteStore: ObservableObject {
    private(set) var detail: RouteDetail
    
    private var tokens: [AnyCancellable] = []
    private var detailTokens: [AnyCancellable] = []
    
    init(_ detail: RouteDetail) {
        self.detail = detail
        bind(detail)
            
        tokens.append(NotificationCenter.default.publisher(for: .markerAdded).receive(on: RunLoop.main).sink(receiveValue: { [weak self] _ in
            self?.objectWillChange.send()
        }))
        
        tokens.append(NotificationCenter.default.publisher(for: .markerUpdated).receive(on: RunLoop.main).sink(receiveValue: { [weak self] _ in
            self?.objectWillChange.send()
        }))
        
        tokens.append(NotificationCenter.default.publisher(for: .routeUpdated).receive(on: RunLoop.main).sink(receiveValue: { [weak self] _ in
            self?.objectWillChange.send()
        }))
    }
    
    deinit {
        tokens.cancelAndRemoveAll()
        detailTokens.cancelAndRemoveAll()
    }
    
    func update(_ detail: RouteDetail) {
        self.detail = detail
        bind(detail)
        objectWillChange.send()
    }

    private func bind(_ detail: RouteDetail) {
        detailTokens.cancelAndRemoveAll()
        detailTokens.append(detail.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.objectWillChange.send()
        })
    }
}
