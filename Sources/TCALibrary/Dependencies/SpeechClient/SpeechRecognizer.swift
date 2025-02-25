import ComposableArchitecture
import Speech

@DependencyClient
public struct SpeechRecognizerBeta: Sendable {
  public var finishTask: @Sendable () async -> Void
  public var requestAuthorization: @Sendable () async -> SFSpeechRecognizerAuthorizationStatus = {
    .notDetermined
  }
  
  public var startTask: @Sendable (_ request: SFSpeechAudioBufferRecognitionRequest, _ audioFilePath: URL?) async -> AsyncThrowingStream<SpeechRecognitionResultFoo, Error> = { _,_ in .finished() }
  
  public enum Failure: Error, Equatable, Sendable {
    case taskError
    case couldntStartAudioEngine
    case couldntConfigureAudioSession
    case couldntConvertAudio
  }
}

extension SpeechRecognizerBeta: TestDependencyKey {
  public static var previewValue: Self {
    let isRecording = LockIsolated(false)
    
    return Self(
      finishTask: { isRecording.setValue(false) }, requestAuthorization: { .authorized },
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
                SpeechRecognitionResultFoo(bestTranscription: TranscriptionFoo( formattedString: text, segments: [] ),
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
  public var speechRecognizerBeta: SpeechRecognizerBeta {
    get { self[SpeechRecognizerBeta.self] }
    set { self[SpeechRecognizerBeta.self] = newValue }
  }
}
