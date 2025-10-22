//
//  LoginView.swift
//  WellPath
//
//  Created on 2025-10-22
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var email = "test.patient.21@wellpath.com"
    @State private var password = "wellpath123"

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.15, blue: 0.2), Color.black]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Logo
                Text("WellPath")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)

                Text("Sign In")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // Login Form
                VStack(spacing: 20) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        TextField("", text: $email)
                            .textFieldStyle(CustomTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .disabled(viewModel.isLoading)
                    }

                    // Password Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        SecureField("", text: $password)
                            .textFieldStyle(CustomTextFieldStyle())
                            .disabled(viewModel.isLoading)
                    }

                    // Error Message
                    if let error = viewModel.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Login Button
                    Button(action: {
                        Task {
                            await viewModel.signIn(email: email, password: password)
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Text("Sign In")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .background(Color.blue)
                    .cornerRadius(12)
                    .disabled(viewModel.isLoading || email.isEmpty || password.isEmpty)
                    .opacity((viewModel.isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                }
                .padding(.horizontal, 30)

                Spacer()
                Spacer()
            }
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .foregroundColor(.white)
    }
}

#Preview {
    LoginView()
}
