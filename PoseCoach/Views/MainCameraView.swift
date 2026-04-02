import SwiftUI

/// 主拍照视图：整合相机预览、AI 引导覆层、底部控制栏
struct MainCameraView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var guideEngine = GuideEngine()
    @StateObject private var permissionManager = CameraPermissionManager()
    @State private var showSceneSelector = false
    @State private var showParameterPanel = false
    @State private var showHarmonyDetail = false
    @State private var showCapturedPhoto = false
    @State private var timerSeconds: Int = 0
    @State private var isCountingDown = false
    @State private var showZoomSlider = false

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
        .sheet(isPresented: $showHarmonyDetail) {
            if let harmony = guideEngine.compositionAnalyzer.harmonyScore {
                HarmonyDetailSheet(harmony: harmony)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Camera View

    private var cameraView: some View {
        ZStack {
            CameraPreview(
                session: cameraManager.session,
                onTapFocus: { point in
                    cameraManager.setFocusPoint(point)
                    guideEngine.setManualSubject(normalizedPoint: point)
                },
                onPinchBegan: {
                    cameraManager.beginPinchZoom()
                },
                onPinchChanged: { scale in
                    cameraManager.updatePinchZoom(scale: scale)
                    withAnimation { showZoomSlider = true }
                }
            )
            .ignoresSafeArea()

            CompositionOverlay(guide: guideEngine.compositionAnalyzer.selectedGuide)
            subjectHighlight

            VStack(spacing: 0) {
                topBar
                Spacer()

                if showZoomSlider {
                    zoomControl
                }

                guidePanel

                if showParameterPanel {
                    cameraParameterPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                bottomControls
            }

            if isCountingDown {
                Text("\(timerSeconds)")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }

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

    // MARK: - Subject Highlight

    private var subjectHighlight: some View {
        GeometryReader { geo in
            let box = guideEngine.subjectDetector.subjectBox
            let subjectType = guideEngine.subjectDetector.subjectType

            if box != .zero && subjectType != .none {
                let rect = CGRect(
                    x: box.minX * geo.size.width,
                    y: (1 - box.maxY) * geo.size.height,
                    width: box.width * geo.size.width,
                    height: box.height * geo.size.height
                )
                let color = highlightColor(for: subjectType)

                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                HStack(spacing: 4) {
                    Image(systemName: subjectType.icon)
                        .font(.system(size: 10))
                    Text(subjectType.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(color.opacity(0.8), in: Capsule())
                .position(x: rect.midX, y: rect.minY - 12)
            }
        }
        .allowsHitTesting(false)
    }

    private func highlightColor(for type: SubjectDetector.SubjectType) -> Color {
        switch type {
        case .person, .multiplePeople: return .green
        case .object: return .cyan
        case .scene: return .blue
        case .manualFocus: return .orange
        case .none: return .clear
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

            harmonyBadge

            Spacer()

            HStack(spacing: 12) {
                // 闪光灯
                Button {
                    cameraManager.cycleFlashMode()
                } label: {
                    Image(systemName: flashIcon)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }

                // 语音
                Button {
                    guideEngine.voiceCoach.isEnabled.toggle()
                } label: {
                    Image(systemName: guideEngine.voiceCoach.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var flashIcon: String {
        switch cameraManager.flashMode {
        case .off: return "bolt.slash.fill"
        case .auto: return "bolt.badge.automatic.fill"
        case .on: return "bolt.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }

    private var harmonyBadge: some View {
        Button { showHarmonyDetail = true } label: {
            HStack(spacing: 6) {
                if let harmony = guideEngine.compositionAnalyzer.harmonyScore {
                    Circle()
                        .fill(harmonyColor(harmony.level))
                        .frame(width: 10, height: 10)
                    Text("\(harmony.total)分")
                        .font(.caption.bold())
                    Text(harmony.level.rawValue)
                        .font(.system(size: 10))
                } else {
                    Circle()
                        .fill(readinessColor)
                        .frame(width: 10, height: 10)
                    Text(guideEngine.overallReadiness.rawValue)
                        .font(.caption.bold())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private func harmonyColor(_ level: CompositionAnalyzer.HarmonyScore.HarmonyLevel) -> Color {
        switch level {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }

    private var readinessColor: Color {
        switch guideEngine.overallReadiness {
        case .notReady: return .red
        case .almostReady: return .yellow
        case .ready: return .green
        case .perfect: return .blue
        }
    }

    // MARK: - Zoom Control

    private var zoomControl: some View {
        HStack(spacing: 12) {
            // 常用焦距快捷按钮
            ForEach([1.0, 2.0, 5.0], id: \.self) { factor in
                if factor <= cameraManager.maxZoom {
                    Button {
                        withAnimation { cameraManager.setZoom(factor) }
                    } label: {
                        Text(factor == 1.0 ? "1x" : "\(Int(factor))x")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isActiveZoom(factor) ? .black : .white)
                            .frame(width: 36, height: 36)
                            .background(isActiveZoom(factor) ? .orange : .white.opacity(0.2), in: Circle())
                    }
                }
            }

            // 缩放滑块
            Slider(
                value: Binding(
                    get: { cameraManager.currentZoom },
                    set: { cameraManager.setZoom($0) }
                ),
                in: cameraManager.minZoom...cameraManager.maxZoom
            )
            .tint(.orange)

            Text(String(format: "%.1fx", cameraManager.currentZoom))
                .font(.caption.bold())
                .foregroundStyle(.orange)
                .frame(width: 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 4)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showZoomSlider = false }
            }
        }
    }

    private func isActiveZoom(_ target: CGFloat) -> Bool {
        abs(cameraManager.currentZoom - target) < 0.3
    }

    // MARK: - Camera Parameter Panel

    private var cameraParameterPanel: some View {
        VStack(spacing: 12) {
            // 曝光
            parameterSlider(
                icon: "sun.max.fill",
                label: "曝光",
                value: Binding(
                    get: { cameraManager.currentExposure },
                    set: { cameraManager.setExposure($0) }
                ),
                range: cameraManager.minExposure...cameraManager.maxExposure,
                displayText: String(format: "%+.1f EV", cameraManager.currentExposure)
            )

            // ISO
            HStack(spacing: 8) {
                Image(systemName: "camera.aperture")
                    .foregroundStyle(.orange)
                    .frame(width: 22)
                Text("ISO")
                    .font(.caption)
                    .frame(width: 30, alignment: .leading)

                if cameraManager.isAutoISO {
                    Text("自动")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("手动") {
                        cameraManager.setISO(cameraManager.currentISO)
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.15), in: Capsule())
                } else {
                    Slider(
                        value: Binding(
                            get: { cameraManager.currentISO },
                            set: { cameraManager.setISO($0) }
                        ),
                        in: cameraManager.minISO...cameraManager.maxISO
                    )
                    .tint(.orange)
                    Text("\(Int(cameraManager.currentISO))")
                        .font(.caption.bold())
                        .frame(width: 44)
                    Button {
                        cameraManager.setAutoISO()
                    } label: {
                        Text("自动")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.orange, in: Capsule())
                    }
                }
            }

            // 白平衡
            HStack(spacing: 8) {
                Image(systemName: "thermometer.medium")
                    .foregroundStyle(.orange)
                    .frame(width: 22)
                Text("色温")
                    .font(.caption)
                    .frame(width: 30, alignment: .leading)

                if cameraManager.isAutoWhiteBalance {
                    Text("自动")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("手动") {
                        cameraManager.setWhiteBalanceTemperature(5500)
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.15), in: Capsule())
                } else {
                    Slider(
                        value: Binding(
                            get: { cameraManager.whiteBalanceTemperature },
                            set: { cameraManager.setWhiteBalanceTemperature($0) }
                        ),
                        in: 2000...10000
                    )
                    .tint(
                        LinearGradient(colors: [.blue, .white, .orange], startPoint: .leading, endPoint: .trailing)
                    )
                    Text("\(Int(cameraManager.whiteBalanceTemperature))K")
                        .font(.caption.bold())
                        .frame(width: 48)
                    Button {
                        cameraManager.setAutoWhiteBalance()
                    } label: {
                        Text("自动")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.orange, in: Capsule())
                    }
                }
            }

            // HDR + 一键AI推荐 + 还原
            HStack(spacing: 12) {
                Toggle(isOn: Binding(
                    get: { cameraManager.isHDREnabled },
                    set: { cameraManager.isHDREnabled = $0 }
                )) {
                    Label("HDR", systemImage: "camera.filters")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .tint(.orange)

                Spacer()

                Button {
                    let params = ParameterRecommender.recommend(
                        scene: guideEngine.sceneClassifier.currentScene,
                        lightAnalyzer: guideEngine.lightAnalyzer
                    )
                    cameraManager.applyParameters(params)
                } label: {
                    Label("AI推荐", systemImage: "wand.and.stars")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.orange, in: Capsule())
                }

                Button {
                    cameraManager.resetAllParameters()
                } label: {
                    Label("还原", systemImage: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.15), in: Capsule())
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private func parameterSlider(
        icon: String, label: String,
        value: Binding<Float>, range: ClosedRange<Float>,
        displayText: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 22)
            Text(label)
                .font(.caption)
                .frame(width: 30, alignment: .leading)
            Slider(value: value, in: range)
                .tint(.orange)
            Text(displayText)
                .font(.caption.bold())
                .frame(width: 52, alignment: .trailing)
        }
    }

    // MARK: - Phone Direction Overlay

    private var phoneDirectionOverlay: some View {
        ZStack {
            if let movement = guideEngine.phoneMovement {
                if movement.horizontal == .moveLeft {
                    directionArrow(systemName: "chevron.left", alignment: .leading)
                } else if movement.horizontal == .moveRight {
                    directionArrow(systemName: "chevron.right", alignment: .trailing)
                }
                if movement.vertical == .moveUp {
                    directionArrow(systemName: "chevron.up", alignment: .top)
                } else if movement.vertical == .moveDown {
                    directionArrow(systemName: "chevron.down", alignment: .bottom)
                }
                if movement.distance == .closer {
                    distancePill(text: "靠近", icon: "arrow.up.right.and.arrow.down.left")
                } else if movement.distance == .farther {
                    distancePill(text: "后退", icon: "arrow.down.left.and.arrow.up.right")
                }
            }
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.3), value: guideEngine.phoneMovement?.horizontal.rawValue)
        .animation(.easeInOut(duration: 0.3), value: guideEngine.phoneMovement?.vertical.rawValue)
    }

    private func directionArrow(systemName: String, alignment: Alignment) -> some View {
        GeometryReader { geo in
            Image(systemName: systemName)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.orange)
                .shadow(color: .black.opacity(0.4), radius: 4)
                .frame(width: geo.size.width, height: geo.size.height, alignment: alignment)
                .padding(alignment == .leading || alignment == .trailing ? 12 : 0)
                .padding(alignment == .top ? 80 : 0)
                .padding(alignment == .bottom ? 160 : 0)
                .opacity(0.9)
        }
    }

    private func distancePill(text: String, icon: String) -> some View {
        VStack {
            Spacer()
            Label(text, systemImage: icon)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.85), in: Capsule())
                .foregroundStyle(.white)
                .padding(.bottom, 160)
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
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
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

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 40) {
            // 参数面板
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showParameterPanel.toggle() }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: showParameterPanel ? "slider.horizontal.3" : "slider.horizontal.3")
                        .font(.title3)
                        .foregroundStyle(showParameterPanel ? .orange : .white)
                    Text("参数")
                        .font(.caption2)
                        .foregroundStyle(showParameterPanel ? .orange : .white)
                }
            }

            // 快门
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

            // 翻转
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

// MARK: - Harmony Detail Sheet

struct HarmonyDetailSheet: View {
    let harmony: CompositionAnalyzer.HarmonyScore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    totalScoreRing
                    ForEach(harmony.details) { detail in
                        detailRow(detail)
                    }
                }
                .padding()
            }
            .navigationTitle("构图协调性")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var totalScoreRing: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: CGFloat(harmony.total) / 100.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(harmony.total)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("/ 100")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(harmony.level.rawValue)
                .font(.headline)
                .foregroundStyle(scoreColor)
        }
        .padding(.vertical, 8)
    }

    private var scoreColor: Color {
        switch harmony.level {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }

    private func detailRow(_ detail: CompositionAnalyzer.HarmonyScore.HarmonyDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: detail.icon)
                    .foregroundStyle(.orange)
                    .frame(width: 24)
                Text(detail.name)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(detail.score)/\(detail.maxScore)")
                    .font(.subheadline.bold())
                    .foregroundStyle(detail.score >= detail.maxScore / 2 ? .green : .orange)
            }
            ProgressView(value: Double(detail.score), total: Double(detail.maxScore))
                .tint(detail.score >= detail.maxScore / 2 ? .green : .orange)
            if let suggestion = detail.suggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
