import ComposableArchitecture
import Speech
import AVFAudio

@DependencyClient
public struct AudioRecorder: Sendable {
  public var finishTask: @Sendable () async -> Void
  public var requestAuthorization: @Sendable () async -> AVAudioApplication.recordPermission = {
    .undetermined
  }
  
  public var startTask: @Sendable (_ audioFileID: String?) async -> AsyncThrowingStream<Action, Error> = {
    _ in .finished()
  }
  
  public var configure: @Sendable (_ configuration: Configuration) async -> Void = { _ in }
  
  public var pause: @Sendable () async -> Void = { }
  public var resume: @Sendable () async throws -> Void = { }
  
  public struct Configuration: Equatable, Sendable {
    public var audioSettings: [String: any Sendable]
    public var category: AVAudioSession.Category
    public var mode: AVAudioSession.Mode
    public var options: AVAudioSession.CategoryOptions
    public var monitorMeters: Bool
    public var audioFilePath: URL
    
    public init(audioSettings: [String : any Sendable]? = nil, category: AVAudioSession.Category? = nil,
                mode: AVAudioSession.Mode? = nil, options: AVAudioSession.CategoryOptions? = nil,
                monitorMeters: Bool? = nil, audioFilePath: URL? = nil) {
      self.audioSettings = audioSettings ?? Self.defaultConfig.audioSettings
      self.category      = category ?? Self.defaultConfig.category
      self.mode          = mode ?? Self.defaultConfig.mode
      self.options       = options ?? Self.defaultConfig.options
      self.monitorMeters = monitorMeters ?? Self.defaultConfig.monitorMeters
      self.audioFilePath = audioFilePath ?? Self.defaultConfig.audioFilePath
    }
    
    public static let defaultConfig = Configuration(
      audioSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 1
        //        AVNumberOfChannelsKey: 1 as NSNumber
      ],
      category: .record,
      mode: .measurement,
      options: .duckOthers,
      monitorMeters: true,
      audioFilePath: URL.documentsDirectory.appendingPathComponent("recording.m4a")
    )
    
    public static func == (lhs: Configuration, rhs: Configuration) -> Bool {
      lhs.category      == rhs.category &&
      lhs.mode          == rhs.mode &&
      lhs.options       == rhs.options &&
      lhs.monitorMeters == rhs.monitorMeters &&
      NSDictionary(dictionary: lhs.audioSettings).isEqual(to: rhs.audioSettings)
    }
  }
  
  public enum RecorderError: Error {
    case engineStartFailure
    case invalidAudioSession
    case recordingFailure
    case recordingNotStarted
  }
  
  public enum Action: Equatable, Sendable {
    case paused
    case resumed
    case stopped(validAudio: Bool)
    case updatePowerLevel(Float, TimeInterval)
  }
}

extension AudioRecorder: TestDependencyKey {
  public static var previewValue: Self {
    let isRecording = LockIsolated(false)
    
    return Self(
      finishTask: { isRecording.setValue(false) },
      requestAuthorization: { .granted },
      startTask: { audioFileID in
        AsyncThrowingStream { continuation in
          isRecording.setValue(true)
          continuation.yield(.stopped(validAudio: true))
          continuation.finish()
        }
      },
      configure: { _ in },
      pause: { },
      resume: { }
    )
  }
  
  public static let testValue = Self(
    finishTask: { },
    requestAuthorization: { .granted },
    startTask: { _ in .finished() },
    configure: { _ in },
    pause: { },
    resume: { }
  )
}

extension DependencyValues {
  public var audioRecorder: AudioRecorder {
    get { self[AudioRecorder.self] }
    set { self[AudioRecorder.self] = newValue }
  }
}
