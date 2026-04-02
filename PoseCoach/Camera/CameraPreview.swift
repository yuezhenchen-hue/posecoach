import SwiftUI
import AVFoundation

/// 相机实时预览视图 (UIViewRepresentable 桥接 AVCaptureVideoPreviewLayer)
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var onTapFocus: ((CGPoint) -> Void)?
    var onPinchBegan: (() -> Void)?
    var onPinchChanged: ((CGFloat) -> Void)?

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        view.onTapFocus = onTapFocus
        view.onPinchBegan = onPinchBegan
        view.onPinchChanged = onPinchChanged
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.onTapFocus = onTapFocus
        uiView.onPinchBegan = onPinchBegan
        uiView.onPinchChanged = onPinchChanged
    }
}

class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet { previewLayer.session = session }
    }
    var onTapFocus: ((CGPoint) -> Void)?
    var onPinchBegan: (() -> Void)?
    var onPinchChanged: ((CGFloat) -> Void)?

    private var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPreviewLayer()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPreviewLayer()
        setupGestures()
    }

    private func setupPreviewLayer() {
        previewLayer.videoGravity = .resizeAspectFill
    }

    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)

        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        addGestureRecognizer(pinchGesture)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        let point = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
        onTapFocus?(point)
        showFocusIndicator(at: location)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            onPinchBegan?()
        case .changed:
            onPinchChanged?(gesture.scale)
        default:
            break
        }
    }

    private func showFocusIndicator(at point: CGPoint) {
        let indicator = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        indicator.center = point
        indicator.layer.borderColor = UIColor.orange.cgColor
        indicator.layer.borderWidth = 2
        indicator.alpha = 0
        addSubview(indicator)

        UIView.animate(withDuration: 0.25, animations: {
            indicator.alpha = 1
            indicator.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: 0.5, options: [], animations: {
                indicator.alpha = 0
            }) { _ in
                indicator.removeFromSuperview()
            }
        }
    }
}
