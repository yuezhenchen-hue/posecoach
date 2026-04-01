import SwiftUI

/// Demo 模式相机视图：用生成的场景图片模拟实时相机，展示 AI 分析结果
struct DemoCameraView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var demoProvider = DemoImageProvider()
    @StateObject private var guideEngine = GuideEngine()
    @State private var showSceneSelector = false
    @State private var showParameterPanel = false
    @State private var hasAnalyzed = false
    @State private var isAnalyzing = false
    @State private var showPhotoDetail = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Scene image
            Image(uiImage: demoProvider.currentScenario.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()

            // Composition overlay
            CompositionOverlay(guide: guideEngine.compositionAnalyzer.selectedGuide)

            VStack(spacing: 0) {
                demoBanner
                topBar
                Spacer()
                guidePanel
                scenarioSwitcher
                bottomControls
            }

            if isAnalyzing {
                ProgressView("AI 分析中...")
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .onAppear {
            analyzeCurrentScenario()
        }
        .onChange(of: demoProvider.currentScenarioIndex) { _, _ in
            analyzeCurrentScenario()
        }
        .sheet(isPresented: $showSceneSelector) {
            SceneSelectionView(
                selectedScene: guideEngine.sceneClassifier.currentScene,
                onSelect: { _ in showSceneSelector = false }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showPhotoDetail) {
            DemoPhotoDetailView(
                scenario: demoProvider.currentScenario,
                guideEngine: guideEngine
            )
        }
    }

    // MARK: - Demo Banner

    private var demoBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "play.rectangle.fill")
                .font(.caption2)
            Text("Demo 模式")
                .font(.caption2.bold())
            Text("·")
            Text("模拟器无摄像头，使用生成场景")
                .font(.caption2)
            Spacer()
            Button("切换真机") {
                appState.isDemoMode = false
            }
            .font(.caption2.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.85))
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { showSceneSelector = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: guideEngine.sceneClassifier.currentScene.icon)
                    Text(guideEngine.sceneClassifier.currentScene.displayName)
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(readinessColor)
                    .frame(width: 10, height: 10)
                Text(guideEngine.overallReadiness.rawValue)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Button {
                guideEngine.voiceCoach.isEnabled.toggle()
            } label: {
                Image(systemName: guideEngine.voiceCoach.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var readinessColor: Color {
        switch guideEngine.overallReadiness {
        case .notReady: return .red
        case .almostReady: return .yellow
        case .ready: return .green
        case .perfect: return .blue
        }
    }

    // MARK: - Guide Panel

    private var guidePanel: some View {
        VStack(spacing: 8) {
            ForEach(guideEngine.currentAdvices.prefix(3)) { advice in
                HStack(spacing: 8) {
                    Image(systemName: iconForCategory(advice.category))
                        .foregroundStyle(.orange)
                        .frame(width: 20)
                    Text(advice.message)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            if guideEngine.currentAdvices.isEmpty && hasAnalyzed {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    Text("场景分析完成，左右滑动切换不同场景")
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            if showParameterPanel {
                parameterCard
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var parameterCard: some View {
        let params = guideEngine.lightAnalyzer.recommendParameters()
        return VStack(spacing: 8) {
            ForEach(params.displayItems) { item in
                HStack {
                    Image(systemName: item.icon)
                        .foregroundStyle(.orange)
                    Text(item.name)
                        .font(.caption)
                    Spacer()
                    Text(item.value)
                        .font(.caption.bold())
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func iconForCategory(_ category: GuideEngine.GuideAdvice.Category) -> String {
        return category.defaultIcon
    }

    // MARK: - Scenario Switcher

    private var scenarioSwitcher: some View {
        HStack(spacing: 16) {
            ForEach(Array(demoProvider.scenarios.enumerated()), id: \.element.id) { index, scenario in
                Button {
                    withAnimation { demoProvider.currentScenarioIndex = index }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: scenario.icon)
                            .font(.body)
                            .frame(width: 36, height: 36)
                            .background(
                                index == demoProvider.currentScenarioIndex
                                ? AnyShapeStyle(.orange)
                                : AnyShapeStyle(.ultraThinMaterial)
                            )
                            .clipShape(Circle())
                        Text(scenario.name)
                            .font(.system(size: 9))
                            .lineLimit(1)
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 40) {
            Button {
                withAnimation { showParameterPanel.toggle() }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                    Text("参数")
                        .font(.caption2)
                }
            }

            Button {
                showPhotoDetail = true
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(.white)
                        .frame(width: 60, height: 60)
                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .foregroundStyle(.black)
                }
            }

            Button {
                withAnimation {
                    demoProvider.nextScenario()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3)
                    Text("换场景")
                        .font(.caption2)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.bottom, 30)
    }

    // MARK: - Analysis

    private func analyzeCurrentScenario() {
        isAnalyzing = true
        hasAnalyzed = false

        let scenario = demoProvider.currentScenario
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guideEngine.processImage(scenario.image, simulatedPersonBox: scenario.simulatedPersonBox)
            isAnalyzing = false
            hasAnalyzed = true
        }
    }
}

// MARK: - Demo Photo Detail

struct DemoPhotoDetailView: View {
    let scenario: DemoScenario
    @ObservedObject var guideEngine: GuideEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image(uiImage: scenario.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        )

                    // Scenario info
                    VStack(alignment: .leading, spacing: 8) {
                        Label(scenario.name, systemImage: scenario.icon)
                            .font(.headline)
                        Text(scenario.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    // AI Analysis Results
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI 分析结果")
                            .font(.headline)

                        analysisRow(icon: "map.fill", title: "场景识别",
                                    value: guideEngine.sceneClassifier.currentScene.displayName)

                        analysisRow(icon: "sun.max.fill", title: "光线条件",
                                    value: guideEngine.lightAnalyzer.lightCondition.description)

                        analysisRow(icon: "thermometer.medium", title: "色温",
                                    value: guideEngine.lightAnalyzer.colorTemperature.rawValue)

                        analysisRow(icon: "sun.min.fill", title: "亮度",
                                    value: String(format: "%.0f%%", guideEngine.lightAnalyzer.brightness * 100))

                        if guideEngine.lightAnalyzer.isBacklit {
                            analysisRow(icon: "exclamationmark.triangle.fill", title: "逆光",
                                        value: "检测到逆光", valueColor: .orange)
                        }

                        analysisRow(icon: "figure.stand", title: "人物检测",
                                    value: guideEngine.poseDetector.personCount > 0
                                    ? "检测到 \(guideEngine.poseDetector.personCount) 人" : "使用模拟数据")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    // Advices
                    if !guideEngine.currentAdvices.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("拍摄建议")
                                .font(.headline)

                            ForEach(guideEngine.currentAdvices) { advice in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                        .padding(.top, 2)
                                    Text(advice.message)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("拍摄分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func analysisRow(icon: String, title: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 2)
    }
}
