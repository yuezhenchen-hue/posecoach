import SwiftUI
import PhotosUI

/// 「照着拍」模式主视图
struct PhotoMatchEntryView: View {
    @StateObject private var analyzer = ReferencePhotoAnalyzer()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var referenceImage: UIImage?
    @State private var showAnalysis = false
    @State private var guides: [PhotoMatchGuide] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let image = referenceImage {
                    referenceImageView(image)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("照着拍")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAnalysis) {
                if let image = referenceImage {
                    PhotoMatchAnalysisSheet(
                        image: image,
                        guides: guides,
                        analyzer: analyzer
                    )
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.orange.opacity(0.6))

            VStack(spacing: 8) {
                Text("上传一张你想复刻的照片")
                    .font(.title2.bold())
                Text("AI 会分析照片中的场景、光线、构图和姿势\n然后实时指导你拍出一样的效果")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("从相册选择", systemImage: "photo.badge.plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
        .onChange(of: selectedPhoto) { _, newItem in
            loadImage(from: newItem)
        }
    }

    private func referenceImageView(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 8)
                .padding()

            if analyzer.isAnalyzing {
                ProgressView("正在分析照片...")
                    .padding()
            }

            HStack(spacing: 16) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("换一张", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.gray.opacity(0.15), in: Capsule())
                }

                Button {
                    showAnalysis = true
                } label: {
                    Label("查看分析", systemImage: "sparkle.magnifyingglass")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.orange, in: Capsule())
                }
                .disabled(guides.isEmpty)
            }

            Spacer()
        }
        .onChange(of: selectedPhoto) { _, newItem in
            loadImage(from: newItem)
        }
    }

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                referenceImage = image
                let _ = await analyzer.analyze(image: image)
                guides = analyzer.generateGuide()
            }
        }
    }
}

/// 分析结果详情页 — 含一键应用参数
struct PhotoMatchAnalysisSheet: View {
    let image: UIImage
    let guides: [PhotoMatchGuide]
    @ObservedObject var analyzer: ReferencePhotoAnalyzer
    @Environment(\.dismiss) private var dismiss
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 参考图 + 主体标注
                    ZStack(alignment: .bottomLeading) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        if let analysis = analyzer.analysis,
                           !analysis.poseDescription.isEmpty {
                            Text("主角: \(analysis.poseDescription)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.6), in: Capsule())
                                .padding(8)
                        }
                    }

                    // 分析结果卡片
                    ForEach(guides) { guide in
                        guideRow(guide)
                    }

                    // 相机参数详情卡片 + 一键应用
                    if let analysis = analyzer.analysis {
                        parameterActionCard(analysis)
                    }

                    // 开始拍摄按钮
                    Button {
                        showCamera = true
                    } label: {
                        Label("开始拍摄", systemImage: "camera.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.orange, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("拍摄方案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showCamera) {
                PhotoMatchCameraView(analyzer: analyzer)
            }
        }
    }

    private func parameterActionCard(_ analysis: ReferencePhotoAnalysis) -> some View {
        let params = ParameterRecommender.matchParameters(from: analysis)
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "camera.aperture")
                    .foregroundStyle(.orange)
                Text("推荐相机参数")
                    .font(.subheadline.bold())
                Spacer()
            }

            VStack(spacing: 8) {
                paramRow(icon: "sun.max.fill", name: "曝光补偿",
                         value: params.exposureBias.map { String(format: "%+.1f", $0) } ?? "0.0")
                paramRow(icon: "camera.filters", name: "HDR",
                         value: params.hdrEnabled ? "开启" : "关闭")
                paramRow(icon: "person.fill", name: "人像模式",
                         value: params.usePortraitMode ? "开启（背景虚化）" : "关闭")
                paramRow(icon: "bolt.fill", name: "闪光灯",
                         value: params.flashMode == .on ? "开启" : (params.flashMode == .auto ? "自动" : "关闭"))

                if analysis.isBacklit {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("检测到逆光，已自动提高曝光 +0.5")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }

            Text("进入拍摄后参数会根据当前实时光线自动微调")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func paramRow(icon: String, name: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 20)
            Text(name)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }

    private func guideRow(_ guide: PhotoMatchGuide) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: guide.icon)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(guide.title)
                    .font(.subheadline.bold())
                Text(guide.description)
                    .font(.subheadline)
                Text(guide.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// 照着拍模式下的相机视图 — 含一键应用/还原 + 实时光线对比
struct PhotoMatchCameraView: View {
    @ObservedObject var analyzer: ReferencePhotoAnalyzer
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var guideEngine = GuideEngine()
    @State private var overlayOpacity: Double = 0.3
    @State private var parametersApplied = false
    @State private var showParameterPanel = true
    @State private var savedDefaultParams = CameraParameters()

    var body: some View {
        ZStack {
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部状态栏
                topStatusBar
                Spacer()

                // 实时光线对比 + 参数建议
                if showParameterPanel {
                    liveParameterComparisonCard
                }

                // 底部控制栏
                bottomControlBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("照着拍")
        .onAppear {
            cameraManager.configure()
            cameraManager.startSession()

            cameraManager.videoFrameHandler = { buffer in
                guideEngine.processFrame(buffer)
            }

            applyReferenceParameters()
        }
        .onDisappear {
            cameraManager.stopSession()
            guideEngine.voiceCoach.stop()
        }
    }

    // MARK: - Top Status Bar

    private var topStatusBar: some View {
        HStack {
            // 参考图缩略
            if analyzer.analysis != nil {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 70)
                    .overlay {
                        VStack(spacing: 2) {
                            Image(systemName: "photo.fill")
                                .font(.caption)
                            Text("参考")
                                .font(.system(size: 8))
                        }
                        .foregroundStyle(.white)
                    }
            }

            Spacer()

            // 主体检测状态
            HStack(spacing: 6) {
                Circle()
                    .fill(guideEngine.poseDetector.personCount > 0 ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(guideEngine.poseDetector.mainSubjectDescription.isEmpty
                     ? "等待检测..." : guideEngine.poseDetector.mainSubjectDescription)
                    .font(.caption2.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            // 参数面板切换
            Button {
                withAnimation { showParameterPanel.toggle() }
            } label: {
                Image(systemName: showParameterPanel ? "slider.horizontal.3" : "slider.horizontal.3")
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Live Parameter Comparison Card

    private var liveParameterComparisonCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("参数对比")
                    .font(.caption.bold())
                Spacer()
                Text(parametersApplied ? "已应用参考参数" : "使用默认参数")
                    .font(.caption2)
                    .foregroundStyle(parametersApplied ? .green : .secondary)
            }

            // 当前实时光线 vs 参考图
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前环境")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(guideEngine.lightAnalyzer.lightCondition.description)
                        .font(.caption.bold())
                    Text("亮度 \(String(format: "%.0f%%", guideEngine.lightAnalyzer.brightness * 100))")
                        .font(.caption2)
                    Text(guideEngine.lightAnalyzer.colorTemperature.rawValue)
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.orange)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("参考图")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(analyzer.analysis?.isBacklit == true ? "逆光" : "顺光")
                        .font(.caption.bold())
                    if let exp = analyzer.analysis?.estimatedExposure {
                        Text("建议曝光 \(String(format: "%+.1f", exp))")
                            .font(.caption2)
                    }
                    Text(analyzer.analysis?.dominantColorTemperature.rawValue ?? "中性")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // 智能提示
            if let tip = generateLightComparisonTip() {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption2)
                    Text(tip)
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 4)
            }

            // 一键应用 / 一键还原 按钮
            HStack(spacing: 12) {
                Button {
                    applyReferenceParameters()
                } label: {
                    Label("一键应用", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(parametersApplied ? .gray : .orange, in: RoundedRectangle(cornerRadius: 8))
                }
                .disabled(parametersApplied)

                Button {
                    restoreDefaultParameters()
                } label: {
                    Label("一键还原", systemImage: "arrow.uturn.backward.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(parametersApplied ? .orange : .gray, in: RoundedRectangle(cornerRadius: 8))
                }
                .disabled(!parametersApplied)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Bottom Control Bar

    private var bottomControlBar: some View {
        HStack(spacing: 40) {
            // 构图提示
            VStack(spacing: 4) {
                Image(systemName: "squareshape.split.3x3")
                    .font(.title3)
                Text(analyzer.analysis?.compositionType.rawValue ?? "三分法")
                    .font(.caption2)
            }

            // 快门
            Button {
                cameraManager.capturePhoto()
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

    // MARK: - Parameter Actions

    private func applyReferenceParameters() {
        guard let analysis = analyzer.analysis else { return }
        var params = ParameterRecommender.matchParameters(from: analysis)

        // 根据当前实时光线动态微调
        let currentBrightness = guideEngine.lightAnalyzer.brightness
        let isCurrentlyDark = currentBrightness < 0.35
        let isCurrentlyBright = currentBrightness > 0.7

        if isCurrentlyDark && !(analysis.isBacklit) {
            params.exposureBias = (params.exposureBias ?? 0) + 0.3
            params.flashMode = .auto
        } else if isCurrentlyBright {
            params.exposureBias = (params.exposureBias ?? 0) - 0.2
        }

        if guideEngine.lightAnalyzer.isBacklit && !analysis.isBacklit {
            params.exposureBias = (params.exposureBias ?? 0) + 0.5
            params.hdrEnabled = true
        }

        cameraManager.applyParameters(params)
        parametersApplied = true
    }

    private func restoreDefaultParameters() {
        let defaults = CameraParameters()
        cameraManager.applyParameters(defaults)
        parametersApplied = false
    }

    private func generateLightComparisonTip() -> String? {
        guard let analysis = analyzer.analysis else { return nil }
        let current = guideEngine.lightAnalyzer

        if current.isBacklit && !analysis.isBacklit {
            return "当前逆光，参考图是顺光，建议转向避免逆光"
        }
        if !current.isBacklit && analysis.isBacklit {
            return "参考图是逆光效果，可以面朝光源拍摄"
        }
        if current.lightCondition.level == .veryDark || current.lightCondition.level == .dark {
            return "当前光线偏暗，已自动提高曝光补偿"
        }
        if current.colorTemperature != analysis.dominantColorTemperature {
            return "色温差异：当前\(current.colorTemperature.rawValue)，参考图\(analysis.dominantColorTemperature.rawValue)"
        }
        return nil
    }
}
