//
//  LoginView.swift
//  WellPath
//
//  Authentication view with Sign In, Sign Up, and Forgot Password options
//  Handles deep link tokens for invitation/password reset flows
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthStateManager
    @StateObject private var viewModel = LoginViewModel()

    // Sign In fields
    @State private var email = ""
    @State private var password = ""

    // Forgot Password
    @State private var showForgotPassword = false
    @State private var forgotPasswordEmail = ""

    // Set Password (from invite link)
    @State private var showSetPassword = false
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""

    // New Patient Setup
    @State private var setupEmail = ""
    @State private var setupPassword = ""
    @State private var setupConfirmPassword = ""

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.15, blue: 0.2), Color.black]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 60)

                    // Logo
                    VStack(spacing: 8) {
                        Text("WellPath")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)

                        Text("Your path to better health")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()
                        .frame(height: 40)

                    // Sign In Header
                    Text("Sign In")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    // Sign In Form
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
                                .textContentType(.emailAddress)
                                .disabled(viewModel.isLoading)
                        }

                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))

                            SecureField("", text: $password)
                                .textFieldStyle(CustomTextFieldStyle())
                                .textContentType(.password)
                                .disabled(viewModel.isLoading)
                        }

                        // Error Message
                        if let error = viewModel.error {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Success Message
                        if let success = viewModel.successMessage {
                            Text(success)
                                .font(.caption)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        // Sign In Button
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
                        .background(isFormValid ? Color.blue : Color.gray)
                        .cornerRadius(12)
                        .disabled(viewModel.isLoading || !isFormValid)

                        // Forgot Password
                        Button(action: {
                            forgotPasswordEmail = email
                            showForgotPassword = true
                        }) {
                            Text("Forgot Password?")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 30)

                    Spacer()
                        .frame(height: 40)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 1)
                        Text("New Patient?")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 12)
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 30)

                    // New Patient Setup
                    VStack(spacing: 16) {
                        if viewModel.patientExists == true {
                            // Step 2: Patient found - show password fields
                            if let firstName = viewModel.patientFirstName {
                                Text("Welcome, \(firstName)!")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }

                            Text("Create a password to complete your account setup.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)

                            // Password Fields
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))

                                SecureField("", text: $setupPassword)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .textContentType(.newPassword)
                                    .disabled(viewModel.isLoading)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))

                                SecureField("", text: $setupConfirmPassword)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .textContentType(.newPassword)
                                    .disabled(viewModel.isLoading)
                            }

                            // Validation hints
                            if !setupPassword.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Image(systemName: setupPassword.count >= 8 ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(setupPassword.count >= 8 ? .green : .white.opacity(0.4))
                                        Text("At least 8 characters")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                    }

                                    if !setupConfirmPassword.isEmpty {
                                        HStack(spacing: 8) {
                                            Image(systemName: setupPassword == setupConfirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .foregroundColor(setupPassword == setupConfirmPassword ? .green : .red)
                                            Text("Passwords match")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                    }
                                }
                            }

                            // Set Password Button
                            Button(action: {
                                Task {
                                    await viewModel.setPatientPassword(email: setupEmail, password: setupPassword)
                                    if viewModel.successMessage != nil {
                                        // Clear fields after success
                                        setupPassword = ""
                                        setupConfirmPassword = ""
                                    }
                                }
                            }) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                } else {
                                    Text("Set Password")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                }
                            }
                            .background(isSetupPasswordValid ? Color.green.opacity(0.8) : Color.gray.opacity(0.5))
                            .cornerRadius(10)
                            .disabled(viewModel.isLoading || !isSetupPasswordValid)

                            // Back button
                            Button(action: {
                                viewModel.patientExists = nil
                                viewModel.patientFirstName = nil
                                setupPassword = ""
                                setupConfirmPassword = ""
                            }) {
                                Text("Use different email")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }

                        } else {
                            // Step 1: Enter email
                            Text("If your clinician has added you to WellPath, enter your email to set up your account.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)

                            // Setup Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))

                                TextField("", text: $setupEmail)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .disabled(viewModel.isLoading)
                            }

                            // Continue Button
                            Button(action: {
                                Task {
                                    await viewModel.checkPatientExists(email: setupEmail)
                                }
                            }) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                } else {
                                    Text("Continue")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                }
                            }
                            .background(setupEmail.isEmpty ? Color.gray.opacity(0.5) : Color.green.opacity(0.8))
                            .cornerRadius(10)
                            .disabled(viewModel.isLoading || setupEmail.isEmpty)
                        }
                    }
                    .padding(.horizontal, 30)

                    Spacer()
                        .frame(height: 60)
                }
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet(
                email: $forgotPasswordEmail,
                viewModel: viewModel,
                isPresented: $showForgotPassword
            )
        }
        .sheet(isPresented: $showSetPassword) {
            SetPasswordSheet(
                newPassword: $newPassword,
                confirmNewPassword: $confirmNewPassword,
                viewModel: viewModel,
                isPresented: $showSetPassword
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPasswordReset)) { _ in
            showSetPassword = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showInviteSetPassword)) { _ in
            showSetPassword = true
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }

    private var isSetupPasswordValid: Bool {
        setupPassword.count >= 8 && setupPassword == setupConfirmPassword
    }
}

// MARK: - Forgot Password Sheet

struct ForgotPasswordSheet: View {
    @Binding var email: String
    @ObservedObject var viewModel: LoginViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding(.top, 40)

                // Title
                Text("Reset Password")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Enter your email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .disabled(viewModel.isLoading)
                }
                .padding(.horizontal)

                // Error/Success Messages
                if let error = viewModel.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                if let success = viewModel.successMessage {
                    Text(success)
                        .font(.caption)
                        .foregroundColor(.green)
                }

                // Send Button
                Button(action: {
                    Task {
                        await viewModel.resetPassword(email: email)
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("Send Reset Link")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(email.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(12)
                .disabled(viewModel.isLoading || email.isEmpty)
                .padding(.horizontal)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Set Password Sheet (from invite or reset link)

struct SetPasswordSheet: View {
    @Binding var newPassword: String
    @Binding var confirmNewPassword: String
    @ObservedObject var viewModel: LoginViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding(.top, 40)

                // Title
                Text("Set Your Password")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Create a password to complete your account setup.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Password Fields
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Password")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        SecureField("Enter new password", text: $newPassword)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.newPassword)
                            .disabled(viewModel.isLoading)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        SecureField("Confirm new password", text: $confirmNewPassword)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.newPassword)
                            .disabled(viewModel.isLoading)
                    }
                }
                .padding(.horizontal)

                // Validation hints
                if !newPassword.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: newPassword.count >= 8 ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(newPassword.count >= 8 ? .green : .secondary)
                            Text("At least 8 characters")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if !confirmNewPassword.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: newPassword == confirmNewPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(newPassword == confirmNewPassword ? .green : .red)
                                Text("Passwords match")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Error/Success Messages
                if let error = viewModel.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                if let success = viewModel.successMessage {
                    Text(success)
                        .font(.caption)
                        .foregroundColor(.green)
                }

                // Update Button
                Button(action: {
                    Task {
                        if newPassword != confirmNewPassword {
                            viewModel.error = "Passwords do not match"
                            return
                        }
                        await viewModel.updatePassword(newPassword: newPassword)
                        if viewModel.error == nil {
                            isPresented = false
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("Update Password")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(isPasswordValid ? Color.blue : Color.gray)
                .cornerRadius(12)
                .disabled(viewModel.isLoading || !isPasswordValid)
                .padding(.horizontal)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private var isPasswordValid: Bool {
        newPassword.count >= 8 && newPassword == confirmNewPassword
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .foregroundColor(.white)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showPasswordReset = Notification.Name("showPasswordReset")
    static let showInviteSetPassword = Notification.Name("showInviteSetPassword")
}

#Preview {
    LoginView()
        .environmentObject(AuthStateManager())
}
