import SwiftUI

/// 设置视图
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var voiceCoach = VoiceCoach()
    @State private var selectedComposition: CompositionAnalyzer.CompositionGuide = .ruleOfThirds

    var body: some View {
        NavigationStack {
            Form {
                Section("语音引导") {
                    Toggle("语音播报", isOn: $appState.isVoiceEnabled)

                    Picker("引导级别", selection: $appState.guidanceLevel) {
                        ForEach(GuidanceLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }

                Section("构图参考线") {
                    Picker("默认构图线", selection: $selectedComposition) {
                        ForEach(CompositionAnalyzer.CompositionGuide.allCases) { guide in
                            Text(guide.rawValue).tag(guide)
                        }
                    }
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link("隐私政策", destination: URL(string: "https://posecoach.app/privacy")!)

                    Link("使用条款", destination: URL(string: "https://posecoach.app/terms")!)
                }

                Section {
                    VStack(spacing: 8) {
                        Text("PoseCoach")
                            .font(.headline)
                        Text("AI 摄影教练 · 让每个人都能拍出好照片")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("设置")
        }
    }
}
