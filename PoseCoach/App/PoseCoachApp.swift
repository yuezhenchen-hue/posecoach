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
    @Published var guidanceLevel: GuidanceLevel = .beginner
    @Published var isVoiceEnabled: Bool = true

    init() {
        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
    }
}

enum GuidanceLevel: String, CaseIterable, Identifiable {
    case beginner = "新手"
    case intermediate = "进阶"
    case advanced = "高级"

    var id: String { rawValue }
}
