import AVFoundation
import Photos

/// 统一管理相机和相册权限请求
@MainActor
class CameraPermissionManager: ObservableObject {
    @Published var cameraPermission: PermissionStatus = .notDetermined
    @Published var photoLibraryPermission: PermissionStatus = .notDetermined

    enum PermissionStatus {
        case notDetermined, authorized, denied
    }

    func checkPermissions() {
        checkCameraPermission()
        checkPhotoLibraryPermission()
    }

    func requestCameraPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraPermission = granted ? .authorized : .denied
    }

    func requestPhotoLibraryPermission() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        photoLibraryPermission = (status == .authorized || status == .limited) ? .authorized : .denied
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: cameraPermission = .authorized
        case .denied, .restricted: cameraPermission = .denied
        case .notDetermined: cameraPermission = .notDetermined
        @unknown default: cameraPermission = .notDetermined
        }
    }

    private func checkPhotoLibraryPermission() {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited: photoLibraryPermission = .authorized
        case .denied, .restricted: photoLibraryPermission = .denied
        case .notDetermined: photoLibraryPermission = .notDetermined
        @unknown default: photoLibraryPermission = .notDetermined
        }
    }
}
