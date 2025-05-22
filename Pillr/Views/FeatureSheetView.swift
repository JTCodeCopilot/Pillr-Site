import SwiftUI

struct FeatureSheetView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#404C42").ignoresSafeArea() // Background color consistent with the app

                VStack(spacing: 20) {
                    Text("Pillr Intelligence")
                        .font(.largeTitle)
                        .fontWeight(.regular)
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .padding(.top, 40)

                    FeatureRow(
                        iconName: "pills.fill",
                        title: "Medication Tracking",
                        description: "Easily log and manage your medications."
                    )

                    FeatureRow(
                        iconName: "bell.fill",
                        title: "Custom Reminders",
                        description: "Set personalized reminders so you never miss a dose."
                    )

                    FeatureRow(
                        iconName: "cross.case.fill",
                        title: "Interaction Checker",
                        description: "Check for potential interactions between your medications."
                    )
                    
                    FeatureRow(
                        iconName: "chart.bar.fill",
                        title: "Progress Reports",
                        description: "View insightful reports on your medication adherence."
                    )

                    Spacer()

                    Button(action: {
                        isPresented = false
                        // Maybe navigate to a premium features page or similar
                    }) {
                        Text("Explore More")
                            .font(.headline)
                            .foregroundColor(Color(hex: "#404C42"))
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: "#C7C7BD"))
                            .cornerRadius(10)
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarItems(trailing: Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .font(.title2)
            })
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark) // Assuming your app uses a dark theme primarily
    }
}

struct FeatureRow: View {
    let iconName: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: iconName)
                .font(.title)
                .foregroundColor(Color(hex: "#C7C7BD"))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#E0E0E0"))
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

struct FeatureSheetView_Previews: PreviewProvider {
    static var previews: some View {
        FeatureSheetView(isPresented: .constant(true))
    }
} 
