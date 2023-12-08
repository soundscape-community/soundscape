//
//  NetworkClient.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import Foundation

enum NetworkError: Error {
    case noDataReturned
}

struct NetworkResponse {
    var allHeaderFields: [AnyHashable: Any]
    var statusCode: HTTPStatusCode
    
    static var empty: NetworkResponse {
        return .init(allHeaderFields: [:], statusCode: .unknown(0))
    }
}

protocol NetworkClient {
    func requestData(_ request: URLRequest) async throws -> (Data, NetworkResponse)
}

extension URLSession: NetworkClient {
    func requestData(_ request: URLRequest) async throws -> (Data, NetworkResponse) {
        request.log()
        
        if #available(iOS 15.0, *) {
            let (data, response) = try await data(for: request)
            response.log(request: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return (data, NetworkResponse(allHeaderFields: [:], statusCode: .unknown(0)))
            }
            
            return (data, NetworkResponse(allHeaderFields: httpResponse.allHeaderFields, statusCode: HTTPStatusCode(rawValue: httpResponse.statusCode)))
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                let task: URLSessionDataTask = dataTask(with: request) { (data, response, error) in
                    if let error = error {
                        continuation.resume(with: .failure(error))
                        return
                    }
                    
                    guard let data = data else {
                        continuation.resume(with: .failure(NetworkError.noDataReturned))
                        return
                    }
                    
                    response?.log(request: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.resume(with: .success((data, .empty)))
                        return
                    }
                    
                    let response = NetworkResponse(allHeaderFields: httpResponse.allHeaderFields, statusCode: HTTPStatusCode(rawValue: httpResponse.statusCode))
                    continuation.resume(with: .success((data, response)))
                }
                
                task.resume()
            }
        }
    }
}

extension URLRequest {
    func log() {
        guard let method = httpMethod?.prefix(3) else {
            return
        }
        
        GDLogVerbose(.network, "Request (\(method)) \(url?.absoluteString ?? "unknown")")
    }
}

extension URLResponse {
    func log(request: URLRequest) {
        let statusString: String
        if let res = self as? HTTPURLResponse {
            statusString = res.statusCode.description
        } else {
            statusString = "unknown"
        }
        
        guard let method = request.httpMethod?.prefix(3) else {
            return
        }
        
        GDLogVerbose(.network, "Response (\(method)) \(statusString) '\(request.url?.absoluteString ?? "unknown")'")
    }
}
