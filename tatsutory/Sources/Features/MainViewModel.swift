import SwiftUI
import UIKit
import Photos
import PhotosUI

@MainActor
class MainViewModel: ObservableObject {
    @Published var showingSettings = false
    @Published var showingCamera = false
    @Published var showingPhotoPicker = false
    @Published var showingPreview = false
    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var generatedPlan: PlanResult?
    @Published var showingConsentDialog = false
    @Published var consentMessage = ""
    @Published var capturedPhotoAssetID: String?

    private let intentStore = IntentSettingsStore.shared
    private let consentStore = ConsentStore.shared
    private let galleryService = PhotoGalleryService()
#if DEBUG
    @AppStorage("debug.useSamplePhoto") private var useSamplePhoto = true
#endif

    var hasAPIKey: Bool { !Secrets.load().isEmpty }
    
    func checkAPIKey() {
        if !hasAPIKey { showingSettings = true }
    }

    func handleTakePhotoTapped() {
#if DEBUG
        if useSamplePhoto {
            useSampleImage()
            return
        }
#endif
        if !consentStore.hasCompletedPrompt {
            consentMessage = L10n.string("main.consent_message")
            showingConsentDialog = true
        } else {
            showingCamera = true
        }
    }
    
    func recordConsent(_ allowed: Bool) {
        consentStore.hasConsentedToVisionUpload = allowed
        consentStore.hasCompletedPrompt = true
        intentStore.update { $0.llm.consent = allowed }
        showingConsentDialog = false
        showingCamera = true
        TelemetryTracker.shared.trackAISettingsSnapshot(
            featureEnabled: FeatureFlags.intentSettingsV1,
            consent: allowed,
            hasAPIKey: hasAPIKey,
            allowNetwork: FeatureFlags.intentSettingsV1 && hasAPIKey && allowed
        )
    }
    
    func handleCapturedImage(_ image: UIImage) {
        Task {
            // Save to gallery and get asset ID
            if galleryService.hasPermission() {
                do {
                    capturedPhotoAssetID = try await galleryService.saveToGallery(image)
                } catch {
                    print("Failed to save photo to gallery: \(error)")
                }
            }
            await generatePlan(from: image)
        }
    }

    func handlePickerImage(_ image: UIImage, assetID: String?) {
        // Photo from picker is already in gallery
        capturedPhotoAssetID = assetID
        Task { await generatePlan(from: image) }
    }

#if DEBUG
    func useSampleImage() {
        guard let url = Bundle.main.url(forResource: "IMG_0162", withExtension: "jpeg"),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            print("[Debug] Failed to load IMG_0162.jpeg from bundle")
            return
        }
        Task { await generatePlan(from: image) }
    }
#endif

    func generatePlan(from image: UIImage) async {
        isLoading = true

        let planner = TidyPlanner()
        let settings = intentStore.value
        let allowNetwork = FeatureFlags.intentSettingsV1 && hasAPIKey && settings.llm.consent

        generatedPlan = await planner.generate(
            from: image,
            allowNetwork: allowNetwork,
            photoAssetID: capturedPhotoAssetID
        ) { [weak self] message in
            self?.loadingMessage = message
        }

        showingPreview = true
        isLoading = false
        loadingMessage = ""
        capturedPhotoAssetID = nil  // Reset after use
        TelemetryTracker.shared.flushIfNeeded()
    }
    
    func handlePlanCompletion(success: Bool) {
        if success {
            generatedPlan = nil
            showingPreview = false
        }
    }
}
import SwiftUI
import PhotosUI
import Photos

// MARK: - Photo Picker

struct PhotoPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onPhotoPicked: (UIImage, String?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView

        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let result = results.first else { return }
            let assetID = result.assetIdentifier  // PHAsset local identifier if available
            let provider = result.itemProvider

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    if let error = error {
                        print("PhotoPicker: Failed to load image: \(error)")
                        return
                    }

                    if let image = image as? UIImage {
                        DispatchQueue.main.async {
                            self?.parent.onPhotoPicked(image, assetID)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Photo Gallery Service

class PhotoGalleryService {
    enum PhotoError: Error {
        case permissionDenied
        case saveFailed
        case assetNotFound
        case exportFailed
    }

    /// Save image to Photos gallery and return asset identifier
    func saveToGallery(_ image: UIImage) async throws -> String {
        // Request permission
        let status = await requestPermission()
        guard status == .authorized else {
            throw PhotoError.permissionDenied
        }

        // Save to gallery
        var assetID: String?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            assetID = request.placeholderForCreatedAsset?.localIdentifier
        }

        guard let id = assetID else {
            throw PhotoError.saveFailed
        }

        return id
    }

    /// Get temporary file URL for EKAttachment
    func getTemporaryFileURL(for assetID: String) async throws -> URL {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = assets.firstObject else {
            throw PhotoError.assetNotFound
        }

        return try await exportAssetToTemporaryFile(asset)
    }

    /// Export PHAsset to temporary file for reminder attachment
    private func exportAssetToTemporaryFile(_ asset: PHAsset) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, uti, orientation, info in
                guard let data = data else {
                    continuation.resume(throwing: PhotoError.exportFailed)
                    return
                }

                // Create temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let filename = "\(UUID().uuidString).jpg"
                let fileURL = tempDir.appendingPathComponent(filename)

                do {
                    try data.write(to: fileURL)
                    continuation.resume(returning: fileURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Request Photos library permission
    private func requestPermission() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        if currentStatus == .notDetermined {
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }

        return currentStatus
    }

    /// Check if permission is granted
    func hasPermission() -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized
    }
}
