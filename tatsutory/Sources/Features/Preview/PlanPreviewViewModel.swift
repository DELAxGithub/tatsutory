import Foundation


@MainActor
class PlanPreviewViewModel: ObservableObject {
    @Published var selectedTasks: Set<String> = []
    @Published var isImporting = false
    @Published var importProgress = 0
    @Published var showingResult = false
    @Published var resultMessage = ""
    @Published var importSuccess = false
    @Published var planSource: PlanSource = .local
    
    private let remindersService = RemindersService()
    
    func selectAllTasks(from plan: Plan) {
        selectedTasks = Set(plan.tasks.map(\.id))
    }
    
    func clearAllTasks() {
        selectedTasks.removeAll()
        TelemetryTracker.shared.trackClearAll()
    }
    
    func toggleTask(_ taskId: String) {
        if selectedTasks.contains(taskId) {
            selectedTasks.remove(taskId)
            TelemetryTracker.shared.trackSelectionChange(taskId: taskId, enabled: false)
        } else {
            selectedTasks.insert(taskId)
            TelemetryTracker.shared.trackSelectionChange(taskId: taskId, enabled: true)
        }
    }
    
    func importSelectedTasks(from plan: Plan) async {
        isImporting = true
        importProgress = 0
        
        let tasksToImport = plan.tasks.filter { selectedTasks.contains($0.id) }
        
        do {
            let imported = try await remindersService.importTasks(tasksToImport, into: L10n.string("reminders.list_name"))
            
            importSuccess = true
            resultMessage = L10n.string("plan.import.success", imported)
            TelemetryTracker.shared.trackExportResult(success: true, taskCount: imported)
            HapticsManager.shared.success()
            showingResult = true
        } catch {
            importSuccess = false
            resultMessage = L10n.string("plan.import.failure", error.localizedDescription)
            TelemetryTracker.shared.trackExportResult(success: false, taskCount: tasksToImport.count, error: error)
            HapticsManager.shared.error()
            showingResult = true
        }
        
        isImporting = false
        TelemetryTracker.shared.flushIfNeeded()
    }
}
