import SwiftUI

struct APIKeyView: View {
    @ObservedObject private var openAIService = OpenAIService.shared
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hex: "#404C42")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Text("Premium Access")
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
                                
                            if openAIService.isPremiumMode {
                                Text("Thank you for supporting Pillr! Premium access is now active.")
                                    .foregroundColor(Color.pillrAccent.opacity(0.9))
                                    .padding(.top, 8)
                            } else {
                                Text("Upgrade to premium for unlimited access to medication interaction checks.")
                                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.9))
                                    .padding(.top, 8)
                            }
                        }
                        .padding()
                        .gyroGlassCardStyle(cornerRadius: 16, borderColor: Color.yellow.opacity(0.5))
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .padding(.bottom, 40)
                }
                .alert(isPresented: $showingAlert) {
                    Alert(
                        title: Text("Premium Access"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
                .navigationBarTitle("", displayMode: .inline)
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
} 
