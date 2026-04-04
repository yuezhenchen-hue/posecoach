import SwiftUI

/// 设置视图
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    private var compositionBinding: Binding<CompositionAnalyzer.CompositionGuide> {
        Binding(
            get: {
                CompositionAnalyzer.CompositionGuide(rawValue: appState.selectedComposition) ?? .ruleOfThirds
            },
            set: {
                appState.selectedComposition = $0.rawValue
            }
        )
    }

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

                    guidanceLevelDescription
                }

                Section("构图参考线") {
                    Picker("默认构图线", selection: compositionBinding) {
                        ForEach(CompositionAnalyzer.CompositionGuide.allCases) { guide in
                            Text(guide.rawValue).tag(guide)
                        }
                    }
                }

                Section("开发调试") {
                    Toggle("Demo 模式", isOn: $appState.isDemoMode)
                    Text("Demo 模式使用生成的场景图片模拟相机，可在模拟器上测试 AI 分析功能")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link("隐私政策", destination: URL(string: "https://posecoach.app/privacy")!)
                    Link("使用条款", destination: URL(string: "https://posecoach.app/terms")!)
                }

                Section {
                    VStack(spacing: 8) {
                        Text("智拍指南")
                            .font(.headline)
                        Text("Smart Pose & Cam")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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

    private var guidanceLevelDescription: some View {
        let desc: String = {
            switch appState.guidanceLevel {
            case .beginner: return "显示最关键的 1-2 条建议，语音播报核心指导"
            case .intermediate: return "显示更多建议，语音播报重要提示"
            case .advanced: return "显示全部专业信息，减少语音干扰"
            }
        }()
        return Text(desc)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
