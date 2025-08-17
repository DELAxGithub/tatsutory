import SwiftUI

struct PlanPreviewView: View {
    let plan: Plan
    let onComplete: (Bool) -> Void
    
    @StateObject private var viewModel = PlanPreviewViewModel()
    
    var body: some View {
        NavigationView {
            content
                .navigationTitle("Review Tasks")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .onAppear { viewModel.selectAllTasks(from: plan) }
                .alert("Import Result", isPresented: $viewModel.showingResult) {
                    Button("OK") { 
                        if viewModel.importSuccess { onComplete(true) }
                    }
                } message: { Text(viewModel.resultMessage) }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isImporting {
            ImportingView(progress: viewModel.importProgress, total: viewModel.selectedTasks.count)
        } else {
            TaskListView(plan: plan, selectedTasks: viewModel.selectedTasks) { 
                viewModel.toggleTask($0) 
            }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { onComplete(false) }
                    .disabled(viewModel.isImporting)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Import") {
                    Task { await viewModel.importSelectedTasks(from: plan) }
                }
                .disabled(viewModel.selectedTasks.isEmpty || viewModel.isImporting)
            }
        }
    }
}