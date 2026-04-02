import SwiftUI

/// 主拍照视图：整合相机预览、AI 引导覆层、底部控制栏
struct MainCameraView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var guideEngine = GuideEngine()
    @StateObject private var permissionManager = CameraPermissionManager()
    @StateObject private var motionManager = DeviceMotionManager()
    @State private var showSceneSelector = false
    @State private var showParameterPanel = false
    @State private var showHarmonyDetail = false
    @State private var showCapturedPhoto = false
    @State private var showZoomSlider = false
    @State private var showLevelIndicator = false
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
            if !appState.isDemoMode { permissionManager.checkPermissions() }
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
                HarmonyDetailSheet(harmony: harmony).presentationDetents([.medium])
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
                onPinchBegan: { cameraManager.beginPinchZoom() },
                onPinchChanged: { scale in
                    cameraManager.updatePinchZoom(scale: scale)
                    withAnimation { showZoomSlider = true }
                }
            )
            .ignoresSafeArea()

            CompositionOverlay(guide: guideEngine.compositionAnalyzer.selectedGuide)
            LevelIndicatorOverlay(motionManager: motionManager, isEnabled: showLevelIndicator)
            subjectHighlight

            VStack(spacing: 0) {
                topBar
                Spacer()

                if showZoomSlider { zoomControl }
                guidePanel

                if showParameterPanel {
                    cameraParameterPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                shootingModeBar
                bottomControls
            }

            if isCountingDown {
                Text("\(timerSeconds)")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }

            if cameraManager.isNightModeActive {
                VStack {
                    Spacer()
                    Label("夜景处理中...", systemImage: "moon.stars.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                }
            }

            phoneDirectionOverlay

            if cameraManager.isRecording {
                recordingOverlay
            }
        }
        .onAppear {
            cameraManager.configure()
            cameraManager.startSession()
            motionManager.start()
            cameraManager.videoFrameHandler = { buffer in guideEngine.processFrame(buffer) }
        }
        .onDisappear {
            cameraManager.stopSession()
            motionManager.stop()
            guideEngine.voiceCoach.stop()
        }
        .onChange(of: cameraManager.capturedImage) { _, newImage in
            if newImage != nil { showCapturedPhoto = true }
        }
    }

    // MARK: - Recording Overlay

    private var recordingOverlay: some View {
        VStack {
            HStack(spacing: 8) {
                Circle().fill(.red).frame(width: 10, height: 10)
                Text(formatDuration(cameraManager.recordingDuration))
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.black.opacity(0.6), in: Capsule())
            .padding(.top, 60)
            Spacer()
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Subject Highlight

    private var subjectHighlight: some View {
        GeometryReader { geo in
            let box = guideEngine.subjectDetector.subjectBox
            let st = guideEngine.subjectDetector.subjectType
            if box != .zero && st != .none {
                let rect = CGRect(
                    x: box.minX * geo.size.width,
                    y: (1 - box.maxY) * geo.size.height,
                    width: box.width * geo.size.width,
                    height: box.height * geo.size.height
                )
                let color = highlightColor(for: st)
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                HStack(spacing: 4) {
                    Image(systemName: st.icon).font(.system(size: 10))
                    Text(st.rawValue).font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
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
        HStack(spacing: 10) {
            Button { showSceneSelector = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: guideEngine.sceneClassifier.currentScene.icon)
                    Text(guideEngine.sceneClassifier.currentScene.displayName)
                        .font(.caption.bold())
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()
            harmonyBadge
            Spacer()

            HStack(spacing: 8) {
                Button { cameraManager.cycleFlashMode() } label: {
                    Image(systemName: flashIcon)
                        .padding(8).background(.ultraThinMaterial, in: Circle())
                }
                Button { withAnimation { showLevelIndicator.toggle() } } label: {
                    Image(systemName: "level.fill")
                        .foregroundStyle(showLevelIndicator ? .orange : .white)
                        .padding(8).background(.ultraThinMaterial, in: Circle())
                }
                Button { guideEngine.voiceCoach.isEnabled.toggle() } label: {
                    Image(systemName: guideEngine.voiceCoach.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .padding(8).background(.ultraThinMaterial, in: Circle())
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal).padding(.top, 8)
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
            HStack(spacing: 5) {
                if let h = guideEngine.compositionAnalyzer.harmonyScore {
                    Circle().fill(harmonyColor(h.level)).frame(width: 8, height: 8)
                    Text("\(h.total)分").font(.system(size: 11, weight: .bold))
                } else {
                    Circle().fill(readinessColor).frame(width: 8, height: 8)
                    Text(guideEngine.overallReadiness.rawValue).font(.system(size: 11, weight: .bold))
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private func harmonyColor(_ l: CompositionAnalyzer.HarmonyScore.HarmonyLevel) -> Color {
        switch l { case .excellent: return .green; case .good: return .blue; case .fair: return .orange; case .poor: return .red }
    }
    private var readinessColor: Color {
        switch guideEngine.overallReadiness { case .notReady: return .red; case .almostReady: return .yellow; case .ready: return .green; case .perfect: return .blue }
    }

    // MARK: - Zoom

    private var zoomControl: some View {
        HStack(spacing: 10) {
            ForEach([1.0, 2.0, 5.0], id: \.self) { f in
                if f <= cameraManager.maxZoom {
                    Button { withAnimation { cameraManager.setZoom(f) } } label: {
                        Text(f == 1.0 ? "1x" : "\(Int(f))x")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(abs(cameraManager.currentZoom - f) < 0.3 ? .black : .white)
                            .frame(width: 32, height: 32)
                            .background(abs(cameraManager.currentZoom - f) < 0.3 ? .orange : .white.opacity(0.2), in: Circle())
                    }
                }
            }
            Slider(value: Binding(get: { cameraManager.currentZoom }, set: { cameraManager.setZoom($0) }),
                   in: cameraManager.minZoom...cameraManager.maxZoom).tint(.orange)
            Text(String(format: "%.1fx", cameraManager.currentZoom))
                .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.orange).frame(width: 36)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal).padding(.bottom, 2)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { showZoomSlider = false } } }
    }

    // MARK: - Parameter Panel

    private var cameraParameterPanel: some View {
        VStack(spacing: 10) {
            // 曝光
            sliderRow(icon: "sun.max.fill", label: "曝光",
                      value: Binding(get: { cameraManager.currentExposure }, set: { cameraManager.setExposure($0) }),
                      range: cameraManager.minExposure...cameraManager.maxExposure,
                      text: String(format: "%+.1f", cameraManager.currentExposure))

            // ISO
            autoManualRow(icon: "camera.aperture", label: "ISO", isAuto: cameraManager.isAutoISO,
                          onManual: { cameraManager.setISO(cameraManager.currentISO) },
                          onAuto: { cameraManager.setAutoISO() }) {
                Slider(value: Binding(get: { cameraManager.currentISO }, set: { cameraManager.setISO($0) }),
                       in: cameraManager.minISO...cameraManager.maxISO).tint(.orange)
                Text("\(Int(cameraManager.currentISO))").font(.system(size: 11, weight: .bold, design: .monospaced)).frame(width: 40)
            }

            // 快门速度
            autoManualRow(icon: "timer", label: "快门", isAuto: cameraManager.isAutoShutter,
                          onManual: { cameraManager.setShutterSpeed(1.0/60) },
                          onAuto: { cameraManager.setAutoExposure() }) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(cameraManager.shutterSpeedOptions, id: \.self) { speed in
                            Button {
                                cameraManager.setShutterSpeed(speed)
                            } label: {
                                Text(CameraManager.shutterSpeedText(speed))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(abs(cameraManager.currentShutterSpeed - speed) < 0.001 ? .black : .white)
                                    .padding(.horizontal, 8).padding(.vertical, 5)
                                    .background(abs(cameraManager.currentShutterSpeed - speed) < 0.001 ? .orange : .white.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                }
            }

            // 白平衡
            autoManualRow(icon: "thermometer.medium", label: "色温", isAuto: cameraManager.isAutoWhiteBalance,
                          onManual: { cameraManager.setWhiteBalanceTemperature(5500) },
                          onAuto: { cameraManager.setAutoWhiteBalance() }) {
                Slider(value: Binding(get: { cameraManager.whiteBalanceTemperature }, set: { cameraManager.setWhiteBalanceTemperature($0) }),
                       in: 2000...10000)
                .tint(LinearGradient(colors: [.blue, .white, .orange], startPoint: .leading, endPoint: .trailing))
                Text("\(Int(cameraManager.whiteBalanceTemperature))K").font(.system(size: 10, weight: .bold, design: .monospaced)).frame(width: 44)
            }

            // 底部：HDR + RAW + AI推荐 + 还原
            HStack(spacing: 8) {
                togglePill("HDR", isOn: $cameraManager.isHDREnabled, icon: "camera.filters")

                if cameraManager.isRAWSupported {
                    togglePill("RAW", isOn: $cameraManager.isRAWEnabled, icon: "doc.fill")
                }

                Spacer()

                Button {
                    let p = ParameterRecommender.recommend(scene: guideEngine.sceneClassifier.currentScene, lightAnalyzer: guideEngine.lightAnalyzer)
                    cameraManager.applyParameters(p)
                } label: {
                    Label("AI推荐", systemImage: "wand.and.stars")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.orange, in: Capsule())
                }

                Button { cameraManager.resetAllParameters() } label: {
                    Label("还原", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(.white.opacity(0.12), in: Capsule())
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal).padding(.bottom, 2)
    }

    private func sliderRow(icon: String, label: String, value: Binding<Float>, range: ClosedRange<Float>, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.orange).frame(width: 20)
            Text(label).font(.system(size: 11)).frame(width: 28, alignment: .leading)
            Slider(value: value, in: range).tint(.orange)
            Text(text).font(.system(size: 11, weight: .bold, design: .monospaced)).frame(width: 44, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func autoManualRow<Content: View>(icon: String, label: String, isAuto: Bool,
                                               onManual: @escaping () -> Void, onAuto: @escaping () -> Void,
                                               @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.orange).frame(width: 20)
            Text(label).font(.system(size: 11)).frame(width: 28, alignment: .leading)
            if isAuto {
                Text("自动").font(.system(size: 11, weight: .bold)).foregroundStyle(.orange)
                Spacer()
                Button("手动") { onManual() }
                    .font(.system(size: 10)).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.white.opacity(0.12), in: Capsule())
            } else {
                content()
                Button { onAuto() } label: {
                    Text("自动").font(.system(size: 9)).foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 3)
                        .background(.orange, in: Capsule())
                }
            }
        }
    }

    private func togglePill(_ label: String, isOn: Binding<Bool>, icon: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(isOn.wrappedValue ? .black : .white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(isOn.wrappedValue ? .orange : .white.opacity(0.15), in: Capsule())
        }
    }

    // MARK: - Shooting Mode Bar

    private var shootingModeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(ShootingMode.allCases) { mode in
                    Button {
                        withAnimation { cameraManager.shootingMode = mode }
                        if mode == .slowMotion { cameraManager.configureSlowMotion() }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 14))
                            Text(mode.rawValue)
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(cameraManager.shootingMode == mode ? .orange : .white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        let isVideoMode = cameraManager.shootingMode == .video || cameraManager.shootingMode == .slowMotion

        return HStack(spacing: 40) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showParameterPanel.toggle() }
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "slider.horizontal.3").font(.title3)
                        .foregroundStyle(showParameterPanel ? .orange : .white)
                    Text("参数").font(.caption2)
                        .foregroundStyle(showParameterPanel ? .orange : .white)
                }
            }

            // 快门/录制按钮
            Button {
                if isVideoMode {
                    cameraManager.isRecording ? cameraManager.stopRecording() : cameraManager.startRecording()
                } else if timerSeconds > 0 {
                    startCountdown()
                } else {
                    cameraManager.capturePhoto()
                }
            } label: {
                ZStack {
                    if isVideoMode {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                        if cameraManager.isRecording {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.red)
                                .frame(width: 28, height: 28)
                        } else {
                            Circle()
                                .fill(.red)
                                .frame(width: 60, height: 60)
                        }
                    } else {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(.white)
                            .frame(width: 60, height: 60)
                    }
                }
            }

            Button { cameraManager.switchCamera() } label: {
                VStack(spacing: 3) {
                    Image(systemName: "camera.rotate.fill").font(.title3)
                    Text("翻转").font(.caption2)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.bottom, 24)
    }

    // MARK: - Phone Direction

    private var phoneDirectionOverlay: some View {
        ZStack {
            if let m = guideEngine.phoneMovement {
                if m.horizontal == .moveLeft { directionArrow(systemName: "chevron.left", alignment: .leading) }
                else if m.horizontal == .moveRight { directionArrow(systemName: "chevron.right", alignment: .trailing) }
                if m.vertical == .moveUp { directionArrow(systemName: "chevron.up", alignment: .top) }
                else if m.vertical == .moveDown { directionArrow(systemName: "chevron.down", alignment: .bottom) }
                if m.distance == .closer { distancePill(text: "靠近", icon: "arrow.up.right.and.arrow.down.left") }
                else if m.distance == .farther { distancePill(text: "后退", icon: "arrow.down.left.and.arrow.up.right") }
            }
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.3), value: guideEngine.phoneMovement?.horizontal.rawValue)
    }

    private func directionArrow(systemName: String, alignment: Alignment) -> some View {
        GeometryReader { geo in
            Image(systemName: systemName)
                .font(.system(size: 36, weight: .bold)).foregroundStyle(.orange)
                .shadow(color: .black.opacity(0.4), radius: 4)
                .frame(width: geo.size.width, height: geo.size.height, alignment: alignment)
                .padding(alignment == .leading || alignment == .trailing ? 10 : 0)
                .padding(alignment == .top ? 70 : 0)
                .padding(alignment == .bottom ? 200 : 0)
                .opacity(0.85)
        }
    }

    private func distancePill(text: String, icon: String) -> some View {
        VStack { Spacer()
            Label(text, systemImage: icon).font(.caption.bold())
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.orange.opacity(0.85), in: Capsule()).foregroundStyle(.white)
                .padding(.bottom, 200)
        }
    }

    // MARK: - Guide Panel

    private var guidePanel: some View {
        VStack(spacing: 4) {
            let priority = guideEngine.currentAdvices.filter { $0.priority >= 1 && $0.priority <= 4 }
            let other = guideEngine.currentAdvices.filter { $0.priority > 4 }
            ForEach(priority.prefix(2)) { a in adviceRow(a, highlight: true) }
            if let o = other.first { adviceRow(o, highlight: false) }
        }
        .padding(.horizontal).padding(.bottom, 2)
    }

    private func adviceRow(_ advice: GuideEngine.GuideAdvice, highlight: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: advice.icon).foregroundStyle(highlight ? .orange : .white.opacity(0.6)).frame(width: 20)
            if let d = advice.direction, d != .stay {
                Text(d.rawValue).font(.system(size: 14, weight: .bold)).foregroundStyle(.orange).frame(width: 18)
            }
            Text(advice.message).font(.system(size: 12)).foregroundStyle(.white).lineLimit(1)
            Spacer()
            Text(advice.category.rawValue).font(.system(size: 8)).foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 5).padding(.vertical, 2).background(.white.opacity(0.08), in: Capsule())
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(
            highlight ? AnyShapeStyle(.orange.opacity(0.12)) : AnyShapeStyle(.ultraThinMaterial),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    // MARK: - Permission

    private var permissionRequestView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill").font(.system(size: 60)).foregroundStyle(.orange.opacity(0.6))
            Text("需要相机权限").font(.title2.bold())
            Text("智拍指南需要访问你的相机\n来提供实时拍照指导")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("允许访问相机") { Task { await permissionManager.requestCameraPermission() } }
                .buttonStyle(.borderedProminent).tint(.orange)
        }.padding()
    }

    private func startCountdown() {
        isCountingDown = true
        var remaining = timerSeconds
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            remaining -= 1; timerSeconds = remaining
            if remaining <= 0 { timer.invalidate(); isCountingDown = false; cameraManager.capturePhoto() }
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
                    scoreRing
                    ForEach(harmony.details) { d in detailRow(d) }
                }.padding()
            }
            .navigationTitle("构图协调性").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
        }
    }

    private var scoreRing: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(.gray.opacity(0.2), lineWidth: 8).frame(width: 100, height: 100)
                Circle().trim(from: 0, to: CGFloat(harmony.total) / 100.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100).rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(harmony.total)").font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("/ 100").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(harmony.level.rawValue).font(.headline).foregroundStyle(scoreColor)
        }.padding(.vertical, 8)
    }

    private var scoreColor: Color {
        switch harmony.level { case .excellent: return .green; case .good: return .blue; case .fair: return .orange; case .poor: return .red }
    }

    private func detailRow(_ d: CompositionAnalyzer.HarmonyScore.HarmonyDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: d.icon).foregroundStyle(.orange).frame(width: 24)
                Text(d.name).font(.subheadline.bold())
                Spacer()
                Text("\(d.score)/\(d.maxScore)").font(.subheadline.bold())
                    .foregroundStyle(d.score >= d.maxScore / 2 ? .green : .orange)
            }
            ProgressView(value: Double(d.score), total: Double(d.maxScore))
                .tint(d.score >= d.maxScore / 2 ? .green : .orange)
            if let s = d.suggestion { Text(s).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(12).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct CapturedPhotoView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Image(uiImage: image).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16)).padding()

                HStack(spacing: 16) {
                    Button {
                        let enhanced = ImageEnhancer.autoEnhance(image)
                        UIImageWriteToSavedPhotosAlbum(enhanced, nil, nil, nil)
                    } label: {
                        Label("AI优化", systemImage: "wand.and.stars")
                            .font(.caption.bold())
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.orange, in: Capsule())
                            .foregroundStyle(.white)
                    }

                    Button {
                        let sr = ImageEnhancer.superResolution(image)
                        UIImageWriteToSavedPhotosAlbum(sr, nil, nil, nil)
                    } label: {
                        Label("超分辨率", systemImage: "magnifyingglass")
                            .font(.caption.bold())
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.blue, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }

                Text("已保存到相册").font(.subheadline).foregroundStyle(.secondary).padding(.top, 8)
            }
            .navigationTitle("拍摄完成").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}
