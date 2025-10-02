import SwiftUI

struct TaskListView: View {
    let plan: Plan
    let selectedTasks: Set<String>
    let onTaskToggle: (String) -> Void
    let onSelectAll: () -> Void
    let onClearAll: () -> Void

    init(plan: Plan,
         selectedTasks: Set<String>,
         onTaskToggle: @escaping (String) -> Void,
         onSelectAll: @escaping () -> Void,
         onClearAll: @escaping () -> Void) {
        self.plan = plan
        self.selectedTasks = selectedTasks
        self.onTaskToggle = onTaskToggle
        self.onSelectAll = onSelectAll
        self.onClearAll = onClearAll
    }
    
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
                Text(L10n.string("tasklist.selection_status", selectedTasks.count, plan.tasks.count))
                    .font(.caption).foregroundColor(.blue)
                Spacer()
                Button(action: onClearAll) {
                    Text(L10n.key("tasklist.clear_all"))
                }
                    .font(.caption)
                    .buttonStyle(.borderless)
                Button(action: onSelectAll) {
                    Text(L10n.key("tasklist.select_all"))
                }
                    .font(.caption)
                    .buttonStyle(.borderless)
            }
            Text(L10n.key("tasklist.small_items_hint"))
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
            Text(L10n.key("importing.title")).font(.headline)
            Text(L10n.string("importing.progress", progress, total))
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
