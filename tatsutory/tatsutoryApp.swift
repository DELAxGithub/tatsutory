import SwiftUI

@main
struct TatsuToriApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(IntentSettingsStore.shared)
        }
    }
}

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                appIcon
                appInfo
                actionButton
                loadingView
                Spacer()
            }
            .padding()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.key("main.toolbar.settings")) { viewModel.showingSettings = true }
                }
            }
            .onAppear { viewModel.checkAPIKey() }
            .sheet(isPresented: $viewModel.showingSettings) {
                SettingsView()
                    .environmentObject(IntentSettingsStore.shared)
            }
            .sheet(isPresented: $viewModel.showingCamera) {
                CameraView { viewModel.handleCapturedImage($0) }
            }
            .sheet(isPresented: $viewModel.showingPhotoPicker) {
                PhotoPickerView { image, assetID in
                    viewModel.handlePickerImage(image, assetID: assetID)
                }
            }
            .sheet(isPresented: $viewModel.showingPreview) {
                if let result = viewModel.generatedPlan {
                    PlanPreviewView(result: result) { viewModel.handlePlanCompletion(success: $0) }
                }
            }
            .alert(L10n.key("main.alert.consent_title"), isPresented: $viewModel.showingConsentDialog) {
                Button(L10n.key("main.alert.allow")) {
                    viewModel.recordConsent(true)
                }
                Button(L10n.key("main.alert.deny"), role: .cancel) {
                    viewModel.recordConsent(false)
                }
            } message: {
                Text(viewModel.consentMessage)
            }
        }
    }
    
    private var appIcon: some View {
        Image(systemName: "camera.viewfinder")
            .font(.system(size: 80))
            .foregroundColor(.blue)
    }
    
    private var appInfo: some View {
        VStack(spacing: 8) {
            Text("TatsuTori").font(.largeTitle).fontWeight(.bold)
            Text(L10n.key("main.subtitle"))
                .font(.headline).foregroundColor(.secondary)
        }
    }
    
    private var actionButton: some View {
        VStack(spacing: 16) {
            Button(L10n.key("main.action.take_photo")) {
                viewModel.handleTakePhotoTapped()
            }
            .buttonStyle(.borderedProminent)
            .font(.title2)

            Button(L10n.key("main.action.choose_photo")) {
                viewModel.showingPhotoPicker = true
            }
            .buttonStyle(.bordered)
            .font(.title3)
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        if viewModel.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text(viewModel.loadingMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}
