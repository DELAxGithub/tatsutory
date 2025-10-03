import SwiftUI
import AVFoundation

struct CameraView: View {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraSessionManager()
    @State private var isPermissionDenied = false
    @State private var isBusy = false
    
    var body: some View {
        ZStack {
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()
                .background(Color.black)
            overlay
        }
        .task {
            await prepareSession()
        }
        .onDisappear {
            cameraManager.stopRunning()
        }
        .onChange(of: cameraManager.lastError != nil) {
            isBusy = false
        }
        .alert(
            L10n.key("camera.error.title"),
            isPresented: Binding(
                get: { cameraManager.lastError != nil || isPermissionDenied },
                set: { newValue in
                    if !newValue {
                        cameraManager.lastError = nil
                        isPermissionDenied = false
                    }
                }
            )
        ) {
            Button(L10n.key("common.ok")) {
                cameraManager.lastError = nil
                isPermissionDenied = false
                dismiss()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var overlay: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                }
                .padding()
#if DEBUG
                Spacer()
                Button(action: triggerSampleImage) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding()
#else
                Spacer()
#endif
            }
            Spacer()
            captureButton
                .padding(.bottom, 32)
        }
    }
    
    private var captureButton: some View {
        Button {
            guard cameraManager.isConfigured else { return }
            guard !isBusy else { return }
            isBusy = true
            cameraManager.capturePhoto()
        } label: {
            Circle()
                .strokeBorder(Color.white, lineWidth: 4)
                .frame(width: 80, height: 80)
                .overlay(
                    Circle()
                        .fill(isBusy ? Color.gray.opacity(0.5) : .white)
                        .frame(width: 68, height: 68)
                )
                .shadow(radius: 4)
        }
        .disabled(!cameraManager.isConfigured)
        .padding()
    }
    
    private func prepareSession() async {
        do {
            try await cameraManager.checkPermissions()
            cameraManager.onImageCaptured = { image in
                isBusy = false
                guard image.size.width.isFinite,
                      image.size.height.isFinite,
                      image.size.width > 0,
                      image.size.height > 0 else {
                    return
                }
                let processed = image.compressed(quality: 0.6, maxSize: 1024)
                onImageCaptured(processed)
                dismiss()
            }
            cameraManager.configureIfNeeded()
            cameraManager.startRunning()
        } catch {
            isPermissionDenied = true
        }
    }

    private var alertMessage: String {
        if isPermissionDenied {
            return L10n.string("camera.error.permission_denied")
        }
        guard let error = cameraManager.lastError else {
            return L10n.string("camera.error.unknown")
        }
        if let cameraError = error as? CameraSessionManager.CameraError {
            switch cameraError {
            case .authorizationDenied:
                return L10n.string("camera.error.permission_denied")
            case .configurationFailed:
                return L10n.string("camera.error.configuration")
            case .captureFailed:
                return L10n.string("camera.error.capture_failed")
            }
        }
        return error.localizedDescription
    }

#if DEBUG
    private func triggerSampleImage() {
        guard let url = Bundle.main.url(forResource: "IMG_0162", withExtension: "jpeg"),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            print("[Debug] Failed to load IMG_0162.jpeg from bundle")
            return
        }
        onImageCaptured(image)
        dismiss()
    }
#endif
}

// MARK: - UIImage Helpers

extension UIImage {
    func compressed(quality: CGFloat, maxSize: CGFloat) -> UIImage {
        let size = self.size
        let ratio = min(maxSize / size.width, maxSize / size.height)
        if ratio >= 1 {
            guard let data = self.jpegData(compressionQuality: quality),
                  let image = UIImage(data: data) else { return self }
            return image
        }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        self.draw(in: CGRect(origin: .zero, size: newSize))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext(),
              let data = resizedImage.jpegData(compressionQuality: quality),
              let finalImage = UIImage(data: data) else { return self }
        return finalImage
    }
}
