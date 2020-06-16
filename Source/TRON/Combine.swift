//
//  Combine.swift
//  TRON
//
//  Created by Denys Telezhkin on 15.06.2020.
//  Copyright © 2020 Denys Telezhkin. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import Alamofire

//swiftlint:disable all

/// Error that is created in case `DownloadAPIRequest` errors out, but Alamofire and URL loading system report error as nil.
/// Practically, this should never happen ¯\_(ツ)_/¯ .
public struct DownloadError<T, Failure: Error>: Error {

    /// Reported `DownloadResponse`
    public let response: DownloadResponse<T, Failure>

    /// Creates `DownloadError` for `DownloadAPIRequest`.
    ///
    /// - Parameter response: response created by `Alamofire`.
    public init(_ response: DownloadResponse<T, Failure>) {
        self.response = response
    }
}

public protocol RequestCancellable {
    func cancelRequest()
}

extension DataRequest: RequestCancellable {
    public func cancelRequest() {
         _ = cancel()
    }
}

extension DownloadRequest: RequestCancellable {
    public func cancelRequest() {
        _ = cancel()
    }
}

#if canImport(Combine)
import Combine

public extension APIRequest {
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func publisher() -> AnyPublisher<Model, ErrorModel> {
        TronPublisher { subscriber in
            self.perform(withSuccess: { model in
                _ = subscriber.receive(model)
                subscriber.receive(completion: .finished)
            }, failure: { error in
                subscriber.receive(completion: .failure(error))
            })
        }.eraseToAnyPublisher()
    }
}

public extension UploadAPIRequest {
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func publisher() -> AnyPublisher<Model, ErrorModel> {
        TronPublisher { subscriber in
            self.perform(withSuccess: { model in
                _ = subscriber.receive(model)
                subscriber.receive(completion: .finished)
            }, failure: { error in
                subscriber.receive(completion: .failure(error))
            })
        }.eraseToAnyPublisher()
    }
}

public extension DownloadAPIRequest {
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
    func publisher() -> AnyPublisher<Model, ErrorModel> {
        TronPublisher { subscriber in
            self.perform(withSuccess: { success in
                _ = subscriber.receive(success)
                subscriber.receive(completion: .finished)
            }, failure: { error in
                subscriber.receive(completion: .failure(error))
            })
        }.eraseToAnyPublisher()
    }
}

// This should be already provided in Combine, but it's not.
// Adapted from https://github.com/Moya/Moya/blob/development/Sources/CombineMoya/MoyaPublisher.swift

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
internal class TronPublisher<Model, ErrorModel: Error>: Publisher {
    typealias Failure = ErrorModel
    typealias Output = Model
    
    private class Subscription: Combine.Subscription {

        private let cancellable: RequestCancellable?

        init(subscriber: AnySubscriber<Output, Failure>, callback: @escaping (AnySubscriber<Output, Failure>) -> RequestCancellable?) {
            self.cancellable = callback(subscriber)
        }

        func request(_ demand: Subscribers.Demand) {
            // We don't care for the demand right now
        }

        func cancel() {
            cancellable?.cancelRequest()
        }
    }

    private let callback: (AnySubscriber<Output, Failure>) -> RequestCancellable?

    init(callback: @escaping (AnySubscriber<Output, Failure>) -> RequestCancellable?) {
        self.callback = callback
    }

    internal func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        let subscription = Subscription(subscriber: AnySubscriber(subscriber), callback: callback)
        subscriber.receive(subscription: subscription)
    }
}

#endif
