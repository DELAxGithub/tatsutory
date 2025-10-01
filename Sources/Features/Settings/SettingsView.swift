import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var goalDate = Date()
    @State private var selectedContext: IntentContext = .moving
    @State private var selectedBias: DisposalBias = .fastDispose
    
    private let intentStore = IntentSettingsStore.shared
    private let consentStore = ConsentStore.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("OpenAI Configuration")) {
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                    
                    Text("Your API key is stored securely in Keychain and never shared.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Intent & Goal")) {
                    Picker("Intent Context", selection: $selectedContext) {
                        ForEach(IntentContext.allCases, id: \.self) { context in
                            Text(context.displayName).tag(context)
                        }
                    }
                    Picker("Disposal Bias", selection: $selectedBias) {
                        ForEach(DisposalBias.allCases, id: \.self) { bias in
                            Text(bias.displayName).tag(bias)
                        }
                    }
                    DatePicker("Goal Date", selection: $goalDate, displayedComponents: .date)
                }
                
                Section(header: Text("Privacy")) {
                    Toggle("Allow AI label refinement", isOn: Binding(
                        get: { consentStore.hasConsentedToVisionUpload },
                        set: { consentStore.hasConsentedToVisionUpload = $0 }
                    ))
                    Text("When disabled, processing stays on-device and uses fallback tasks.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("TatsuTori helps you organize moving tasks by analyzing photos and creating actionable reminders.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
            .onAppear {
                loadAPIKey()
            }
            .alert("Settings", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadAPIKey() {
        apiKey = Secrets.load()
        goalDate = intentStore.goalDate
        let intent = intentStore.currentIntent
        selectedContext = intent.context
        selectedBias = intent.bias
    }
    
    private func saveAPIKey() {
        if Secrets.save(apiKey) {
            alertMessage = "API key saved successfully!"
            showingAlert = true
        } else {
            alertMessage = "Failed to save API key. Please try again."
            showingAlert = true
        }
        intentStore.currentIntent = UserIntent(context: selectedContext, bias: selectedBias)
        intentStore.goalDate = goalDate
    }
}
