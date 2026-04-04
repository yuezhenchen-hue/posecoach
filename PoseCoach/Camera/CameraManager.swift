@preconcurrency import AVFoundation
import UIKit
import Combine
import CoreImage
import Photos

/// 拍摄模式
enum ShootingMode: String, CaseIterable, Identifiable {
    case auto = "自动"
    case night = "夜景"
    case portrait = "人像"
    case manual = "专业"
    case video = "视频"
    case slowMotion = "慢动作"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .auto: return "camera.fill"
        case .night: return "moon.stars.fill"
        case .portrait: return "person.fill"
        case .manual: return "dial.medium.fill"
        case .video: return "video.fill"
        case .slowMotion: return "slowmo"
        }
    }
}

/// 拍照结果封装，用于安全传递给 SwiftUI sheet
struct CapturedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// 相机核心管理器
class CameraManager: NSObject, ObservableObject {
    @MainActor @Published var isSessionRunning = false
    @MainActor @Published var capturedPhoto: CapturedPhoto?
    @MainActor @Published var cameraPosition: AVCaptureDevice.Position = .back
    @MainActor @Published var error: CameraError?
    @MainActor @Published var shootingMode: ShootingMode = .auto
    @MainActor @Published var isCaptureInProgress = false

    @MainActor @Published var currentZoom: CGFloat = 1.0
    @MainActor @Published var minZoom: CGFloat = 1.0
    @MainActor @Published var maxZoom: CGFloat = 10.0

    @MainActor @Published var currentExposure: Float = 0.0
    @MainActor @Published var minExposure: Float = -2.0
    @MainActor @Published var maxExposure: Float = 2.0

    @MainActor @Published var currentISO: Float = 100
    @MainActor @Published var minISO: Float = 50
    @MainActor @Published var maxISO: Float = 1600
    @MainActor @Published var isAutoISO: Bool = true

    @MainActor @Published var currentShutterSpeed: Double = 1.0 / 60.0
    @MainActor @Published var isAutoShutter: Bool = true
    @MainActor @Published var shutterSpeedOptions: [Double] = [
        1.0/1000, 1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30, 1.0/15, 1.0/8, 1.0/4, 0.5, 1.0
    ]

    @MainActor @Published var isAutoWhiteBalance: Bool = true
    @MainActor @Published var whiteBalanceTemperature: Float = 5500

    @MainActor @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @MainActor @Published var isHDREnabled = false
    @MainActor @Published var isRAWEnabled = false
    @MainActor @Published var isRAWSupported = false

    @MainActor @Published var isRecording = false
    @MainActor @Published var recordingDuration: TimeInterval = 0
    @MainActor @Published var isStabilizationEnabled = true
    @MainActor @Published var isNightModeActive = false

    let session = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "com.posecoach.camera.session")

    nonisolated(unsafe) var videoFrameHandler: ((CMSampleBuffer) -> Void)?
    private var pinchStartZoom: CGFloat = 1.0
    private var recordingTimer: Timer?

    /// 根据设备物理方向返回 photoOutput connection 应设置的旋转角度
    @MainActor
    private func currentVideoRotationAngle() -> CGFloat {
        switch UIDevice.current.orientation {
        case .portrait:            return 90
        case .portraitUpsideDown:   return 270
        case .landscapeLeft:        return 0
        case .landscapeRight:       return 180
        default:                    return 90   // faceUp / faceDown / unknown → 默认竖屏
        }
    }

    // MARK: - Session Lifecycle

    func configure() {
        sessionQueue.async { [weak self] in self?.configureSession() }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            let running = self.session.isRunning
            DispatchQueue.main.async {
                self.isSessionRunning = running
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
            }
        }
    }

    // MARK: - Session Configuration

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let videoDevice = bestCamera(for: .back),
              let input = try? AVCaptureDeviceInput(device: videoDevice) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
            videoDeviceInput = input
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
            if let connection = photoOutput.connection(with: .video) {
                connection.videoRotationAngle = 90
            }
        }

        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.posecoach.camera.videodata"))
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            if let connection = videoDataOutput.connection(with: .video) {
                connection.videoRotationAngle = 90
            }
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            if let connection = movieOutput.connection(with: .video) {
                connection.videoRotationAngle = 90
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .cinematic
                }
            }
        }

        session.commitConfiguration()

        let device = videoDevice
        let rawSupported = !photoOutput.availableRawPhotoPixelFormatTypes.isEmpty

        DispatchQueue.main.async {
            self.minZoom = device.minAvailableVideoZoomFactor
            self.maxZoom = min(device.maxAvailableVideoZoomFactor, 15.0)
            self.currentZoom = device.videoZoomFactor
            self.minExposure = device.minExposureTargetBias
            self.maxExposure = device.maxExposureTargetBias
            self.minISO = device.activeFormat.minISO
            self.maxISO = device.activeFormat.maxISO
            self.currentISO = device.iso
            self.isRAWSupported = rawSupported
        }
    }

    private func bestCamera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTripleCamera],
            mediaType: .video, position: position
        ).devices.first
    }

    // MARK: - Capture Photo

    @MainActor
    func capturePhoto() {
        guard isSessionRunning, !isCaptureInProgress else { return }
        guard photoOutput.connection(with: .video) != nil else { return }

        isCaptureInProgress = true

        switch shootingMode {
        case .night:
            captureNightMode()
        default:
            captureStandard()
        }
    }

    @MainActor
    private func captureStandard() {
        // 1) 根据设备方向设置旋转角度
        if let connection = photoOutput.connection(with: .video) {
            connection.videoRotationAngle = currentVideoRotationAngle()
        }

        // 2) 配置 RAW / Processed 格式
        let settings: AVCapturePhotoSettings
        if isRAWEnabled,
           let rawType = photoOutput.availableRawPhotoPixelFormatTypes.first {
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(
                    rawPixelFormatType: rawType,
                    processedFormat: [AVVideoCodecKey: AVVideoCodecType.hevc]
                )
            } else {
                settings = AVCapturePhotoSettings(
                    rawPixelFormatType: rawType,
                    processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg]
                )
            }
        } else {
            settings = AVCapturePhotoSettings()
        }

        // 3) 最大分辨率
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions

        // 4) 闪光灯
        let supported = photoOutput.supportedFlashModes
        settings.flashMode = supported.contains(flashMode) ? flashMode : .off

        // 5) 始终最高质量
        settings.photoQualityPrioritization = .quality

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    @MainActor
    private func captureNightMode() {
        isNightModeActive = true

        if let connection = photoOutput.connection(with: .video) {
            connection.videoRotationAngle = currentVideoRotationAngle()
        }

        let settings = AVCapturePhotoSettings()
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        settings.photoQualityPrioritization = .quality
        settings.flashMode = .off

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Photo Saving

    /// 用原始 Data 直接保存到相册（保留全分辨率 + EXIF + 零损失）
    static func savePhotoDataToLibrary(_ data: Data, completion: ((Bool) -> Void)? = nil) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                let creation = PHAssetCreationRequest.forAsset()
                creation.addResource(with: .photo, data: data, options: nil)
            }) { success, _ in
                DispatchQueue.main.async { completion?(success) }
            }
        }
    }

    /// 保存 UIImage（仅用于 AI 处理后的增强图片）
    static func saveToPhotoLibrary(_ image: UIImage, completion: ((Bool) -> Void)? = nil) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, _ in
                DispatchQueue.main.async { completion?(success) }
            }
        }
    }

    static func saveDNGToPhotoLibrary(_ dngData: Data) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges({
                let creation = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = false
                creation.addResource(with: .photo, data: dngData, options: options)
            }) { _, _ in }
        }
    }

    // MARK: - Video Recording

    @MainActor
    func startRecording() {
        guard !isRecording else { return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        if let connection = movieOutput.connection(with: .video),
           isStabilizationEnabled && connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .cinematic
        }

        movieOutput.startRecording(to: tempURL, recordingDelegate: self)
        isRecording = true
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.recordingDuration += 0.1 }
        }
    }

    @MainActor
    func stopRecording() {
        guard isRecording else { return }
        movieOutput.stopRecording()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    @MainActor
    func configureSlowMotion() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if let format = device.formats.last(where: {
                    $0.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= 120 })
                }) {
                    device.activeFormat = format
                    device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 120)
                    device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 120)
                }
                device.unlockForConfiguration()
            } catch {}
        }
    }

    // MARK: - Zoom

    @MainActor
    func setZoom(_ factor: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        let clamped = max(minZoom, min(factor, maxZoom))
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            currentZoom = clamped
        } catch {}
    }

    @MainActor func beginPinchZoom() { pinchStartZoom = currentZoom }
    @MainActor func updatePinchZoom(scale: CGFloat) { setZoom(pinchStartZoom * scale) }

    // MARK: - Exposure

    @MainActor
    func setExposure(_ value: Float) {
        guard let device = videoDeviceInput?.device else { return }
        let clamped = max(device.minExposureTargetBias, min(value, device.maxExposureTargetBias))
        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(clamped)
            device.unlockForConfiguration()
            currentExposure = clamped
        } catch {}
    }

    // MARK: - Shutter Speed

    @MainActor
    func setShutterSpeed(_ duration: Double) {
        guard let device = videoDeviceInput?.device else { return }
        let cmTime = CMTime(seconds: duration, preferredTimescale: 1000000)
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: cmTime, iso: isAutoISO ? AVCaptureDevice.currentISO : currentISO)
            device.unlockForConfiguration()
            currentShutterSpeed = duration
            isAutoShutter = false
        } catch {}
    }

    @MainActor
    func setAutoExposure() {
        guard let device = videoDeviceInput?.device,
              device.isExposureModeSupported(.continuousAutoExposure) else { return }
        do {
            try device.lockForConfiguration()
            device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
            isAutoShutter = true
            isAutoISO = true
        } catch {}
    }

    // MARK: - ISO

    @MainActor
    func setISO(_ value: Float) {
        guard let device = videoDeviceInput?.device else { return }
        let clamped = max(device.activeFormat.minISO, min(value, device.activeFormat.maxISO))
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: device.exposureDuration, iso: clamped)
            device.unlockForConfiguration()
            currentISO = clamped
            isAutoISO = false
        } catch {}
    }

    @MainActor
    func setAutoISO() {
        guard let device = videoDeviceInput?.device,
              device.isExposureModeSupported(.continuousAutoExposure) else { return }
        do {
            try device.lockForConfiguration()
            device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
            isAutoISO = true
        } catch {}
    }

    // MARK: - White Balance

    @MainActor
    func setWhiteBalanceTemperature(_ temperature: Float) {
        guard let device = videoDeviceInput?.device else { return }
        let tv = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: temperature, tint: 0)
        var gains = device.deviceWhiteBalanceGains(for: tv)
        let maxGain = device.maxWhiteBalanceGain
        gains.redGain = max(1.0, min(gains.redGain, maxGain))
        gains.greenGain = max(1.0, min(gains.greenGain, maxGain))
        gains.blueGain = max(1.0, min(gains.blueGain, maxGain))
        do {
            try device.lockForConfiguration()
            device.setWhiteBalanceModeLocked(with: gains)
            device.unlockForConfiguration()
            whiteBalanceTemperature = temperature
            isAutoWhiteBalance = false
        } catch {}
    }

    @MainActor
    func setAutoWhiteBalance() {
        guard let device = videoDeviceInput?.device,
              device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) else { return }
        do {
            try device.lockForConfiguration()
            device.whiteBalanceMode = .continuousAutoWhiteBalance
            device.unlockForConfiguration()
            isAutoWhiteBalance = true
        } catch {}
    }

    // MARK: - Flash

    @MainActor
    func cycleFlashMode() {
        switch flashMode {
        case .off: flashMode = .auto
        case .auto: flashMode = .on
        case .on: flashMode = .off
        @unknown default: flashMode = .off
        }
    }

    // MARK: - Focus

    @MainActor
    func setFocusPoint(_ point: CGPoint) {
        guard let device = videoDeviceInput?.device,
              device.isFocusPointOfInterestSupported else { return }
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {}
    }

    // MARK: - Switch Camera

    @MainActor
    func switchCamera() {
        let newPosition: AVCaptureDevice.Position = (cameraPosition == .back) ? .front : .back
        cameraPosition = newPosition

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            if let currentInput = self.videoDeviceInput { self.session.removeInput(currentInput) }
            guard let newDevice = self.bestCamera(for: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                self.session.commitConfiguration()
                return
            }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.videoDeviceInput = newInput
            }
            self.session.commitConfiguration()

            let device = newDevice
            DispatchQueue.main.async {
                self.minZoom = device.minAvailableVideoZoomFactor
                self.maxZoom = min(device.maxAvailableVideoZoomFactor, 15.0)
                self.currentZoom = device.videoZoomFactor
                self.minISO = device.activeFormat.minISO
                self.maxISO = device.activeFormat.maxISO
                self.currentISO = device.iso
            }
        }
    }

    // MARK: - Apply / Reset

    @MainActor
    func applyParameters(_ params: CameraParameters) {
        if let exposure = params.exposureBias { setExposure(exposure) }
        flashMode = params.flashMode
        isHDREnabled = params.hdrEnabled
    }

    @MainActor
    func resetAllParameters() {
        setZoom(1.0)
        setExposure(0)
        setAutoExposure()
        setAutoWhiteBalance()
        flashMode = .off
        isHDREnabled = false
        isRAWEnabled = false
        shootingMode = .auto
    }

    static func shutterSpeedText(_ duration: Double) -> String {
        if duration >= 1.0 { return "\(Int(duration))s" }
        return "1/\(Int(round(1.0 / duration)))"
    }
}

// MARK: - Video Data Delegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        videoFrameHandler?(sampleBuffer)
    }
}

// MARK: - Photo Delegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if photo.isRawPhoto {
            if let rawData = photo.fileDataRepresentation() {
                CameraManager.saveDNGToPhotoLibrary(rawData)
            }
            return
        }
        guard error == nil else {
            DispatchQueue.main.async { self.isCaptureInProgress = false }
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            DispatchQueue.main.async { self.isCaptureInProgress = false }
            return
        }
        guard let image = UIImage(data: data) else {
            DispatchQueue.main.async { self.isCaptureInProgress = false }
            return
        }

        DispatchQueue.main.async {
            self.isCaptureInProgress = false
            self.isNightModeActive = false

            if self.shootingMode == .night {
                DispatchQueue.global(qos: .userInitiated).async {
                    let enhanced = ImageEnhancer.enhanceLowLight(image)
                    DispatchQueue.main.async {
                        self.capturedPhoto = CapturedPhoto(image: enhanced)
                        CameraManager.saveToPhotoLibrary(enhanced)
                    }
                }
            } else {
                self.capturedPhoto = CapturedPhoto(image: image)
                CameraManager.savePhotoDataToLibrary(data)
            }
        }
    }
}

// MARK: - Movie Recording Delegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        guard error == nil else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
            })
        }
    }
}

// MARK: - Error Types

enum CameraError: LocalizedError {
    case cameraUnavailable
    case permissionDenied
    case configurationFailed

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable: return "无法访问相机"
        case .permissionDenied: return "请在设置中允许访问相机"
        case .configurationFailed: return "相机配置失败"
        }
    }
}
