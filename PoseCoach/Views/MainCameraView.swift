import SwiftUI

/// 主拍照视图：整合相机预览、AI 引导覆层、底部控制栏
struct MainCameraView: View {
    @EnvironmentObject var appState: AppState
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
            if appState.isDemoMode {
                DemoCameraView()
            } else if permissionManager.cameraPermission == .authorized {
                cameraView
            } else {
                permissionRequestView
            }
        }
        .onAppear {
            if !appState.isDemoMode {
                permissionManager.checkPermissions()
            }
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
            CameraPreview(session: cameraManager.session) { point in
                cameraManager.setFocusPoint(point)
            }
            .ignoresSafeArea()

            CompositionOverlay(guide: guideEngine.compositionAnalyzer.selectedGuide)

            VStack(spacing: 0) {
                topBar
                Spacer()
                guidePanel
                bottomControls
            }

            if isCountingDown {
                Text("\(timerSeconds)")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }

            // 手机移动方向指示器
            phoneDirectionOverlay
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

            readinessBadge

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

    private var readinessBadge: some View {
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
    }

    private var readinessColor: Color {
        switch guideEngine.overallReadiness {
        case .notReady: return .red
        case .almostReady: return .yellow
        case .ready: return .green
        case .perfect: return .blue
        }
    }

    // MARK: - Phone Direction Overlay

    /// 屏幕四周的方向箭头指示器
    private var phoneDirectionOverlay: some View {
        ZStack {
            if let movement = guideEngine.phoneMovement {
                // 左右箭头
                if movement.horizontal == .moveLeft {
                    directionArrow(systemName: "chevron.left", alignment: .leading)
                } else if movement.horizontal == .moveRight {
                    directionArrow(systemName: "chevron.right", alignment: .trailing)
                }
                // 上下箭头
                if movement.vertical == .moveUp {
                    directionArrow(systemName: "chevron.up", alignment: .top)
                } else if movement.vertical == .moveDown {
                    directionArrow(systemName: "chevron.down", alignment: .bottom)
                }
                // 远近提示
                if movement.distance == .closer {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Label("靠近", systemImage: "arrow.up.right.and.arrow.down.left")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.orange.opacity(0.85), in: Capsule())
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.bottom, 160)
                    }
                } else if movement.distance == .farther {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Label("后退", systemImage: "arrow.down.left.and.arrow.up.right")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.orange.opacity(0.85), in: Capsule())
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.bottom, 160)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.3), value: guideEngine.phoneMovement?.horizontal.rawValue)
        .animation(.easeInOut(duration: 0.3), value: guideEngine.phoneMovement?.vertical.rawValue)
    }

    private func directionArrow(systemName: String, alignment: Alignment) -> some View {
        GeometryReader { geo in
            let size: CGFloat = 40
            Image(systemName: systemName)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.orange)
                .shadow(color: .black.opacity(0.4), radius: 4)
                .frame(width: geo.size.width, height: geo.size.height, alignment: alignment)
                .padding(alignment == .leading || alignment == .trailing ? 12 : 0)
                .padding(alignment == .top ? 80 : 0)
                .padding(alignment == .bottom ? 160 : 0)
                .opacity(0.9)
        }
    }

    // MARK: - Guide Panel

    private var guidePanel: some View {
        VStack(spacing: 6) {
            let priorityAdvices = guideEngine.currentAdvices.filter { $0.priority >= 1 && $0.priority <= 4 }
            let otherAdvices = guideEngine.currentAdvices.filter { $0.priority > 4 }

            if !priorityAdvices.isEmpty {
                VStack(spacing: 4) {
                    ForEach(priorityAdvices.prefix(3)) { advice in
                        adviceRow(advice, highlight: true)
                    }
                }
            }

            if let topOther = otherAdvices.first {
                adviceRow(topOther, highlight: false)
            }

            if showParameterPanel {
                parameterCard
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func adviceRow(_ advice: GuideEngine.GuideAdvice, highlight: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: advice.icon)
                .foregroundStyle(highlight ? .orange : .white.opacity(0.7))
                .frame(width: 22)

            if let dir = advice.direction, dir != .stay {
                Text(dir.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.orange)
                    .frame(width: 20)
            }

            Text(advice.message)
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer()

            Text(advice.category.rawValue)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.white.opacity(0.1), in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            highlight
                ? AnyShapeStyle(.orange.opacity(0.15))
                : AnyShapeStyle(.ultraThinMaterial),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(highlight ? .orange.opacity(0.3) : .clear, lineWidth: 1)
        )
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

            Text("智拍指南需要访问你的相机\n来提供实时拍照指导")
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
