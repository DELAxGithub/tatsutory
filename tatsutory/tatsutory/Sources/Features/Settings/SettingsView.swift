import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
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
    }
    
    private func saveAPIKey() {
        if Secrets.save(apiKey) {
            alertMessage = "API key saved successfully!"
            showingAlert = true
        } else {
            alertMessage = "Failed to save API key. Please try again."
            showingAlert = true
        }
    }
}