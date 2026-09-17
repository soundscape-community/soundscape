//
//  URLResourceManager.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation
import Combine

/*
 Delegates URL resources to the appropriate handler after the resource is opened by the app.
 
 Supported resource types are defined in the Info.plist (`Imported Type Identifiers` and `Exported Type Identifiers`) and the expected identifier is additionally defined in `URLResourceIdentifier`
 */
class URLResourceManager {
    
    private struct URLResource {
        let identifier: URLResourceIdentifier
        let filename: String
        let stagedURL: Result<URL, Error>
    }
    
    // MARK: Properties
    
    private var listeners: [AnyCancellable] = []
    private var pendingURLResources: [URLResource] = []
    private var homeViewControllerDidLoad = false
    private var queue = DispatchQueue(label: "services.soundscape.urlresourcemanager")
    private let fileManager: FileManager
    private let importDirectory: URL
    // Handlers
    private let gpxHandler = GPXResourceHandler()
    private let routeHandler = RouteResourceHandler()
    
    // MARK: Initialization
    
    init(fileManager: FileManager = .default,
         importDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("Incoming URL Resources", isDirectory: true)) {
        self.fileManager = fileManager
        self.importDirectory = importDirectory
        listeners.append(NotificationCenter.default.publisher(for: .homeViewControllerDidLoad)
                            .receive(on: RunLoop.main)
                            .sink(receiveValue: { [weak self] _ in
                                guard let `self` = self else {
                                    return
                                }
                                
                                self.queue.async {
                                    self.homeViewControllerDidLoad = true
                                    
                                    for resource in self.pendingURLResources {
                                        self.openResource(resource)
                                    }
                                    
                                    self.pendingURLResources = []
                                }
                            }))
    }
    
    // MARK: Manage URL Resources
    
    /*
     Delegates URL resources to the appropriate handler.
     
     Returns TRUE if the resource type is supported by the app and has a corresponding handler
    Returns FALSE if the resource type is not supported
     */
    func onOpenResource(from url: URL) -> Bool {
        guard let identifier = URLResourceIdentifier(pathExtension: url.pathExtension) else {
            GDLogURLResourceError("Unsupported incoming file: \(url.lastPathComponent)")
            return false
        }

        GDLogURLResourceVerbose("Opening incoming file: \(url.lastPathComponent)")

        let stagedURL: Result<URL, Error>
        do {
            stagedURL = .success(try stageIncomingFile(at: url))
        } catch {
            GDLogURLResourceError("Failed to copy incoming file \(url.lastPathComponent): \(error)")
            stagedURL = .failure(error)
        }
        let resource = URLResource(identifier: identifier, filename: url.lastPathComponent, stagedURL: stagedURL)
        
        queue.async { [weak self] in
            guard let `self` = self else {
                return
            }
            
            if self.homeViewControllerDidLoad {
                self.openResource(resource)
            } else {
                self.pendingURLResources.append(resource)
            }
        }
        
        return true
    }
    
    private func openResource(_ resource: URLResource) {
        guard case .success(let url) = resource.stagedURL else {
            reportImportFailure(for: resource)
            return
        }
        defer { try? fileManager.removeItem(at: url.deletingLastPathComponent()) }

        let handler: URLResourceHandler
        
        switch resource.identifier {
        case .gpx: handler = gpxHandler
        case .route: handler = routeHandler
        }
        
        handler.handleURLResource(with: url)
    }

    private func stageIncomingFile(at source: URL) throws -> URL {
        let directory = importDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(source.lastPathComponent)
        do {
            let hasSecurityScope = source.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope { source.stopAccessingSecurityScopedResource() }
            }

            var coordinationError: NSError?
            var copyError: Error?
            NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { coordinatedSource in
                do {
                    try fileManager.copyItem(at: coordinatedSource, to: destination)
                } catch {
                    copyError = error
                }
            }
            if let error = coordinationError ?? copyError as NSError? {
                throw error
            }
            return destination
        } catch {
            try? fileManager.removeItem(at: directory)
            throw error
        }
    }

    private func reportImportFailure(for resource: URLResource) {
        DispatchQueue.main.async {
            switch resource.identifier {
            case .route:
                NotificationCenter.default.post(name: .didFailToImportRoute, object: self.routeHandler)
            case .gpx:
                let error: Error
                if case .failure(let stagingError) = resource.stagedURL {
                    error = stagingError
                } else {
                    error = CocoaError(.fileReadUnknown)
                }
                NotificationCenter.default.post(name: .didImportGPXResource,
                                                object: self.gpxHandler,
                                                userInfo: [GPXResourceHandler.Keys.filename: resource.filename,
                                                           GPXResourceHandler.Keys.error: error])
            }
        }
    }
    
    static func removeURLResource(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            GDLogURLResourceError("Failed to remove file for URL resource")
        }
    }
    
}

extension URLResourceManager {
    
    static func shareRoute(_ route: Route) -> URL? {
        return RouteParameters.encodeAndWriteToTemporaryFile(from: route, context: .share)
    }
    
}
