//
//  ChangePasswordView.swift
//  WellPath
//
//  User interface for changing password
//

import SwiftUI

struct ChangePasswordView: View {
    @StateObject private var viewModel = ChangePasswordViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showSuccessAlert = false

    var body: some View {
        Form {
            Section {
                SecureField("New Password", text: $viewModel.newPassword)
                    .textContentType(.newPassword)

                // Password strength indicator
                if !viewModel.newPassword.isEmpty {
                    HStack {
                        Text("Strength:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        PasswordStrengthBar(strength: viewModel.passwordStrength)

                        Text(viewModel.passwordStrength.label)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(strengthColor)
                    }
                }

                SecureField("Confirm Password", text: $viewModel.confirmPassword)
                    .textContentType(.newPassword)
            } header: {
                Text("New Password")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if let message = viewModel.validationMessage {
                        Text(message)
                            .foregroundColor(.red)
                    } else {
                        Text("Password must be at least 8 characters")
                    }
                }
            }

            Section {
                Button(action: {
                    Task {
                        let success = await viewModel.changePassword()
                        if success {
                            showSuccessAlert = true
                        }
                    }
                }) {
                    HStack {
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Change Password")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!viewModel.isValid || viewModel.isLoading)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your password has been changed successfully.")
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }

    private var strengthColor: Color {
        switch viewModel.passwordStrength {
        case .none: return .secondary
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }
}

// MARK: - Password Strength Bar

struct PasswordStrengthBar: View {
    let strength: PasswordStrength

    private var filledSegments: Int {
        switch strength {
        case .none: return 0
        case .weak: return 1
        case .medium: return 2
        case .strong: return 3
        }
    }

    private var barColor: Color {
        switch strength {
        case .none: return .secondary
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < filledSegments ? barColor : Color(uiColor: .tertiarySystemFill))
                    .frame(width: 20, height: 6)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChangePasswordView()
    }
}
