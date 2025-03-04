//
//  UploadClient.swift
//  FlashCards
//
//  Created by David Croy on 7/12/24.
//

import ComposableArchitecture
import Foundation

@DependencyClient
public struct UploadClient: @unchecked Sendable {
  public var upload: @Sendable (_ request: URLRequest) -> AsyncThrowingStream<Event, Error> = { _ in .finished() }
  
  @CasePathable
  public enum Event: Equatable, Sendable {
    case response(Data)
    case progress(Double)
  }
}

extension DependencyValues {
  public var uploadClient: UploadClient {
    get { self[UploadClient.self] }
    set { self[UploadClient.self] = newValue }
  }
}

extension UploadClient: DependencyKey {
  public static let liveValue = Self(
    upload: { request in
      AsyncThrowingStream<Event, Error>(bufferingPolicy: .unbounded) { continuation in
        Task {
          do {
            let (data, _) = try await URLSession.shared.data(for: request)
            continuation.yield(.response(data))
            continuation.finish()
          } catch {
            continuation.finish(throwing: error)
          }
        }
      }
    }
  )
  
  public static let testValue = Self()
}
