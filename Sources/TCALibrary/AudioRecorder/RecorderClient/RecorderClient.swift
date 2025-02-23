import ComposableArchitecture
import Speech
import AVFAudio

@DependencyClient
struct RecorderClient {
  var finishTask: @Sendable () async -> Void
  var requestAuthorization: @Sendable () async -> AVAudioApplication.recordPermission = {
    .undetermined
  }
  
  var startTask: @Sendable (_ audioFileID: String?) async -> AsyncThrowingStream<Action, Error> = {
    _ in .finished()
  }
  
  var configure: @Sendable (_ configuration: Configuration) async -> Void = { _ in }
  
  struct Configuration: Equatable, Sendable {
    var audioSettings: [String: any Sendable]
    var category: AVAudioSession.Category
    var mode: AVAudioSession.Mode
    var options: AVAudioSession.CategoryOptions
    var monitorMeters: Bool
    var audioFilePath: URL
    
    init(audioSettings: [String : any Sendable]? = nil, category: AVAudioSession.Category? = nil,
         mode: AVAudioSession.Mode? = nil, options: AVAudioSession.CategoryOptions? = nil,
         monitorMeters: Bool? = nil, audioFilePath: URL? = nil) {
      self.audioSettings = audioSettings ?? Self.defaultConfig.audioSettings
      self.category      = category ?? Self.defaultConfig.category
      self.mode          = mode ?? Self.defaultConfig.mode
      self.options       = options ?? Self.defaultConfig.options
      self.monitorMeters = monitorMeters ?? Self.defaultConfig.monitorMeters
      self.audioFilePath = audioFilePath ?? Self.defaultConfig.audioFilePath
    }
    
    static let defaultConfig = Configuration(
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
    
    static func == (lhs: Configuration, rhs: Configuration) -> Bool {
      lhs.category      == rhs.category &&
      lhs.mode          == rhs.mode &&
      lhs.options       == rhs.options &&
      lhs.monitorMeters == rhs.monitorMeters &&
      NSDictionary(dictionary: lhs.audioSettings).isEqual(to: rhs.audioSettings)
    }
  }
  
  enum RecorderError: Error {
    case engineStartFailure
    case invalidAudioSession
    case recordingFailure
  }
  
  enum Action: Equatable {
    case stopped(validAudio: Bool)
    case updatePowerLevel(Float)
  }
}

extension RecorderClient: TestDependencyKey {
  static var previewValue: Self {
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
      configure: { _ in }
    )
  }
  
  static let testValue = Self()
}

extension DependencyValues {
  var recorderClient: RecorderClient {
    get { self[RecorderClient.self] }
    set { self[RecorderClient.self] = newValue }
  }
}
