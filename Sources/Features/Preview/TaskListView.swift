import SwiftUI

struct TaskListView: View {
    let plan: Plan
    let selectedTasks: Set<String>
    let onTaskToggle: (String) -> Void
    let onSelectAll: () -> Void
    let onClearAll: () -> Void
    
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
            HStack {
                Text("\(selectedTasks.count) of \(plan.tasks.count) selected")
                    .font(.caption).foregroundColor(.blue)
                Spacer()
                Button("Clear All") { onClearAll() }
                    .font(.caption)
                    .buttonStyle(.borderless)
                Button("Select All") { onSelectAll() }
                    .font(.caption)
                    .buttonStyle(.borderless)
            }
            Text("Small items filtered out by default. Toggle back on if needed.")
                .font(.caption2)
                .foregroundColor(.secondary)
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
        .listStyle(.plain)
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
