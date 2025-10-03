import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: IntentSettingsStore

    @State private var apiKey: String = ""
    @State private var hasStoredAPIKey = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var advancedExpanded = false
    @State private var aboutTapCount = 0
    @AppStorage("intent.legacy.unlocked") private var legacyUnlocked: Bool = false
#if DEBUG
    @State private var debugStatus: String = ""
    @AppStorage("debug.useSamplePhoto") private var useSamplePhoto = true
#endif

    private var isoFormatter: ISO8601DateFormatter { ISO8601DateFormatter() }

    var body: some View {
        NavigationView {
            Form {
                apiSection
                miniSurveySection
                regionSection
                remindersSection
                advancedSection
                aiStatusSection
                aboutSection
#if DEBUG
                debugSection
#endif
            }
            .navigationTitle(L10n.key("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Text(L10n.key("settings.close"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { saveAPIKey() }) {
                        Text(L10n.key("settings.save_api_key"))
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
            .onAppear {
                let stored = Secrets.load()
                apiKey = stored
                hasStoredAPIKey = !stored.isEmpty
                emitAISnapshotTelemetry(hasKeyOverride: hasStoredAPIKey)
            }
            .alert(L10n.key("settings.api_alert_title"), isPresented: $showingAlert) {
                Button(L10n.key("common.ok")) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var apiSection: some View {
        Section(header: Text(L10n.key("settings.openai.header"))) {
            SecureField(L10n.string("settings.openai.placeholder"), text: $apiKey)
                .textContentType(.password)
            Text(L10n.key("settings.openai.caption"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var miniSurveySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.key("settings.purpose.header"))
                    .font(.headline)

                ForEach([Purpose.move_fast, Purpose.move_value, Purpose.cleanup], id: \.self) { purpose in
                    Button(action: {
                        store.update { $0.purpose = purpose }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.key(purposeTitleKey(purpose)))
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text(L10n.key(purposeDescriptionKey(purpose)))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            if store.value.purpose == purpose {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }

                if legacyUnlocked || store.value.purpose == .legacy_hidden {
                    Button(action: {
                        store.update { $0.purpose = .legacy_hidden }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.key("settings.purpose.legacy"))
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text(L10n.key("settings.purpose.legacy_description"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            if store.value.purpose == .legacy_hidden {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var regionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.key("settings.region.header"))
                    .font(.headline)

                ForEach(["JP", "CA-TO", "OTHER"], id: \.self) { region in
                    Button(action: {
                        store.update { $0.region = region }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.key(regionTitleKey(region)))
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text(L10n.key(regionDescriptionKey(region)))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            if store.value.region == region {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }

                DatePicker(L10n.key("settings.goal_date.label"), selection: bindingDate(\.goalDateISO), displayedComponents: .date)
                    .padding(.top, 8)
            }
        }
    }

    private var remindersSection: some View {
        Section(L10n.key("settings.reminders.header")) {
            TextField(L10n.string("settings.reminders.placeholder"), text: binding(\.remindersList))
        }
    }

    private var advancedSection: some View {
        Section {
            DisclosureGroup(isExpanded: $advancedExpanded) {
                Picker(L10n.key("settings.advanced.small_items"), selection: binding(\.smallItemThreshold)) {
                    ForEach(SmallThreshold.allCases, id: \.self) { threshold in
                        Text(L10n.key(threshold.localizationKey)).tag(threshold)
                    }
                }
                Stepper(value: binding(\.maxTasksPerPhoto), in: 4...8) {
                    Text(L10n.string("settings.advanced.max_tasks", store.value.maxTasksPerPhoto))
                }
                ForEach(ExitTag.allCases, id: \.self) { tag in
                    HStack {
                        Text(L10n.key(tag.localizationKey))
                        Spacer()
                        OffsetStepper(key: tag.rawValue)
                    }
                }
                Toggle(L10n.key("settings.advanced.llm_consent"), isOn: consentBinding)
                if legacyUnlocked {
                    Toggle(L10n.key("settings.advanced.legacy_toggle"), isOn: legacyModeBinding)
                    Text(L10n.key("settings.advanced.legacy_caption"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Button(action: resetOffsets) {
                    Text(L10n.key("settings.advanced.reset_offsets"))
                }
                .font(.caption)
            } label: {
                Text(L10n.key("settings.advanced.header"))
            }
        }
    }

    private var aiStatusSection: some View {
        Section(L10n.key("settings.status.header")) {
            StatusRow(title: L10n.key("settings.status.flag"),
                      value: FeatureFlags.intentSettingsV1 ? L10n.key("settings.status.enabled") : L10n.key("settings.status.disabled"),
                      isActive: FeatureFlags.intentSettingsV1)
            StatusRow(title: L10n.key("settings.status.consent"),
                      value: store.value.llm.consent ? L10n.key("settings.status.granted") : L10n.key("settings.status.off"),
                      isActive: store.value.llm.consent)
            StatusRow(title: L10n.key("settings.status.api_key"),
                      value: hasStoredAPIKey ? L10n.key("settings.status.stored") : L10n.key("settings.status.missing"),
                      isActive: hasStoredAPIKey)
            StatusRow(title: L10n.key("settings.status.network"),
                      value: allowNetworkStatus ? L10n.key("settings.status.allowed") : L10n.key("settings.status.blocked"),
                      isActive: allowNetworkStatus)
            let reason = TelemetryTracker.shared.localizedSkipReason()
            if reason != "-" {
                Text(L10n.string("settings.status.last_skip", reason))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Button(action: { emitAISnapshotTelemetry() }) {
                Text(L10n.key("settings.status.send_snapshot"))
            }
            .font(.caption)
        }
    }

    private var aboutSection: some View {
        Section(L10n.key("settings.about.header")) {
            Button(action: handleVersionTap) {
                Text(L10n.string("settings.about.version", appVersion))
            }
            .foregroundColor(.secondary)
            Text(L10n.key("settings.about.description"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

#if DEBUG
    private var debugSection: some View {
        Section(L10n.key("settings.debug.header")) {
            Toggle(L10n.key("settings.debug.sample_photo"), isOn: $useSamplePhoto)
            Button(action: runEnrichmentTest) {
                Text(L10n.key("settings.debug.force_enrichment"))
            }
            Text(L10n.string("settings.debug.last_skip", TelemetryTracker.shared.localizedSkipReason()))
                .font(.caption)
                .foregroundColor(.secondary)
            if !debugStatus.isEmpty {
                Text(debugStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
#endif

    private func saveAPIKey() {
        if Secrets.save(apiKey) {
            alertMessage = L10n.string("settings.api_saved")
            hasStoredAPIKey = true
            emitAISnapshotTelemetry(hasKeyOverride: true)
        } else {
            alertMessage = L10n.string("settings.api_failed")
        }
        showingAlert = true
    }

    private func binding<T>(_ keyPath: WritableKeyPath<IntentSettings, T>) -> Binding<T> {
        Binding(
            get: { store.value[keyPath: keyPath] },
            set: { newValue in
                store.update { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private func bindingDate(_ keyPath: WritableKeyPath<IntentSettings, String>) -> Binding<Date> {
        Binding<Date>(
            get: {
                let iso = store.value[keyPath: keyPath]
                return isoFormatter.date(from: iso) ?? Date()
            },
            set: { newDate in
                let formatted = isoFormatter.string(from: newDate)
                store.update { $0[keyPath: keyPath] = formatted }
            }
        )
    }

    private var consentBinding: Binding<Bool> {
        Binding(
            get: { store.value.llm.consent },
            set: { newValue in
                store.update { $0.llm.consent = newValue }
                emitAISnapshotTelemetry(consentOverride: newValue)
            }
        )
    }

    private var legacyModeBinding: Binding<Bool> {
        Binding(
            get: { store.value.purpose == .legacy_hidden },
            set: { newValue in
                store.update { settings in
                    settings.purpose = newValue ? .legacy_hidden : .move_fast
                }
            }
        )
    }

    private func resetOffsets() {
        store.update { settings in
            settings.offsets = [
                "SELL": -7,
                "GIVE": -5,
                "RECYCLE": -3,
                "TRASH": -2,
                "KEEP": -1
            ]
        }
    }

    private var allowNetworkStatus: Bool {
        FeatureFlags.intentSettingsV1 && hasStoredAPIKey && store.value.llm.consent
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private func handleVersionTap() {
        aboutTapCount += 1
        if aboutTapCount >= 5 {
            legacyUnlocked = true
        }
    }

    private func purposeTitleKey(_ purpose: Purpose) -> String {
        switch purpose {
        case .move_fast: return "settings.purpose.move_fast"
        case .move_value: return "settings.purpose.move_value"
        case .cleanup: return "settings.purpose.cleanup"
        case .legacy_hidden: return "settings.purpose.legacy"
        }
    }

    private func purposeDescriptionKey(_ purpose: Purpose) -> String {
        switch purpose {
        case .move_fast: return "settings.purpose.move_fast_description"
        case .move_value: return "settings.purpose.move_value_description"
        case .cleanup: return "settings.purpose.cleanup_description"
        case .legacy_hidden: return "settings.purpose.legacy_description"
        }
    }

    private func regionTitleKey(_ region: String) -> String {
        switch region {
        case "JP": return "settings.region.jp"
        case "CA-TO": return "settings.region.ca_to"
        default: return "settings.region.other"
        }
    }

    private func regionDescriptionKey(_ region: String) -> String {
        switch region {
        case "JP": return "settings.region.jp_description"
        case "CA-TO": return "settings.region.ca_to_description"
        default: return "settings.region.other_description"
        }
    }

#if DEBUG
    private func runEnrichmentTest() {
        Task {
            debugStatus = L10n.string("settings.debug.running")
            let status = await TidyPlanner.debugForceEnrichmentTest()
            debugStatus = status
        }
    }
#endif

    private func emitAISnapshotTelemetry(consentOverride: Bool? = nil, hasKeyOverride: Bool? = nil) {
        let consent = consentOverride ?? store.value.llm.consent
        let hasKey = hasKeyOverride ?? hasStoredAPIKey
        let featureEnabled = FeatureFlags.intentSettingsV1
        let allowNetwork = featureEnabled && hasKey && consent
        TelemetryTracker.shared.trackAISettingsSnapshot(
            featureEnabled: featureEnabled,
            consent: consent,
            hasAPIKey: hasKey,
            allowNetwork: allowNetwork
        )
    }
}

private struct OffsetStepper: View {
    @EnvironmentObject private var store: IntentSettingsStore
    let key: String

    var body: some View {
        Stepper(value: binding, in: -30...0) {
            Text(L10n.string("settings.offset.format", binding.wrappedValue))
        }
    }

    private var binding: Binding<Int> {
        Binding(
            get: { store.value.offsets[key, default: 0] },
            set: { newValue in store.update { $0.offsets[key] = newValue } }
        )
    }
}

private struct StatusRow: View {
    let title: LocalizedStringKey
    let value: LocalizedStringKey
    let isActive: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(isActive ? .green : .secondary)
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
