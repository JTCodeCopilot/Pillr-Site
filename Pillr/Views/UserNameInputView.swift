//
//  UserNameInputView.swift
//  Pillr
//
//  Created by Justin Tilley on 14/5/2025.
//

import SwiftUI

struct UserNameInputView: View {
    @ObservedObject var settings = UserSettings.shared
    @State private var userName: String = ""
    @State private var isNameInvalid: Bool = false
    @Binding var isShowing: Bool
    
    var body: some View {
        ZStack {
            Color(hex: "#404C42")
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Welcome to Pillr")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .padding(.top, 40)
                
                Text("What's your name?")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#C7C7BD").opacity(0.8))
                    .padding(.bottom, 10)
                
                TextField("Enter your name", text: $userName)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isNameInvalid ? Color.red : Color(hex: "#C7C7BD").opacity(0.2), lineWidth: 1)
                    )
                    .foregroundColor(Color(hex: "#C7C7BD"))
                    .accentColor(Color(hex: "#C7C7BD"))
                    .padding(.horizontal, 20)
                
                if isNameInvalid {
                    Text("Please enter your name")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                
                Button {
                    if userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        isNameInvalid = true
                    } else {
                        settings.saveUserName(userName)
                        settings.isFirstLaunch = false
                        isShowing = false
                    }
                } label: {
                    Text("Continue")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#C7C7BD"))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 40)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "#C7C7BD").opacity(0.2), lineWidth: 1)
                        )
                }
                .padding(.top, 10)
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            userName = settings.userName
        }
    }
} 