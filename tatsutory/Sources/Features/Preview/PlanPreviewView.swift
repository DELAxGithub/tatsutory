import SwiftUI

struct PlanPreviewView: View {
    let result: PlanResult
    let onComplete: (Bool) -> Void
    
    @StateObject private var viewModel = PlanPreviewViewModel()
    @State private var toastMessage: String?
    
    private var plan: Plan { result.plan }

    var body: some View {
        NavigationView {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .onAppear {
                    viewModel.selectAllTasks(from: plan)
                    viewModel.planSource = result.source
                    handleSourceChange(result.source)
                    if let notice = result.notice {
                        showToast(notice)
                    }
                    HapticsManager.shared.prepareIfNeeded()
                }
                .onChange(of: result.source) { _, newValue in
                    viewModel.planSource = newValue
                    handleSourceChange(newValue)
                }
                .alert(L10n.key("plan.alert.result_title"), isPresented: $viewModel.showingResult) {
                    Button(L10n.key("common.ok")) {
                        if viewModel.importSuccess { onComplete(true) }
                    }
                } message: { Text(viewModel.resultMessage) }
                .toolbar { sourceToolbar }
                .overlay(alignment: .top) {
                    if let toastMessage {
                        Text(toastMessage)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                            .padding(.top, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isImporting {
            ImportingView(progress: viewModel.importProgress, total: viewModel.selectedTasks.count)
        } else {
            TaskListView(
                plan: plan,
                selectedTasks: viewModel.selectedTasks,
                onTaskToggle: { viewModel.toggleTask($0) },
                onSelectAll: { viewModel.selectAllTasks(from: plan) },
                onClearAll: { viewModel.clearAllTasks() }
            )
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { onComplete(false) }) {
                    Text(L10n.key("plan.toolbar.cancel"))
                }
                    .disabled(viewModel.isImporting)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { Task { await viewModel.importSelectedTasks(from: plan) } }) {
                    Text(L10n.key("plan.toolbar.import"))
                }
                .disabled(viewModel.selectedTasks.isEmpty || viewModel.isImporting)
            }
        }
    }
    
    private var sourceToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 4) {
                Text(L10n.key("plan.toolbar.review"))
                    .font(.headline)
                sourceBadge
            }
        }
    }
    
    @ViewBuilder
    private var sourceBadge: some View {
        switch viewModel.planSource {
        case .local:
            Label(L10n.key("plan.source.local"), systemImage: "bolt.slash")
                .font(.caption2)
                .padding(6)
                .background(Color.gray.opacity(0.2))
                .clipShape(Capsule())
        case .openAI(let requestId):
            Label(L10n.string("plan.source.openai", displayId(requestId)), systemImage: "bolt.fill")
                .font(.caption2)
                .padding(6)
                .foregroundColor(.white)
                .background(Color.blue.opacity(0.8))
                .clipShape(Capsule())
        case .rateLimited:
            Label(L10n.key("plan.source.rate_limited"), systemImage: "exclamationmark.triangle")
                .font(.caption2)
                .padding(6)
                .background(Color.yellow.opacity(0.8))
                .clipShape(Capsule())
        }
    }
    
    private func displayId(_ id: String) -> String {
        if id.count > 8 {
            return String(id.suffix(8))
        }
        return id
    }
    
    private func handleSourceChange(_ source: PlanSource) {
        switch source {
        case .openAI:
            showToast(L10n.string("plan.toast.ai_applied"))
        case .rateLimited:
            showToast(L10n.string("plan.toast.rate_limited"))
        case .local:
            break
        }
    }
    
    private func showToast(_ text: String) {
        withAnimation {
            toastMessage = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                toastMessage = nil
            }
        }
    }
}
