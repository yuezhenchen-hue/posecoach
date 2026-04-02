@preconcurrency import AVFoundation
import UIKit
import Combine

/// 相机核心管理器：控制 AVCaptureSession、拍照、缩放、参数调整
class CameraManager: NSObject, ObservableObject {
    @MainActor @Published var isSessionRunning = false
    @MainActor @Published var capturedImage: UIImage?
    @MainActor @Published var cameraPosition: AVCaptureDevice.Position = .back
    @MainActor @Published var error: CameraError?

    // 参数状态
    @MainActor @Published var currentZoom: CGFloat = 1.0
    @MainActor @Published var minZoom: CGFloat = 1.0
    @MainActor @Published var maxZoom: CGFloat = 10.0
    @MainActor @Published var currentExposure: Float = 0.0
    @MainActor @Published var minExposure: Float = -2.0
    @MainActor @Published var maxExposure: Float = 2.0
    @MainActor @Published var currentISO: Float = 0
    @MainActor @Published var minISO: Float = 50
    @MainActor @Published var maxISO: Float = 1600
    @MainActor @Published var isAutoISO: Bool = true
    @MainActor @Published var isAutoWhiteBalance: Bool = true
    @MainActor @Published var whiteBalanceTemperature: Float = 5500
    @MainActor @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @MainActor @Published var isHDREnabled = false

    let session = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.posecoach.camera.session")

    nonisolated(unsafe) var videoFrameHandler: ((CMSampleBuffer) -> Void)?
    private var pinchStartZoom: CGFloat = 1.0

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
            Task { @MainActor in
                self.isSessionRunning = running
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            Task { @MainActor in
                self.isSessionRunning = false
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
            photoOutput.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024)
        }

        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.posecoach.camera.videodata"))
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            if let connection = videoDataOutput.connection(with: .video) {
                connection.videoRotationAngle = 90
            }
        }

        session.commitConfiguration()

        let device = videoDevice
        Task { @MainActor in
            self.minZoom = device.minAvailableVideoZoomFactor
            self.maxZoom = min(device.maxAvailableVideoZoomFactor, 15.0)
            self.currentZoom = device.videoZoomFactor
            self.minExposure = device.minExposureTargetBias
            self.maxExposure = device.maxExposureTargetBias
            self.minISO = device.activeFormat.minISO
            self.maxISO = device.activeFormat.maxISO
            self.currentISO = device.iso
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
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        settings.photoQualityPrioritization = .balanced
        photoOutput.capturePhoto(with: settings, delegate: self)
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

    @MainActor
    func beginPinchZoom() {
        pinchStartZoom = currentZoom
    }

    @MainActor
    func updatePinchZoom(scale: CGFloat) {
        setZoom(pinchStartZoom * scale)
    }

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

    // MARK: - ISO

    @MainActor
    func setISO(_ value: Float) {
        guard let device = videoDeviceInput?.device else { return }
        let clamped = max(device.activeFormat.minISO, min(value, device.activeFormat.maxISO))
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(
                duration: device.exposureDuration,
                iso: clamped
            )
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
        let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
            temperature: temperature, tint: 0
        )
        var gains = device.deviceWhiteBalanceGains(for: temperatureAndTint)
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

            if let currentInput = self.videoDeviceInput {
                self.session.removeInput(currentInput)
            }

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

    // MARK: - Apply Recommended Parameters

    @MainActor
    func applyParameters(_ params: CameraParameters) {
        if let exposure = params.exposureBias {
            setExposure(exposure)
        }
        flashMode = params.flashMode
        isHDREnabled = params.hdrEnabled
    }

    /// 一键还原所有参数
    @MainActor
    func resetAllParameters() {
        setZoom(1.0)
        setExposure(0)
        setAutoISO()
        setAutoWhiteBalance()
        flashMode = .off
        isHDREnabled = false
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        videoFrameHandler?(sampleBuffer)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let data = photo.fileDataRepresentation() else { return }

        Task { @MainActor [weak self] in
            guard let image = UIImage(data: data) else { return }
            self?.capturedImage = image
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
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
