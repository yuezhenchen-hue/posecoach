import Foundation

enum AppConstants {
    static let appName = "PoseCoach"
    static let appDisplayName = "AI 摄影教练"
    static let appVersion = "1.0.0"
    static let bundleIdentifier = "com.posecoach.app"

    enum URLs {
        static let privacyPolicy = "https://posecoach.app/privacy"
        static let termsOfService = "https://posecoach.app/terms"
        static let support = "https://posecoach.app/support"
    }

    enum Camera {
        static let maxFrameAnalysisRate: TimeInterval = 0.2
        static let defaultTimerDuration = 3
        static let photoQuality: Float = 0.95
    }

    enum AI {
        static let poseConfidenceThreshold: Float = 0.3
        static let sceneClassificationInterval: TimeInterval = 1.0
        static let lightAnalysisInterval: TimeInterval = 0.5
    }
}
