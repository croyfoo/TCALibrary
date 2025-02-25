import Speech

// The core data types in the Speech framework are reference types and are not constructible by us,
// and so they aren't testable out the box. We define struct versions of those types to make
// them easier to use and test.

public struct SpeechRecognitionMetadataFoo: Equatable, Sendable {
  public var averagePauseDuration: TimeInterval
  public var speakingRate: Double
  public var voiceAnalytics: VoiceAnalyticsFoo?
}

@preconcurrency public struct SpeechRecognitionResultFoo: Equatable, Sendable {
  public var bestTranscription: TranscriptionFoo
  public var isFinal: Bool
  public var speechRecognitionMetadata: SpeechRecognitionMetadataFoo?
  public var transcriptions: [TranscriptionFoo]
}

public struct TranscriptionFoo: Equatable, Sendable {
  public var formattedString: String
  public var segments: [TranscriptionSegmentFoo]
}

public struct TranscriptionSegmentFoo: Equatable, Sendable {
  public var alternativeSubstrings: [String]
  public var confidence: Float
  public var duration: TimeInterval
  public var substring: String
  public var timestamp: TimeInterval
}

public struct VoiceAnalyticsFoo: Equatable, Sendable {
  public var jitter: AcousticFeatureFoo
  public var pitch: AcousticFeatureFoo
  public var shimmer: AcousticFeatureFoo
  public var voicing: AcousticFeatureFoo
}

public struct AcousticFeatureFoo: Equatable, Sendable {
  public var acousticFeatureValuePerFrame: [Double]
  public var frameDuration: TimeInterval
}

extension SpeechRecognitionMetadataFoo {
  init(_ speechRecognitionMetadata: SFSpeechRecognitionMetadata) {
    self.averagePauseDuration = speechRecognitionMetadata.averagePauseDuration
    self.speakingRate = speechRecognitionMetadata.speakingRate
    self.voiceAnalytics = speechRecognitionMetadata.voiceAnalytics.map(VoiceAnalyticsFoo.init)
  }
}

extension SpeechRecognitionResultFoo {
  init(_ speechRecognitionResult: SFSpeechRecognitionResult) {
    self.bestTranscription = TranscriptionFoo(speechRecognitionResult.bestTranscription)
    self.isFinal = speechRecognitionResult.isFinal
    self.speechRecognitionMetadata = speechRecognitionResult.speechRecognitionMetadata
      .map(SpeechRecognitionMetadataFoo.init)
    self.transcriptions = speechRecognitionResult.transcriptions.map(TranscriptionFoo.init)
  }
}

extension TranscriptionFoo {
  init(_ transcription: SFTranscription) {
    self.formattedString = transcription.formattedString
    self.segments = transcription.segments.map(TranscriptionSegmentFoo.init)
  }
}

extension TranscriptionSegmentFoo {
  init(_ transcriptionSegment: SFTranscriptionSegment) {
    self.alternativeSubstrings = transcriptionSegment.alternativeSubstrings
    self.confidence = transcriptionSegment.confidence
    self.duration = transcriptionSegment.duration
    self.substring = transcriptionSegment.substring
    self.timestamp = transcriptionSegment.timestamp
  }
}

extension VoiceAnalyticsFoo {
  init(_ voiceAnalytics: SFVoiceAnalytics) {
    self.jitter = AcousticFeatureFoo(voiceAnalytics.jitter)
    self.pitch = AcousticFeatureFoo(voiceAnalytics.pitch)
    self.shimmer = AcousticFeatureFoo(voiceAnalytics.shimmer)
    self.voicing = AcousticFeatureFoo(voiceAnalytics.voicing)
  }
}

extension AcousticFeatureFoo {
  init(_ acousticFeature: SFAcousticFeature) {
    self.acousticFeatureValuePerFrame = acousticFeature.acousticFeatureValuePerFrame
    self.frameDuration = acousticFeature.frameDuration
  }
}
