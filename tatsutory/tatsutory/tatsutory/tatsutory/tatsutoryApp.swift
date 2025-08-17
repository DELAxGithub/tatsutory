import SwiftUI

@main
struct TatsuToriApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
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
                    Button("Settings") { viewModel.showingSettings = true }
                }
            }
            .onAppear { viewModel.checkAPIKey() }
            .sheet(isPresented: $viewModel.showingSettings) { SettingsView() }
            .sheet(isPresented: $viewModel.showingCamera) {
                CameraView { viewModel.handleCapturedImage($0) }
            }
            .sheet(isPresented: $viewModel.showingPreview) {
                if let plan = viewModel.generatedPlan {
                    PlanPreviewView(plan: plan) { viewModel.handlePlanCompletion(success: $0) }
                }
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
            Text("Moving-specific task maker")
                .font(.headline).foregroundColor(.secondary)
        }
    }
    
    private var actionButton: some View {
        Button("Take Photo") { viewModel.showingCamera = true }
            .buttonStyle(.borderedProminent)
            .font(.title2)
    }
    
    @ViewBuilder
    private var loadingView: some View {
        if viewModel.isLoading {
            ProgressView("AI analyzing...")
        }
    }
}
