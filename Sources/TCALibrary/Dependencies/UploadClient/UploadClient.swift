//
//  UploadClient.swift
//  FlashCards
//
//  Created by David Croy on 7/12/24.
//

import ComposableArchitecture
import Foundation

@DependencyClient
struct UploadClient {
  var upload: @Sendable (_ request: URLRequest) -> AsyncThrowingStream<Event, Error> = { _ in .finished() }
  
  @CasePathable
  enum Event: Equatable {
    case response(Data)
    case progress(Double)
  }
}

extension DependencyValues {
  var uploadClient: UploadClient {
    get { self[UploadClient.self] }
    set { self[UploadClient.self] = newValue }
  }
}

extension UploadClient: DependencyKey {
  static let liveValue = Self(
    upload: { request in
        .init { continuation in
          Task {
            do {
              let (data, response) = try await URLSession.shared.data(for: request)
              continuation.yield(.response(data))
//              continuation.yield(.uploadResponse)
              continuation.finish()
            } catch {
              continuation.finish(throwing: error)
            }
          }
        }
    }
  )
  
  static let testValue = Self()
}
