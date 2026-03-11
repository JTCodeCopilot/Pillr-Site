import SwiftUI

struct FeatureSheetView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color.pillrPrimary.ignoresSafeArea() // Background color consistent with the app

                VStack(spacing: 20) {
                    Text("Pillr Features")
                        .font(.largeTitle)
                        .fontWeight(.regular)
                        .foregroundColor(Color.pillrSecondary)
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
                            .foregroundColor(Color.pillrPrimary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.pillrSecondary)
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
                    .foregroundColor(Color.pillrSecondary)
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
                .foregroundColor(Color.pillrSecondary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.pillrBackground)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(Color.pillrSecondary.opacity(0.8))
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
