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

/// 分析结果详情页
struct PhotoMatchAnalysisSheet: View {
    let image: UIImage
    let guides: [PhotoMatchGuide]
    @ObservedObject var analyzer: ReferencePhotoAnalyzer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    ForEach(guides) { guide in
                        guideRow(guide)
                    }

                    NavigationLink {
                        PhotoMatchCameraView(analyzer: analyzer)
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

/// 照着拍模式下的相机视图（分屏对比）
struct PhotoMatchCameraView: View {
    @ObservedObject var analyzer: ReferencePhotoAnalyzer
    @StateObject private var cameraManager = CameraManager()
    @State private var overlayOpacity: Double = 0.3

    var body: some View {
        ZStack {
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()

            // 参考图半透明叠层
            if let analysis = analyzer.analysis,
               let pose = analyzer.referencePose {
                VStack {
                    HStack {
                        // 左上角缩略参考图
                        if let _ = analyzer.analysis {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.black.opacity(0.3))
                                .frame(width: 100, height: 140)
                                .overlay {
                                    Text("参考图")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                }
                        }
                        Spacer()

                        // 匹配度指示器
                        VStack(spacing: 4) {
                            Text("匹配度")
                                .font(.caption2)
                            Text("--")
                                .font(.title2.bold())
                                .foregroundStyle(.orange)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding()

                    Spacer()

                    // 实时建议卡片
                    VStack(spacing: 8) {
                        Text("对齐参考图中的姿势")
                            .font(.subheadline.bold())
                        Text(analysis.poseDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Slider(value: $overlayOpacity, in: 0...0.8)
                            .tint(.orange)

                        Text("叠层透明度")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            cameraManager.configure()
            cameraManager.startSession()

            if let analysis = analyzer.analysis {
                let params = ParameterRecommender.matchParameters(from: analysis)
                cameraManager.applyParameters(params)
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
}
