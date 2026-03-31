import AVFoundation

/// 语音教练：将拍摄建议转为语音播报
@MainActor
class VoiceCoach: ObservableObject {
    @Published var isEnabled = true
    @Published var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpokenMessage: String = ""
    private var lastSpeakTime: Date = .distantPast
    private let minSpeakInterval: TimeInterval = 3.0

    init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// 播报一条建议（自动去重和限频）
    func speak(_ message: String, priority: Priority = .normal) {
        guard isEnabled else { return }

        let now = Date()
        let interval = priority == .high ? 1.0 : minSpeakInterval

        guard now.timeIntervalSince(lastSpeakTime) >= interval,
              message != lastSpokenMessage else { return }

        if synthesizer.isSpeaking && priority != .high {
            return
        }

        if priority == .high {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.05
        utterance.volume = 0.9

        synthesizer.speak(utterance)
        lastSpokenMessage = message
        lastSpeakTime = now
        isSpeaking = true

        Task {
            try? await Task.sleep(for: .seconds(Double(message.count) * 0.15 + 0.5))
            isSpeaking = false
        }
    }

    /// 播报一组建议（取最重要的一条）
    func speakAdvices(_ advices: [PoseAdvice]) {
        guard let primary = advices.first else { return }
        let priority: Priority = primary.type == .warning ? .high : .normal
        speak(primary.message, priority: priority)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    enum Priority {
        case normal, high
    }
}
