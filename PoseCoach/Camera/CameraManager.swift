@preconcurrency import AVFoundation
import UIKit
import Combine
import CoreImage

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

/// 相机核心管理器：控制拍照、缩放、参数调整、夜景、RAW、视频
class CameraManager: NSObject, ObservableObject {
    @MainActor @Published var isSessionRunning = false
    @MainActor @Published var capturedImage: UIImage?
    @MainActor @Published var cameraPosition: AVCaptureDevice.Position = .back
    @MainActor @Published var error: CameraError?
    @MainActor @Published var shootingMode: ShootingMode = .auto

    // 缩放
    @MainActor @Published var currentZoom: CGFloat = 1.0
    @MainActor @Published var minZoom: CGFloat = 1.0
    @MainActor @Published var maxZoom: CGFloat = 10.0

    // 曝光
    @MainActor @Published var currentExposure: Float = 0.0
    @MainActor @Published var minExposure: Float = -2.0
    @MainActor @Published var maxExposure: Float = 2.0

    // ISO
    @MainActor @Published var currentISO: Float = 100
    @MainActor @Published var minISO: Float = 50
    @MainActor @Published var maxISO: Float = 1600
    @MainActor @Published var isAutoISO: Bool = true

    // 快门速度
    @MainActor @Published var currentShutterSpeed: Double = 1.0 / 60.0
    @MainActor @Published var isAutoShutter: Bool = true
    @MainActor @Published var shutterSpeedOptions: [Double] = [
        1.0/1000, 1.0/500, 1.0/250, 1.0/125, 1.0/60, 1.0/30, 1.0/15, 1.0/8, 1.0/4, 0.5, 1.0
    ]

    // 白平衡
    @MainActor @Published var isAutoWhiteBalance: Bool = true
    @MainActor @Published var whiteBalanceTemperature: Float = 5500

    // 闪光灯 & HDR
    @MainActor @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @MainActor @Published var isHDREnabled = false

    // RAW
    @MainActor @Published var isRAWEnabled = false
    @MainActor @Published var isRAWSupported = false

    // 视频
    @MainActor @Published var isRecording = false
    @MainActor @Published var recordingDuration: TimeInterval = 0
    @MainActor @Published var isStabilizationEnabled = true

    // 夜景模式
    @MainActor @Published var isNightModeActive = false
    @MainActor @Published var nightModeFrameCount: Int = 5

    let session = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "com.posecoach.camera.session")

    nonisolated(unsafe) var videoFrameHandler: ((CMSampleBuffer) -> Void)?
    private var pinchStartZoom: CGFloat = 1.0
    private var recordingTimer: Timer?

    // MARK: - Session Lifecycle

    func configure() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            let running = self.session.isRunning
            Task { @MainActor in self.isSessionRunning = running }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            Task { @MainActor in self.isSessionRunning = false }
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
            photoOutput.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024)
            photoOutput.isHighResolutionCaptureEnabled = true
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

        Task { @MainActor in
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
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTripleCamera],
            mediaType: .video,
            position: position
        )
        return discoverySession.devices.first
    }

    // MARK: - Capture Photo

    @MainActor
    func capturePhoto() {
        switch shootingMode {
        case .night:
            captureNightMode()
        default:
            captureStandard()
        }
    }

    @MainActor
    private func captureStandard() {
        if isRAWEnabled && isRAWSupported,
           let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first {
            let settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
            settings.flashMode = flashMode
            photoOutput.capturePhoto(with: settings, delegate: self)
        } else {
            let settings = AVCapturePhotoSettings()
            settings.flashMode = flashMode
            settings.photoQualityPrioritization = .quality
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    /// 夜景模式：多帧长曝合成（通过系统API + 高质量优先）
    @MainActor
    private func captureNightMode() {
        isNightModeActive = true
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.photoQualityPrioritization = .quality
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Video Recording

    @MainActor
    func startRecording() {
        guard !isRecording else { return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        if let connection = movieOutput.connection(with: .video) {
            if isStabilizationEnabled && connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .cinematic
            }
        }

        movieOutput.startRecording(to: tempURL, recordingDelegate: self)
        isRecording = true
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 0.1
            }
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

    // MARK: - Slow Motion

    @MainActor
    func configureSlowMotion() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if let format = device.formats.last(where: {
                    let ranges = $0.videoSupportedFrameRateRanges
                    return ranges.contains(where: { $0.maxFrameRate >= 120 })
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
            Task { @MainActor in
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

    /// 快门速度显示文本
    static func shutterSpeedText(_ duration: Double) -> String {
        if duration >= 1.0 { return "\(Int(duration))s" }
        let denominator = Int(round(1.0 / duration))
        return "1/\(denominator)"
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
        guard let data = photo.fileDataRepresentation() else { return }
        Task { @MainActor [weak self] in
            guard let image = UIImage(data: data) else { return }

            if self?.shootingMode == .night {
                let enhanced = ImageEnhancer.enhanceLowLight(image)
                self?.capturedImage = enhanced
                UIImageWriteToSavedPhotosAlbum(enhanced, nil, nil, nil)
                self?.isNightModeActive = false
            } else {
                self?.capturedImage = image
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        }
    }
}

// MARK: - Movie Recording Delegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        guard error == nil else { return }
        UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
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
