import Speech

// The core data types in the Speech framework are reference types and are not constructible by us,
// and so they aren't testable out the box. We define struct versions of those types to make
// them easier to use and test.

public struct SpeechRecognitionMetadata: Equatable {
  public var averagePauseDuration: TimeInterval
  public var speakingRate: Double
  public var voiceAnalytics: VoiceAnalytics?
}

@preconcurrency public struct SpeechRecognitionResult: Equatable {
  public var bestTranscription: Transcription
  public var isFinal: Bool
  public var speechRecognitionMetadata: SpeechRecognitionMetadata?
  public var transcriptions: [Transcription]
}

public struct Transcription: Equatable {
  public var formattedString: String
  public var segments: [TranscriptionSegment]
}

public struct TranscriptionSegment: Equatable {
  public var alternativeSubstrings: [String]
  public var confidence: Float
  public var duration: TimeInterval
  public var substring: String
  public var timestamp: TimeInterval
}

public struct VoiceAnalytics: Equatable {
  public var jitter: AcousticFeature
  public var pitch: AcousticFeature
  public var shimmer: AcousticFeature
  public var voicing: AcousticFeature
}

public struct AcousticFeature: Equatable {
  public var acousticFeatureValuePerFrame: [Double]
  public var frameDuration: TimeInterval
}

extension SpeechRecognitionMetadata {
  init(_ speechRecognitionMetadata: SFSpeechRecognitionMetadata) {
    self.averagePauseDuration = speechRecognitionMetadata.averagePauseDuration
    self.speakingRate = speechRecognitionMetadata.speakingRate
    self.voiceAnalytics = speechRecognitionMetadata.voiceAnalytics.map(VoiceAnalytics.init)
  }
}

extension SpeechRecognitionResult {
  init(_ speechRecognitionResult: SFSpeechRecognitionResult) {
    self.bestTranscription = Transcription(speechRecognitionResult.bestTranscription)
    self.isFinal = speechRecognitionResult.isFinal
    self.speechRecognitionMetadata = speechRecognitionResult.speechRecognitionMetadata
      .map(SpeechRecognitionMetadata.init)
    self.transcriptions = speechRecognitionResult.transcriptions.map(Transcription.init)
  }
}

extension Transcription {
  init(_ transcription: SFTranscription) {
    self.formattedString = transcription.formattedString
    self.segments = transcription.segments.map(TranscriptionSegment.init)
  }
}

extension TranscriptionSegment {
  init(_ transcriptionSegment: SFTranscriptionSegment) {
    self.alternativeSubstrings = transcriptionSegment.alternativeSubstrings
    self.confidence = transcriptionSegment.confidence
    self.duration = transcriptionSegment.duration
    self.substring = transcriptionSegment.substring
    self.timestamp = transcriptionSegment.timestamp
  }
}

extension VoiceAnalytics {
  init(_ voiceAnalytics: SFVoiceAnalytics) {
    self.jitter = AcousticFeature(voiceAnalytics.jitter)
    self.pitch = AcousticFeature(voiceAnalytics.pitch)
    self.shimmer = AcousticFeature(voiceAnalytics.shimmer)
    self.voicing = AcousticFeature(voiceAnalytics.voicing)
  }
}

extension AcousticFeature {
  init(_ acousticFeature: SFAcousticFeature) {
    self.acousticFeatureValuePerFrame = acousticFeature.acousticFeatureValuePerFrame
    self.frameDuration = acousticFeature.frameDuration
  }
}
