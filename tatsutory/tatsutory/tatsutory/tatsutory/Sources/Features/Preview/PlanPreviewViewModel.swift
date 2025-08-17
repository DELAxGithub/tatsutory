import Foundation

@MainActor
class PlanPreviewViewModel: ObservableObject {
    @Published var selectedTasks: Set<String> = []
    @Published var isImporting = false
    @Published var importProgress = 0
    @Published var showingResult = false
    @Published var resultMessage = ""
    @Published var importSuccess = false
    
    private let remindersService = RemindersService()
    
    func selectAllTasks(from plan: Plan) {
        selectedTasks = Set(plan.tasks.map(\.id))
    }
    
    func toggleTask(_ taskId: String) {
        if selectedTasks.contains(taskId) {
            selectedTasks.remove(taskId)
        } else {
            selectedTasks.insert(taskId)
        }
    }
    
    func importSelectedTasks(from plan: Plan) async {
        isImporting = true
        importProgress = 0
        
        let tasksToImport = plan.tasks.filter { selectedTasks.contains($0.id) }
        
        do {
            let imported = try await remindersService.importTasks(tasksToImport, into: "TatsuTori Tasks")
            
            importSuccess = true
            resultMessage = "Successfully imported \(imported) tasks to Reminders!"
            showingResult = true
        } catch {
            importSuccess = false
            resultMessage = "Failed to import tasks: \(error.localizedDescription)"
            showingResult = true
        }
        
        isImporting = false
    }
}