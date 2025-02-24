import ComposableArchitecture
import Speech

@DependencyClient
public struct SpeechClient: Sendable {
  var finishTask: @Sendable () async -> Void
  var requestAuthorization: @Sendable () async -> SFSpeechRecognizerAuthorizationStatus = {
    .notDetermined
  }
  
  var startTask:
  @Sendable (_ request: SFSpeechAudioBufferRecognitionRequest, _ audioFilePath: URL?) async -> AsyncThrowingStream<SpeechRecognitionResult, Error> = { _,_ in .finished() }
  
  enum Failure: Error, Equatable, Sendable {
    case taskError
    case couldntStartAudioEngine
    case couldntConfigureAudioSession
    case couldntConvertAudio
  }
}

extension SpeechClient: TestDependencyKey {
  public static var previewValue: Self {
    let isRecording = LockIsolated(false)
    
    return Self( finishTask: { isRecording.setValue(false) }, requestAuthorization: { .authorized },
                 startTask: { _,_ in
      AsyncThrowingStream { continuation in
        Task {
          isRecording.setValue(true)
          var finalText = """
              Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor 
              incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud 
              exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute 
              irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla 
              pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui 
              officia deserunt mollit anim id est laborum.
              """
          var text = ""
          while isRecording.value {
            let word = finalText.prefix { $0 != " " }
            try await Task.sleep(for: .milliseconds(word.count * 50 + .random(in: 0...200)))
            finalText.removeFirst(word.count)
            if finalText.first == " " {
              finalText.removeFirst()
            }
            text += word + " "
            continuation.yield(
              SpeechRecognitionResult( bestTranscription: Transcription( formattedString: text, segments: [] ),
                                       isFinal: false,
                                       transcriptions: []
                                     )
            )
          }
        }
      }
    }
    )
  }
  
  public static let testValue = Self()
}

extension DependencyValues {
  public var speechClient: SpeechClient {
    get { self[SpeechClient.self] }
    set { self[SpeechClient.self] = newValue }
  }
}
