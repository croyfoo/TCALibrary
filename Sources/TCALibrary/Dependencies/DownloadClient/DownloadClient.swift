import ComposableArchitecture
import Foundation

@DependencyClient
public struct DownloadClient: @unchecked Sendable {
  public var download: @Sendable (_ url: URLRequest, _ showProgress: Bool ) -> AsyncThrowingStream<Event, Error> = {
    _,_ in .finished()
  }
  
  @CasePathable
  public enum Event: Equatable {
    case response(Data, URLResponse)
    case updateProgress(Double)
  }
}

extension DependencyValues {
  public var downloadClient: DownloadClient {
    get { self[DownloadClient.self] }
    set { self[DownloadClient.self] = newValue }
  }
}

extension DownloadClient: DependencyKey {
  public static let liveValue = Self(
    download: { request, showProgress in
      AsyncThrowingStream<Event, Error> (bufferingPolicy: .unbounded) { continuation in
        Task {
          do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            var data     = Data()
            var progress = 0
            for try await byte in bytes {
              data.append(byte)
              guard showProgress else { continue }
              let newProgress = Int( Double(data.count) / Double(response.expectedContentLength) * 100)
              if newProgress != progress {
                progress = newProgress
                continuation.yield(.updateProgress(Double(progress) / 100))
              }
            }
            continuation.yield(.response(data, response))
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

extension DownloadClient {
  public func download( _ url: URLRequest, showProgress: Bool = false ) -> AsyncThrowingStream<Event, Error> {
    self.download(url, showProgress)
  }
}
