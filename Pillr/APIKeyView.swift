import SwiftUI

struct APIKeyView: View {
    @ObservedObject private var openAIService = OpenAIService.shared
    @State private var apiKey: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("hasSetAPIKey") private var hasSetAPIKey = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hex: "#404C42")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Text("OpenAI API Key")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#C7C7BD"))
                            .padding(.top, 20)
                        
                        // Premium Mode Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                
                                Text("Premium Mode")
                                    .font(.headline)
                                    .foregroundColor(Color(hex: "#C7C7BD"))
                                
                                Spacer()
                                
                                Toggle("", isOn: $openAIService.isPremiumMode)
                                    .labelsHidden()
                                    .toggleStyle(SwitchToggleStyle(tint: Color.pillrAccent))
                                    .onChange(of: openAIService.isPremiumMode) { newValue in
                                        if newValue {
                                            openAIService.enablePremiumMode()
                                            alertMessage = "Premium mode enabled! You can now use the built-in API key."
                                            showingAlert = true
                                        } else {
                                            openAIService.disablePremiumMode()
                                        }
                                    }
                            }
                            
                            Text("Enable premium mode to use our built-in API key for medication interaction checks.")
                                .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                        }
                        .padding()
                        .gyroGlassCardStyle(cornerRadius: 16, borderColor: Color.yellow.opacity(0.5))
                        .padding(.horizontal)
                        
                        // Or divider
                        HStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 1)
                            
                            Text("OR")
                                .foregroundColor(Color(hex: "#404C42").opacity(0.6))
                                .font(.caption)
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        // Personal API Key section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Use Your Own API Key")
                                .font(.headline)
                                .foregroundColor(Color(hex: "#404C42"))
                                .padding(.horizontal)
                            
                            Text("If you prefer, you can use your own OpenAI API key. Your key is stored securely on your device only.")
                                .foregroundColor(Color(hex: "#404C42").opacity(0.9))
                                .padding(.horizontal)
                            
                            Text("You can obtain an API key from OpenAI's website by signing up for an account.")
                                .foregroundColor(Color(hex: "#404C42").opacity(0.8))
                                .padding(.horizontal)
                            
                            Link("Get an API Key from OpenAI", destination: URL(string: "https://platform.openai.com/api-keys")!)
                                .foregroundColor(Color.pillrAccent)
                                .padding(.horizontal)
                                .padding(.top, 4)
                        }
                        .padding()
                        .gyroGlassCardStyle(cornerRadius: 16, borderColor: .white.opacity(0.3))
                        .padding(.horizontal)
                        .opacity(openAIService.isPremiumMode ? 0.6 : 1.0)
                        .disabled(openAIService.isPremiumMode)
                        
                        if !openAIService.isPremiumMode {
                            VStack(spacing: 16) {
                                SecureField("Enter your OpenAI API key", text: $apiKey)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                    .foregroundColor(Color(hex: "#404C42"))
                                    .accentColor(Color.pillrAccent)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                
                                Button(action: saveAPIKey) {
                                    Text("Save API Key")
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(hex: "#404C42"))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.pillrAccent.opacity(0.8), Color.pillrAccent]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(10)
                                }
                                .buttonStyle(HapticButtonStyle(style: .success))
                                .disabled(apiKey.isEmpty)
                                .opacity(apiKey.isEmpty ? 0.6 : 1.0)
                                
                                if hasSetAPIKey {
                                    Button(action: clearAPIKey) {
                                        Text("Clear API Key")
                                            .fontWeight(.semibold)
                                            .foregroundColor(Color(hex: "#404C42"))
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color.red.opacity(0.6), Color.red.opacity(0.8)]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .cornerRadius(10)
                                    }
                                    .buttonStyle(HapticButtonStyle(style: .warning))
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 40)
                }
                .alert(isPresented: $showingAlert) {
                    Alert(
                        title: Text("API Key"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
                .navigationBarTitle("", displayMode: .inline)
                .navigationBarItems(trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                })
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(Color.pillrAccent)
                        .buttonStyle(HapticButtonStyle(style: .soft))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveAPIKey() {
        if !apiKey.isEmpty {
            openAIService.setAPIKey(apiKey)
            hasSetAPIKey = true
            alertMessage = "API key saved successfully!"
            showingAlert = true
            apiKey = "" // Clear the text field for security
        }
    }
    
    private func clearAPIKey() {
        openAIService.clearAPIKey()
        hasSetAPIKey = false
        alertMessage = "API key has been cleared"
        showingAlert = true
    }
} 
