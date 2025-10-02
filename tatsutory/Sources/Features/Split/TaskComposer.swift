import Foundation

struct TaskComposer {
    struct Blueprint {
        let id: String
        let displayLabel: String
        let labelKey: String
        let exitTag: ExitTag
        let schedule: TaskSchedule
        let checklist: [String]
        let links: [String]
        let note: String
        let timeEstimateMinutes: Int
        let tip: String

        var title: String {
            "\(exitTag.localizedName): \(displayLabel)"
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func buildLocalTasks(settings: IntentSettings, locale: UserLocale, items: [DetectedItem]) -> [TidyTask] {
        guard !items.isEmpty else { return fallbackTasks(settings: settings, locale: locale) }
        let blueprints = makeBlueprints(settings: settings, locale: locale, items: items)
        return tasks(from: blueprints)
    }

    static func fallbackPlan(settings: IntentSettings, locale: UserLocale) -> Plan {
        let tasks = fallbackTasks(settings: settings, locale: locale)
        return Plan(project: L10n.string("plan.project_name"), locale: locale, tasks: tasks).validated()
    }

    static func makeBlueprints(settings: IntentSettings, locale: UserLocale, items: [DetectedItem]) -> [Blueprint] {
        let goalDate = isoFormatter.date(from: settings.goalDateISO) ?? Date()
        let scheduler = WBSComposer(goalDate: goalDate, offsets: settings.offsets)
        let limitedItems = Array(items.prefix(settings.maxTasksPerPhoto))
        return limitedItems.map { item in
            let exitTag = inferExitTag(for: item, settings: settings)
            let schedule = scheduler.schedule(for: exitTag)
            let checklist = buildChecklist(exitTag: exitTag, locale: locale, purpose: settings.purpose, label: item.label)
            let links = LocaleGuide.getDefaultLinks(for: locale, exitTag: exitTag)
            let timeEstimate = estimatedMinutes(for: exitTag)
            let tip = buildTip(exitTag: exitTag, label: item.label, locale: locale, purpose: settings.purpose)
            let note = buildNote(exitTag: exitTag,
                                 offsetDays: schedule.offsetDays,
                                 locale: locale,
                                 label: item.label,
                                 purpose: settings.purpose,
                                 timeMinutes: timeEstimate,
                                 tip: tip)
            return Blueprint(
                id: item.id.uuidString,
                displayLabel: item.label,
                labelKey: item.label.lowercased(),
                exitTag: schedule.exitTag,
                schedule: schedule,
                checklist: checklist,
                links: dedupe(links),
                note: note,
                timeEstimateMinutes: timeEstimate,
                tip: tip
            )
        }
    }

    private static func fallbackTasks(settings: IntentSettings, locale: UserLocale) -> [TidyTask] {
        let schedule = makeFallbackSchedule(settings: settings)
        let timeEstimate = estimatedMinutes(for: .keep)
        let tip = buildTip(exitTag: .keep, label: "Declutter", locale: locale, purpose: settings.purpose)
        let blueprint = Blueprint(
            id: UUID().uuidString,
            displayLabel: "Declutter",
            labelKey: "general",
            exitTag: .keep,
            schedule: schedule,
            checklist: ["Sort items in photo", "Decide on exit plan"],
            links: LocaleGuide.getDefaultLinks(for: locale, exitTag: .keep),
            note: buildNote(exitTag: .keep,
                            offsetDays: schedule.offsetDays,
                            locale: locale,
                            label: "Declutter",
                            purpose: settings.purpose,
                            timeMinutes: timeEstimate,
                            tip: tip),
            timeEstimateMinutes: timeEstimate,
            tip: tip
        )
        return tasks(from: [blueprint])
    }

    static func tasks(from blueprints: [Blueprint]) -> [TidyTask] {
        blueprints.map { blueprint in
            TidyTask(
                id: blueprint.id,
                title: blueprint.title,
                note: blueprint.note,
                area: nil,
                exit_tag: blueprint.exitTag,
                priority: nil,
                effort_min: blueprint.timeEstimateMinutes,
                labels: [blueprint.labelKey],
                checklist: blueprint.checklist,
                links: blueprint.links,
                url: nil,
                due_at: isoFormatter.string(from: blueprint.schedule.dueDate)
            )
        }
    }

    private static func makeFallbackSchedule(settings: IntentSettings) -> TaskSchedule {
        let goalDate = isoFormatter.date(from: settings.goalDateISO) ?? Date()
        let scheduler = WBSComposer(goalDate: goalDate, offsets: settings.offsets)
        return scheduler.schedule(for: .keep)
    }

    private static func inferExitTag(for item: DetectedItem, settings: IntentSettings) -> ExitTag {
        let label = item.label.lowercased()
        if label.contains("electronics") || label.contains("battery") {
            return .recycle
        }
        if label.contains("food") || label.contains("trash") {
            return .trash
        }
        if label.contains("book") || label.contains("clothes") {
            return settings.purpose == .move_value ? .sell : .give
        }
        switch settings.purpose {
        case .move_value:
            return .sell
        case .move_fast, .cleanup:
            return .trash
        case .legacy_hidden:
            return .keep
        }
    }

    private static func buildChecklist(exitTag: ExitTag, locale: UserLocale, purpose: Purpose, label: String) -> [String] {
        var steps = LocaleGuide.getTemplateChecklist(for: exitTag, locale: locale)
        if purpose == .legacy_hidden {
            steps.append("Discuss with family about \(label)")
        }
        return dedupe(steps)
    }

    private static func buildNote(exitTag: ExitTag,
                                  offsetDays: Int,
                                  locale: UserLocale,
                                  label: String,
                                  purpose: Purpose,
                                  timeMinutes: Int,
                                  tip: String) -> String {
        let isJapanese = locale.country.uppercased() == "JP" || (Locale.preferredLanguages.first ?? "en").hasPrefix("ja")
        let offsetDescription: String
        if isJapanese {
            if offsetDays == 0 {
                offsetDescription = "ゴール当日"
            } else {
                let direction = offsetDays < 0 ? "前" : "後"
                offsetDescription = "ゴール\(abs(offsetDays))日\(direction)"
            }
            return "締切: \(offsetDescription) (\(locale.city))\n所要時間目安: 約\(timeMinutes)分\nひとこと: \(tip)"
        } else {
            if offsetDays == 0 {
                offsetDescription = "On goal date"
            } else {
                let dayLabel = abs(offsetDays) == 1 ? "day" : "days"
                let direction = offsetDays < 0 ? "before" : "after"
                offsetDescription = "\(abs(offsetDays)) \(dayLabel) \(direction) goal"
            }
            return "Deadline: \(offsetDescription) (\(locale.city))\nTime estimate: ~\(timeMinutes) min\nTip: \(tip)"
        }
    }

    private static func dedupe(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }
        return result
    }

    private static func estimatedMinutes(for exitTag: ExitTag) -> Int {
        switch exitTag {
        case .sell: return 25
        case .give: return 20
        case .recycle: return 15
        case .trash: return 10
        case .keep: return 15
        }
    }

    private static func buildTip(exitTag: ExitTag,
                                 label: String,
                                 locale: UserLocale,
                                 purpose: Purpose) -> String {
        let isJapanese = locale.country.uppercased() == "JP" || (Locale.preferredLanguages.first ?? "en").hasPrefix("ja")
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (exitTag, isJapanese) {
        case (.sell, true):
            return "\(trimmedLabel)はメルカリで『家電・カメラ > オーディオ機器』に登録すると検索されやすい。相場より5%高く出して値下げ交渉で落ち着かせると早く売れやすい。"
        case (.sell, false):
            return "List \(trimmedLabel) under “Electronics > Audio” on Mercari and start about 5% above comps to leave room for offers."
        case (.give, true):
            return "ジモティーで最寄駅と一緒に投稿すると閲覧数が一気に増える。『即日受け渡し可』を添えると声が掛かりやすい。"
        case (.give, false):
            return "Mention your nearest station or neighborhood in the listing; same-day pickup notes drive quick replies."
        case (.recycle, true):
            return "自治体の粗大ごみ受付はスマホ申し込みが最短5分。スクショを撮っておけば当日の確認もラク。"
        case (.recycle, false):
            return "Book the municipal pickup online—it usually takes under 5 minutes. Screenshot the confirmation for collection day."
        case (.trash, true):
            return "前夜に玄関へ移動させると朝のバタつきゼロ。袋に日付を書いておくと出し忘れ防止になる。"
        case (.trash, false):
            return "Stage the bag by the door the night before and jot the pickup date on painter’s tape to avoid morning rush."
        case (.keep, true):
            if purpose == .legacy_hidden {
                return "家族と短い時間で共有すると迷いが減る。『手放すか/写真だけ残すか』の二択にすると決めやすい。"
            }
            return "透明ケースやジッパーバッグにまとめておくと次の仕分けも10分で済む。"
        case (.keep, false):
            if purpose == .legacy_hidden {
                return "Schedule a quick family chat; framing the choice as “keep vs. digitize” keeps momentum."
            }
            return "Store it in a clear bin with a bold label so the next cleanup takes under 10 minutes."
        }
    }
}
