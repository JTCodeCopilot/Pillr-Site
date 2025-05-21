import SwiftUI

struct PremiumSearchUpsellView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#404C42") // Consistent background
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "#81C784")) // Accent color

                    Text("Unlock Smart Medication Search")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .multilineTextAlignment(.center)

                    Text("Quickly find medications by name with our AI-powered search. This feature is available for premium users.")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#B0B0B0"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Text("Consider upgrading to access this and other exclusive features!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)


                    Button(action: {
                        // TODO: Add action to navigate to premium upgrade screen or dismiss
                        isPresented = false // Placeholder: just dismisses for now
                    }) {
                        Text("Learn More") // Or "Upgrade Now"
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#404C42"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#C7C7BD"))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 10)

                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Maybe Later")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "#B0B0B0"))
                    }
                    .padding(.top, 5)
                }
                .padding(30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Premium Feature")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(Color(hex: "#C7C7BD"))
                    }
                }
            }
        }
    }
}

#if DEBUG
struct PremiumSearchUpsellView_Previews: PreviewProvider {
    static var previews: some View {
        PremiumSearchUpsellView(isPresented: .constant(true))
            .preferredColorScheme(.dark)
    }
}
#endif 