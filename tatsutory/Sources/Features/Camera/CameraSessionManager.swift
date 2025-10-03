import AVFoundation
import UIKit
import SwiftUI

final class CameraSessionManager: NSObject, ObservableObject {
    enum CameraError: Error {
        case authorizationDenied
        case configurationFailed
        case captureFailed
    }
    
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.tatsutori.camera.session")
    private var pendingRecovery = false
    
    @Published private(set) var isConfigured = false
    @Published var lastError: Error?
    
    var onImageCaptured: ((UIImage) -> Void)?
    
    func checkPermissions() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { throw CameraError.authorizationDenied }
        default:
            throw CameraError.authorizationDenied
        }
    }
    
    func configureIfNeeded() {
        guard !isConfigured else { return }
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            
            do {
                try self.configureInputs()
                try self.configureOutputs()
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.isConfigured = true }
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.lastError = error }
            }
        }
    }
    
    private func configureInputs() throws {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        guard let device = discovery.devices.first else {
            throw CameraError.configurationFailed
        }
        assert(device.deviceType == .builtInWideAngleCamera, "Unexpected camera type: \(device.deviceType.rawValue)")
        #if DEBUG
        print("CAMERA DEVICE ID=\(device.uniqueID) type=\(device.deviceType.rawValue)")
        #endif
        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            throw CameraError.configurationFailed
        }
    }
    
    private func configureOutputs() throws {
        if photoOutput.isDepthDataDeliverySupported {
            photoOutput.isDepthDataDeliveryEnabled = false
        }
        if photoOutput.isPortraitEffectsMatteDeliverySupported {
            photoOutput.isPortraitEffectsMatteDeliveryEnabled = false
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        } else {
            throw CameraError.configurationFailed
        }
        if let connection = photoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                let portraitAngle: CGFloat = 90
                if connection.isVideoRotationAngleSupported(portraitAngle) {
                    connection.videoRotationAngle = portraitAngle
                }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
    }
    
    func startRunning() {
        sessionQueue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }
    
    func stopRunning() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }
    
    func capturePhoto() {
        sessionQueue.async {
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraSessionManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            DispatchQueue.main.async { self.lastError = error }
            scheduleRecovery()
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            DispatchQueue.main.async { self.lastError = CameraError.captureFailed }
            scheduleRecovery()
            return
        }
        DispatchQueue.main.async {
            self.onImageCaptured?(image)
        }
    }
}

private extension CameraSessionManager {
    func scheduleRecovery() {
        sessionQueue.async {
            guard !self.pendingRecovery else { return }
            self.pendingRecovery = true
            let delay = DispatchTime.now() + 1.0
            self.sessionQueue.asyncAfter(deadline: delay) {
                self.session.beginConfiguration()
                for input in self.session.inputs {
                    self.session.removeInput(input)
                }
                for output in self.session.outputs {
                    self.session.removeOutput(output)
                }
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.isConfigured = false
                }
                do {
                    self.session.beginConfiguration()
                    try self.configureInputs()
                    try self.configureOutputs()
                    self.session.commitConfiguration()
                    self.session.startRunning()
                    DispatchQueue.main.async {
                        self.isConfigured = true
                        self.pendingRecovery = false
                    }
                } catch {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        self.lastError = error
                        self.pendingRecovery = false
                    }
                }
            }
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewLayerView {
        let view = PreviewLayerView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewLayerView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

final class PreviewLayerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
