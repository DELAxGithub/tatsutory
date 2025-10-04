import SwiftUI

struct OverviewPlanView: View {
    let plan: OverviewPlan
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Overview Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("全体概要")
                            .font(.headline)
                            .foregroundColor(.primary)

                        VStack(alignment: .leading, spacing: 8) {
                            Label(plan.overview.state, systemImage: "house")
                                .font(.body)

                            Label(plan.overview.estimatedTime, systemImage: "clock")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Main Issues Section
                    if !plan.overview.mainIssues.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("主な課題")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(plan.overview.mainIssues.enumerated()), id: \.offset) { index, issue in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1).")
                                            .foregroundColor(.secondary)
                                        Text(issue)
                                            .font(.subheadline)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }

                    // Quick Start Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("最初の30分でやること")
                            .font(.headline)

                        Text(plan.quickStart)
                            .font(.body)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                    }

                    // Priority Areas Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("優先エリア")
                            .font(.headline)

                        ForEach(plan.priorityAreas) { area in
                            PriorityAreaCard(area: area)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("初手モード - 優先順位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PriorityAreaCard: View {
    let area: OverviewPlan.PriorityArea

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Rank + Area Name
            HStack {
                Text("#\(area.rank)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(rankColor)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(area.areaName)
                        .font(.headline)

                    HStack(spacing: 12) {
                        Label(area.timeRequired, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label(area.difficulty.displayText, systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label(area.impact.displayText, systemImage: "bolt.fill")
                            .font(.caption)
                            .foregroundColor(impactColor)
                    }
                }

                Spacer()
            }

            // Reason
            Text(area.reason)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Tasks
            VStack(alignment: .leading, spacing: 8) {
                Text("作業内容")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                ForEach(Array(area.tasks.enumerated()), id: \.offset) { index, task in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.blue)
                        Text(task)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    private var rankColor: Color {
        switch area.rank {
        case 1: return .red
        case 2: return .orange
        case 3: return .blue
        default: return .gray
        }
    }

    private var impactColor: Color {
        switch area.impact {
        case .high: return .red
        case .medium: return .orange
        case .low: return .gray
        }
    }
}

#Preview {
    OverviewPlanView(
        plan: OverviewPlan(
            overview: OverviewPlan.Overview(
                state: "物の総量は中程度。売却可能な家電・自転車類が複数",
                estimatedTime: "総仕分け3-5時間、出品準備5-15時間",
                mainIssues: [
                    "自転車の処分手配",
                    "PC・モニタの売却判断",
                    "衣類の大量仕分け"
                ]
            ),
            priorityAreas: [
                OverviewPlan.PriorityArea(
                    rank: 1,
                    areaName: "自転車・大型物",
                    reason: "売却・処分に時間がかかるため早めの着手が必要",
                    tasks: [
                        "SELL/GIVE/RECYCLE/KEEPで判断",
                        "売却する場合は早めに出品",
                        "梱包・分解が必要なら工具準備"
                    ],
                    timeRequired: "2-6時間",
                    difficulty: .hard,
                    impact: .high
                )
            ],
            quickStart: "最初の30分で自転車と大物を写真で記録し、持っていく/売る/処分を即決"
        )
    )
}
