//
//  EducationQAModal.swift
//  WellPath
//
//  AI-powered Q&A modal for asking questions about health metrics
//  Uses the generate-education edge function with Anthropic Claude
//

import SwiftUI

struct EducationQAModal: View {
    let viewId: String
    let viewName: String
    let color: Color

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EducationQAViewModel
    @FocusState private var isInputFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    init(viewId: String, viewName: String, color: Color) {
        self.viewId = viewId
        self.viewName = viewName
        self.color = color
        _viewModel = StateObject(wrappedValue: EducationQAViewModel(viewId: viewId, viewName: viewName))
    }

    var body: some View {
        NavigationStack {
            mainContentView
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 0) {
                        inputView

                        // Spacer for keyboard
                        if keyboardHeight > 0 {
                            Color.clear
                                .frame(height: keyboardHeight)
                        }
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("Ask About \(viewName)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        if !viewModel.conversationHistory.isEmpty {
                            Button("Clear") {
                                viewModel.clearConversation()
                            }
                            .foregroundColor(.secondary)
                        }
                    }

                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isInputFocused = false
                        }
                    }
                }
                .task {
                    await viewModel.loadInitialData()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                        withAnimation(.easeOut(duration: 0.25)) {
                            keyboardHeight = keyboardFrame.height
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        keyboardHeight = 0
                    }
                }
        }
    }

    // MARK: - Main Content View

    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Conversation area (takes remaining space)
            if viewModel.isLoadingHistory {
                loadingHistoryView
            } else if viewModel.conversationHistory.isEmpty {
                emptyStateView
            } else {
                conversationView
            }
        }
    }

    // MARK: - Loading History View

    private var loadingHistoryView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading conversation...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Chiron")
                        .font(.headline)
                    Text("Your Personal Longevity Guide")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(color.opacity(0.5))

            VStack(spacing: 8) {
                Text("Ask me anything about \(viewName)")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("I can help you understand your health data, explain what your values mean, and provide personalized tips.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Suggested questions (from database or fallback)
            VStack(spacing: 12) {
                Text("Try asking:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(viewModel.suggestedQuestions, id: \.self) { question in
                    Button {
                        viewModel.question = question
                        Task { await viewModel.askQuestion() }
                    } label: {
                        Text(question)
                            .font(.subheadline)
                            .foregroundColor(color)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(color.opacity(0.1))
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    // MARK: - Conversation View

    private var conversationView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.conversationHistory) { message in
                        MessageBubble(message: message, color: color)
                            .id(message.id)
                    }

                    if viewModel.isLoading {
                        HStack {
                            ThinkingIndicator(color: color)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("loading")
                    }

                    if let error = viewModel.error {
                        ErrorBubble(error: error)
                            .id("error")
                    }

                    // Bottom spacer for keyboard
                    Color.clear
                        .frame(height: 8)
                        .id("bottom")
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                // Scroll to bottom when history loads
                if let lastMessage = viewModel.conversationHistory.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: viewModel.conversationHistory.count) { _, _ in
                withAnimation {
                    if let lastMessage = viewModel.conversationHistory.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading {
                    withAnimation {
                        proxy.scrollTo("loading", anchor: .bottom)
                    }
                }
            }
            .onChange(of: isInputFocused) { _, focused in
                if focused, let lastMessage = viewModel.conversationHistory.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Input View (Floating Glass Style)

    private let inputBarHeight: CGFloat = 48

    private var inputView: some View {
        HStack(spacing: 12) {
            // Floating glass input bar
            HStack(spacing: 10) {
                TextField("Ask a question...", text: $viewModel.question, axis: .vertical)
                    .font(.body)
                    .focused($isInputFocused)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .onSubmit {
                        Task { await viewModel.askQuestion() }
                    }

                // Clear text button
                if !viewModel.question.isEmpty {
                    Button {
                        viewModel.question = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: inputBarHeight)
            .background(
                Capsule()
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            )
            .modifier(GlassEffectModifier())

            // Send button - floating glass circle
            Button {
                Task { await viewModel.askQuestion() }
            } label: {
                ZStack {
                    Circle()
                        .fill(canSend ? color : Color.gray.opacity(0.3))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: inputBarHeight, height: inputBarHeight)
                .modifier(GlassEffectModifier())
            }
            .disabled(!canSend || viewModel.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var canSend: Bool {
        !viewModel.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: QAMessage
    let color: Color

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(message.role == .user ? color : Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(18)

                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role == .assistant {
                Spacer()
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Thinking Indicator

struct ThinkingIndicator: View {
    let color: Color
    @State private var animating = false

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(color.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(18)

            Text("Thinking...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Error Bubble

struct ErrorBubble: View {
    let error: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }

                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    EducationQAModal(
        viewId: "DISP_BIO_HDL",
        viewName: "HDL Cholesterol",
        color: .orange
    )
}
