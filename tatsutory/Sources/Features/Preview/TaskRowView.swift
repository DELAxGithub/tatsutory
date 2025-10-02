import SwiftUI

struct TaskRowView: View {
    let task: TidyTask
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            checkButton
            taskInfo
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onToggle(!isSelected) }
    }
    
    private var checkButton: some View {
        Button { onToggle(!isSelected) } label: {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.title3)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var taskInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleRow
            metaRow
            checklistInfo
        }
    }
    
    private var titleRow: some View {
        HStack {
            Text(task.title).font(.headline).lineLimit(2)
            Spacer()
            ExitTagBadge(exitTag: task.exitTag)
        }
    }
    
    private var metaRow: some View {
        HStack(spacing: 16) {
            if let area = task.area {
                MetaLabel(text: area, icon: "location")
            }
            MetaLabel(text: L10n.string("task.meta.effort_minutes", task.effortMinutes), icon: "clock")
            if task.isHighPriority {
                MetaLabel(text: L10n.string("task.meta.priority_high"), icon: "exclamationmark.triangle", color: .orange)
            }
            if task.dueDate != nil {
                MetaLabel(text: L10n.string("task.meta.due"), icon: "calendar", color: .red)
            }
        }
    }

    @ViewBuilder
    private var checklistInfo: some View {
        if let checklist = task.checklist, !checklist.isEmpty {
            let key = checklist.count == 1 ? "task.meta.steps.single" : "task.meta.steps"
            Text(L10n.string(key, checklist.count))
                .font(.caption).foregroundColor(.green)
        }
    }
}

struct ExitTagBadge: View {
    let exitTag: ExitTag
    
    var body: some View {
        Label(exitTag.localizedName, systemImage: exitTag.systemImage)
            .font(.caption)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct MetaLabel: View {
    let text: String
    let icon: String
    var color: Color = .secondary
    
    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption).foregroundColor(color)
    }
}
