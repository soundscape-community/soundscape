//
//  URLResourceHandler.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import Foundation

protocol URLResourceHandler {
    /// Consume or move the staged file synchronously. The manager removes its
    /// directory when this method returns; later work must use decoded values
    /// or a separately owned copy, rather than retaining this URL.
    func handleURLResource(with url: URL)
}
