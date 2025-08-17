import SwiftUI

struct TaskListView: View {
    let plan: Plan
    let selectedTasks: Set<String>
    let onTaskToggle: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            taskList
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.project).font(.title2).fontWeight(.bold)
            Text("\(plan.locale.city), \(plan.locale.country)")
                .font(.subheadline).foregroundColor(.secondary)
            Text("\(selectedTasks.count) of \(plan.tasks.count) selected")
                .font(.caption).foregroundColor(.blue)
        }
        .padding(.horizontal)
    }
    
    private var taskList: some View {
        List {
            ForEach(plan.tasks) { task in
                TaskRowView(
                    task: task,
                    isSelected: selectedTasks.contains(task.id)
                ) { _ in onTaskToggle(task.id) }
            }
        }
    }
}

struct ImportingView: View {
    let progress: Int
    let total: Int
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.5)
            Text("Importing...").font(.headline)
            Text("\(progress) of \(total) completed")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}