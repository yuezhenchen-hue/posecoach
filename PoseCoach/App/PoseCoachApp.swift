import SwiftUI

@main
struct PoseCoachApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isOnboardingComplete: Bool {
        didSet { UserDefaults.standard.set(isOnboardingComplete, forKey: "isOnboardingComplete") }
    }
    @Published var guidanceLevel: GuidanceLevel {
        didSet { UserDefaults.standard.set(guidanceLevel.rawValue, forKey: "guidanceLevel") }
    }
    @Published var isVoiceEnabled: Bool {
        didSet { UserDefaults.standard.set(isVoiceEnabled, forKey: "isVoiceEnabled") }
    }
    @Published var selectedComposition: String {
        didSet { UserDefaults.standard.set(selectedComposition, forKey: "selectedComposition") }
    }
    @Published var isDemoMode: Bool = false

    init() {
        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
        self.isVoiceEnabled = UserDefaults.standard.object(forKey: "isVoiceEnabled") as? Bool ?? true
        self.selectedComposition = UserDefaults.standard.string(forKey: "selectedComposition") ?? "三分法"
        if let raw = UserDefaults.standard.string(forKey: "guidanceLevel"),
           let level = GuidanceLevel(rawValue: raw) {
            self.guidanceLevel = level
        } else {
            self.guidanceLevel = .beginner
        }
        #if targetEnvironment(simulator)
        isDemoMode = true
        #endif
    }
}

enum GuidanceLevel: String, CaseIterable, Identifiable {
    case beginner = "新手"
    case intermediate = "进阶"
    case advanced = "高级"

    var id: String { rawValue }
}
