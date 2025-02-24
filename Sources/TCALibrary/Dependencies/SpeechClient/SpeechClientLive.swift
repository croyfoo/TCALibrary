import ComposableArchitecture
import Speech

extension SpeechClient: DependencyKey {
  public static var liveValue: Self {
    let speech = Speech()
    return Self (
      finishTask: {
        await speech.finishTask()
      },
      requestAuthorization: {
        await withCheckedContinuation { continuation in
          SFSpeechRecognizer.requestAuthorization { status in
            continuation.resume(returning: status)
          }
        }
      },
      startTask: { request, audioFilePath in
        let request = UncheckedSendable(request)
        let wrappedStream = await speech.startTask(request: request, audioFilePath: audioFilePath)
        return wrappedStream.wrappedValue
      }
    )
  }
}

private actor Speech {
  var audioFilePath: URL?
  //  var audioFilePath: URL?                       = nil
  var audioSession: AVAudioSession = .sharedInstance()
  var audioEngine: AVAudioEngine?               = nil
  var recognitionTask: SFSpeechRecognitionTask? = nil
  var recognitionContinuation: AsyncThrowingStream<SpeechRecognitionResult, any Error>.Continuation?
  
  private var audioFile: AVAudioFile?
  private var request: SFSpeechAudioBufferRecognitionRequest?
  
  func finishTask() {
    self.audioEngine?.stop()
    self.audioEngine?.inputNode.removeTap(onBus: 0)
    self.recognitionTask?.finish()
    self.recognitionContinuation?.finish()
    self.recognitionTask = nil
  }
  
  func startTask( request: UncheckedSendable<SFSpeechAudioBufferRecognitionRequest>,
                  audioFilePath: URL? = nil ) -> UncheckedSendable<AsyncThrowingStream<SpeechRecognitionResult, any Error>> {
    self.request = request.wrappedValue
    self.audioFilePath = audioFilePath
    
    let stream = AsyncThrowingStream { @Sendable continuation in
      Task { [self] in
        await handleContinuationSetup(continuation)
      }
    }
    
    return UncheckedSendable(stream)
  }
  
  private func handleContinuationSetup(_ continuation: AsyncThrowingStream<SpeechRecognitionResult, any Error>.Continuation) async {
    self.recognitionContinuation = continuation
    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      continuation.finish(throwing: SpeechClient.Failure.couldntConfigureAudioSession)
      return
    }
    
    self.audioEngine     = AVAudioEngine()
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    self.recognitionTask = speechRecognizer.recognitionTask(with: self.request!) { result, error in
      if let result {
        continuation.yield(UncheckedSendable(SpeechRecognitionResult(result)).wrappedValue)
      } else {
        continuation.finish(throwing: SpeechClient.Failure.taskError)
      }
    }
    
    // Setup termination handling
    continuation.onTermination = {
      [
        audioEngine = UncheckedSendable(audioEngine),
        recognitionTask = UncheckedSendable(recognitionTask)
      ] _ in
      audioEngine.wrappedValue?.stop()
      audioEngine.wrappedValue?.inputNode.removeTap(onBus: 0)
      recognitionTask.wrappedValue?.finish()
    }
    
    if let recordingFormat = self.audioEngine?.inputNode.outputFormat(forBus: 0), let audioFilePath {
      do {
        self.audioFile = try AVAudioFile(forWriting: audioFilePath, settings: recordingFormat.settings)
      } catch {
        // Handle error
      }
      
      self.audioEngine?.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
        do {
          try self.audioFile?.write(from: buffer)
        } catch {
          // Handle error
        }
        
        self.request?.append(buffer)
      }
    }
    
    do {
      try self.audioEngine?.start()
    } catch {
      continuation.finish(throwing: SpeechClient.Failure.couldntStartAudioEngine)
      return
    }
  }
  
  /// Audio settings for saving `.m4a` file
  private func getAudioSettings() -> [String: Any] {
    return [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: 8000,
      AVNumberOfChannelsKey: 1,
      AVEncoderBitRateKey: 16000,
      AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
    ]
  }
}
