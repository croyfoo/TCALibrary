import ComposableArchitecture
import Speech
import AVFAudio

extension AudioRecorder: DependencyKey {
  public static var liveValue: Self {
    let recorder = Recorder()
    return Self(

      finishTask: {
        await recorder.finishTask()
      },

      requestAuthorization: {
        await recorder.requestAuthorization()
      },

      startTask: { configuration in
        return await recorder.startTask(configuration: configuration)
      },

      pause: {
        await recorder.pause()
      },
      resume: {
        try await recorder.resume()
      }
    )
  }
}

private actor Recorder {
  private(set) var validAudio = false
  
  var audioSession: AVAudioSession = .sharedInstance()
  var audioRecorder: AVAudioRecorder?
  var recorderContinuation: AsyncThrowingStream<AudioRecorder.Action, Error>.Continuation?
  var configuration: AudioRecorder.Configuration
  private var timerTask: Task<Void, Never>?
  var currentTime: TimeInterval = 0

  var samples: [Float] = []

  init() {
    self.configuration = AudioRecorder.Configuration.defaultConfig
  }
  
  func configure(_ configuration: AudioRecorder.Configuration) {
    self.configuration = configuration
  }
  
  func finishTask() {
    // Read current time for duration validation
    let duration = audioRecorder?.currentTime ?? 0.0

    // Ensure meters are updated after stopping
//    audioRecorder?.updateMeters()
    
    // Obtain current average and peak power levels
    let averagePower = audioRecorder?.averagePower(forChannel: 0) ?? -120.0
    let peakPower    = audioRecorder?.peakPower(forChannel: 0) ?? -120.0

    audioRecorder?.stop()
    
    // Define the thresholds (may need adjustment based on real-world testing)
    let minimumDuration: TimeInterval = 0.5
    let averagePowerThreshold: Float  = -50.0
    let peakPowerThreshold: Float     = -40.0
    
    // Determine if audio is valid based on duration and power levels
    validAudio = (duration >= minimumDuration) &&
    (averagePower > averagePowerThreshold || peakPower > peakPowerThreshold)
    
    // Send the stopped action with validation status
    recorderContinuation?.yield(.stopped(validAudio: validAudio))
    recorderContinuation?.finish()
    
    // Cancel the timer when finishing recording
    timerTask?.cancel()
    
    // Clean up invalid recordings
    if !validAudio {
      try? FileManager.default.removeItem(atPath: configuration.audioFilePath.path())
    }
  }
  
  func startTask(configuration: AudioRecorder.Configuration? = nil) async -> AsyncThrowingStream<AudioRecorder.Action, Error> {

    if let configuration {
      self.configure(configuration)
    }
    
    return AsyncThrowingStream { continuation in
      do {
        self.recorderContinuation = continuation
        try self.configureAudioSession()
        try self.setupAudioRecorder(continuation)
        
        // Start the power level update timer
        if self.configuration.monitorMeters {
          self.startPowerLevelTimer(continuation: continuation)
        }
      } catch {
        continuation.finish(throwing: error)
      }
    }
  }
  
  private func startPowerLevelTimer(continuation: AsyncThrowingStream<AudioRecorder.Action, Error>.Continuation) {
    // Cancel any existing timer before starting a new one
    timerTask?.cancel()
    
    timerTask = Task {
      while !Task.isCancelled, let audioRecorder {
        do {
          try await Task.sleep(for: .seconds(0.005))
          audioRecorder.updateMeters()
          currentTime = audioRecorder.currentTime
          if configuration.monitorMeters {
            let power            = audioRecorder.averagePower(forChannel: 0)
            let currentAmplitude = 1 - pow(10, power / 20)
            samples.append(currentAmplitude)
            continuation.yield(.updatePowerLevel(currentAmplitude, audioRecorder.currentTime))
          }
        } catch {
          break
        }
      }
    }
  }
  
  private func configureAudioSession() throws {
    do {
      try audioSession.setCategory( configuration.category, mode: configuration.mode,
                                    options: configuration.options )
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      throw AudioRecorder.RecorderError.invalidAudioSession
    }
  }
  
  private func setupAudioRecorder(_ continuation: AsyncThrowingStream<AudioRecorder.Action, Error>.Continuation) throws {
    do {
      let audioPath      = configuration.audioFilePath
      self.audioRecorder = try AVAudioRecorder( url: audioPath, settings: configuration.audioSettings )
      self.audioRecorder?.isMeteringEnabled = true
      
      // Capture the current timerTask in a local variable
      let currentTimerTask = self.timerTask
      continuation.onTermination = { [
        audioRecorder    = UncheckedSendable(audioRecorder),
        currentTimerTask = UncheckedSendable(currentTimerTask) ] _ in
        audioRecorder.wrappedValue?.stop()
        currentTimerTask.wrappedValue?.cancel()
      }
      
      guard self.audioRecorder?.prepareToRecord() == true,
            self.audioRecorder?.record() == true else {
        throw AudioRecorder.RecorderError.recordingFailure
      }
    } catch {
      throw AudioRecorder.RecorderError.engineStartFailure
    }
  }
  
  func requestAuthorization() async -> AVAudioApplication.recordPermission {
    await withCheckedContinuation { continuation in
      AVAudioApplication.requestRecordPermission { granted in
        continuation.resume(returning: granted ? .granted : .denied)
      }
    }
  }
  
  func pause() {
    audioRecorder?.pause()
    timerTask?.cancel()
    recorderContinuation?.yield(.paused)
  }
  
  func resume() async throws {
    guard audioRecorder?.isRecording ?? false else {
      throw AudioRecorder.RecorderError.recordingNotStarted
    }
    
    audioRecorder?.record()
    startPowerLevelTimer(continuation: recorderContinuation!)
    recorderContinuation?.yield(.resumed)
  }
}
