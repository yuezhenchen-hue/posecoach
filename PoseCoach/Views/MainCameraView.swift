import SwiftUI

/// 主拍照视图：整合相机预览、AI 引导覆层、底部控制栏
struct MainCameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var guideEngine = GuideEngine()
    @StateObject private var permissionManager = CameraPermissionManager()
    @State private var showSceneSelector = false
    @State private var showParameterPanel = false
    @State private var showCapturedPhoto = false
    @State private var timerSeconds: Int = 0
    @State private var isCountingDown = false

    var body: some View {
        ZStack {
            if permissionManager.cameraPermission == .authorized {
                cameraView
            } else {
                permissionRequestView
            }
        }
        .onAppear {
            permissionManager.checkPermissions()
        }
        .sheet(isPresented: $showSceneSelector) {
            SceneSelectionView(
                selectedScene: guideEngine.sceneClassifier.currentScene,
                onSelect: { _ in showSceneSelector = false }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showCapturedPhoto) {
            if let image = cameraManager.capturedImage {
                CapturedPhotoView(image: image)
            }
        }
    }

    // MARK: - Camera View

    private var cameraView: some View {
        ZStack {
            // 相机预览层
            CameraPreview(session: cameraManager.session) { point in
                cameraManager.setFocusPoint(point)
            }
            .ignoresSafeArea()

            // 构图参考线
            CompositionOverlay(guide: guideEngine.compositionAnalyzer.selectedGuide)

            // 引导信息覆层
            VStack {
                topBar
                Spacer()
                guidePanel
                bottomControls
            }

            // 倒计时显示
            if isCountingDown {
                Text("\(timerSeconds)")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .onAppear {
            cameraManager.configure()
            cameraManager.startSession()
            cameraManager.videoFrameHandler = { buffer in
                guideEngine.processFrame(buffer)
            }
        }
        .onDisappear {
            cameraManager.stopSession()
            guideEngine.voiceCoach.stop()
        }
        .onChange(of: cameraManager.capturedImage) { _, newImage in
            if newImage != nil { showCapturedPhoto = true }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // 场景标签
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

            // 就绪度指示
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

            // 语音开关
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
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            // 参数推荐卡片
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

            Button {
                let params = ParameterRecommender.recommend(
                    scene: guideEngine.sceneClassifier.currentScene,
                    lightAnalyzer: guideEngine.lightAnalyzer
                )
                cameraManager.applyParameters(params)
            } label: {
                Text("一键应用推荐参数")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.orange, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func iconForCategory(_ category: GuideEngine.GuideAdvice.Category) -> String {
        switch category {
        case .scene: return "map.fill"
        case .light: return "sun.max.fill"
        case .composition: return "squareshape.split.3x3"
        case .pose: return "figure.stand"
        case .parameter: return "camera.aperture"
        case .creative: return "sparkles"
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 40) {
            // 参数面板切换
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

            // 快门按钮
            Button {
                if timerSeconds > 0 {
                    startCountdown()
                } else {
                    cameraManager.capturePhoto()
                }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(.white)
                        .frame(width: 60, height: 60)
                }
            }

            // 翻转相机
            Button {
                cameraManager.switchCamera()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "camera.rotate.fill")
                        .font(.title3)
                    Text("翻转")
                        .font(.caption2)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.bottom, 30)
    }

    // MARK: - Permission Request

    private var permissionRequestView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange.opacity(0.6))

            Text("需要相机权限")
                .font(.title2.bold())

            Text("PoseCoach 需要访问你的相机\n来提供实时拍照指导")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("允许访问相机") {
                Task { await permissionManager.requestCameraPermission() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
    }

    // MARK: - Timer

    private func startCountdown() {
        isCountingDown = true
        var remaining = timerSeconds
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            remaining -= 1
            timerSeconds = remaining
            if remaining <= 0 {
                timer.invalidate()
                isCountingDown = false
                cameraManager.capturePhoto()
            }
        }
    }
}

/// 拍摄完成后展示照片
struct CapturedPhotoView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding()

                Text("已保存到相册")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("拍摄完成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
