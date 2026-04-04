import SwiftUI
import Vision

/// 姿势模仿相机：相机画面叠加人物轮廓，实时对比姿态
struct PoseOverlayCameraView: View {
    let template: PoseTemplate
    let silhouetteImage: UIImage?
    let templateJoints: [VNHumanBodyPoseObservation.JointName: CGPoint]?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var poseTracker = LivePoseTracker()
    @State private var silhouetteOpacity: Double = 0.4
    @State private var comparison: PoseComparisonResult?
    @State private var showGuide = true

    var body: some View {
        ZStack {
            cameraLayer
            silhouetteOverlay
            poseSkeletonOverlay
            controlsOverlay
        }
        .onAppear {
            cameraManager.configure()
            cameraManager.startSession()
            cameraManager.videoFrameHandler = { [weak poseTracker] buffer in
                DispatchQueue.main.async {
                    poseTracker?.processFrame(buffer)
                }
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onChange(of: poseTracker.currentJoints) { _, newJoints in
            if let newJoints, let tJoints = templateJoints {
                comparison = SilhouetteExtractor.comparePoses(
                    templateJoints: tJoints, liveJoints: newJoints
                )
            }
        }
        .statusBarHidden()
    }

    // MARK: - Camera

    private var cameraLayer: some View {
        CameraPreview(session: cameraManager.session)
            .ignoresSafeArea()
    }

    // MARK: - Silhouette Overlay

    private var silhouetteOverlay: some View {
        GeometryReader { geo in
            if let sil = silhouetteImage {
                Image(uiImage: sil)
                    .resizable().scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(silhouetteOpacity)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Live Pose Skeleton

    private var poseSkeletonOverlay: some View {
        GeometryReader { geo in
            if let joints = poseTracker.currentJoints {
                Canvas { context, size in
                    drawSkeleton(
                        context: context, size: size,
                        joints: joints, color: skeletonColor
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var skeletonColor: Color {
        guard let c = comparison else { return .white }
        switch c.level {
        case .perfect: return .green
        case .good: return .blue
        case .fair: return .orange
        case .needsWork: return .red
        }
    }

    private func drawSkeleton(
        context: GraphicsContext, size: CGSize,
        joints: [VNHumanBodyPoseObservation.JointName: CGPoint],
        color: Color
    ) {
        let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
            (.nose, .neck),
            (.neck, .leftShoulder), (.neck, .rightShoulder),
            (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
            (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
            (.neck, .leftHip), (.neck, .rightHip),
            (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
            (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        ]

        func screenPoint(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let p = joints[name] else { return nil }
            return CGPoint(x: p.x * size.width, y: (1 - p.y) * size.height)
        }

        for (a, b) in connections {
            guard let pa = screenPoint(a), let pb = screenPoint(b) else { continue }
            var path = Path()
            path.move(to: pa)
            path.addLine(to: pb)
            context.stroke(path, with: .color(color.opacity(0.8)), lineWidth: 3)
        }

        for (_, point) in joints {
            let sp = CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
            let dot = CGRect(x: sp.x - 5, y: sp.y - 5, width: 10, height: 10)
            context.fill(Path(ellipseIn: dot), with: .color(color))
        }
    }

    // MARK: - Controls

    private var controlsOverlay: some View {
        VStack {
            topBar
            Spacer()

            if showGuide { guideHint }

            comparisonPanel
            bottomBar
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2).foregroundStyle(.white)
                    .shadow(radius: 4)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(template.name).font(.caption.bold())
                Text("对齐轮廓，摆出相同姿势").font(.system(size: 10))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Button { withAnimation { showGuide.toggle() } } label: {
                Image(systemName: showGuide ? "eye.fill" : "eye.slash.fill")
                    .font(.title3).foregroundStyle(.white)
                    .shadow(radius: 4)
            }
        }
        .padding(.horizontal).padding(.top, 8)
    }

    private var guideHint: some View {
        VStack(spacing: 4) {
            if let c = comparison {
                if !c.mismatchedParts.isEmpty {
                    Text("需要调整: \(c.mismatchedParts.prefix(3).joined(separator: "、"))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private var comparisonPanel: some View {
        HStack(spacing: 16) {
            if let c = comparison {
                HStack(spacing: 6) {
                    Circle().fill(matchColor(c.level)).frame(width: 10, height: 10)
                    Text("\(c.score)分").font(.system(size: 16, weight: .bold, design: .rounded))
                }

                Text(c.feedback)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("请站入画面中...").font(.system(size: 12))
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text("透明度").font(.system(size: 9)).foregroundStyle(.secondary)
                Slider(value: $silhouetteOpacity, in: 0...0.8)
                    .tint(.orange).frame(width: 80)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal).padding(.bottom, 4)
    }

    private var bottomBar: some View {
        HStack(spacing: 40) {
            Button { cameraManager.switchCamera() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "camera.rotate.fill").font(.title3)
                    Text("翻转").font(.caption2)
                }
            }

            Button { cameraManager.capturePhoto() } label: {
                ZStack {
                    Circle().strokeBorder(.white, lineWidth: 4).frame(width: 72, height: 72)
                    Circle().fill(.white).frame(width: 60, height: 60)

                    if let c = comparison, c.score >= 70 {
                        Image(systemName: "checkmark")
                            .font(.title2.bold()).foregroundStyle(.green)
                    }
                }
            }

            Button { withAnimation { showGuide.toggle() } } label: {
                VStack(spacing: 4) {
                    Image(systemName: showGuide ? "person.fill.viewfinder" : "person.fill")
                        .font(.title3)
                    Text(showGuide ? "隐藏" : "显示").font(.caption2)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.bottom, 30)
    }

    private func matchColor(_ level: PoseComparisonResult.MatchLevel) -> Color {
        switch level {
        case .perfect: return .green
        case .good: return .blue
        case .fair: return .orange
        case .needsWork: return .red
        }
    }
}

// MARK: - Live Pose Tracker

/// 实时追踪相机画面中的人体姿态
@MainActor
class LivePoseTracker: ObservableObject {
    @Published var currentJoints: [VNHumanBodyPoseObservation.JointName: CGPoint]?

    private var lastDetectionTime: Date = .distantPast
    private let detectionInterval: TimeInterval = 0.15

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastDetectionTime) >= detectionInterval else { return }
        lastDetectionTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])

        guard let pose = request.results?.first else {
            currentJoints = nil
            return
        }

        var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        let names: [VNHumanBodyPoseObservation.JointName] = [
            .nose, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]

        for name in names {
            if let point = try? pose.recognizedPoint(name), point.confidence > 0.3 {
                joints[name] = CGPoint(x: point.location.x, y: point.location.y)
            }
        }

        currentJoints = joints.isEmpty ? nil : joints
    }
}
