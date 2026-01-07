//
//  CoachChatSheet.swift
//  WellPath
//
//  Chat interface with the AI Health Coach
//

import SwiftUI

struct CoachChatSheet: View {
    @StateObject private var viewModel = CoachChatViewModel()
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                CoachMessageBubble(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isLoading {
                                HStack {
                                    TypingIndicator()
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input Area
                HStack(spacing: 12) {
                    TextField("Ask Chiron...", text: $messageText)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .cornerRadius(20)
                        .focused($isInputFocused)

                    Button {
                        let text = messageText
                        messageText = ""
                        Task {
                            await viewModel.sendMessage(text)
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundColor(messageText.isEmpty ? .gray : .green)
                    }
                    .disabled(messageText.isEmpty || viewModel.isLoading)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .navigationTitle("Chiron")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadChatHistory()
            }
        }
    }
}

// MARK: - Coach Message Bubble

struct CoachMessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)
            } else {
                // Chiron avatar for coach messages
                ChironAvatar(size: .small, style: .filled)
                    .padding(.top, 4)
            }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.isFromUser ? Color.green : Color(uiColor: .tertiarySystemGroupedBackground))
                    .foregroundColor(message.isFromUser ? .white : .primary)
                    .cornerRadius(16)

                Text(message.formattedTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !message.isFromUser {
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .opacity(index <= dotCount ? 1 : 0.3)
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(16)
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 3
        }
    }
}

// MARK: - Coach Response Model

struct CoachResponse: Codable {
    let message: CoachMessageContent?
}

struct CoachMessageContent: Codable {
    let message: String?
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id: String
    let content: String
    let isFromUser: Bool
    let timestamp: Date

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - Chiron Chat DB Model

struct ChironChatMessage: Codable {
    let chatId: String
    let patientId: String
    let role: String
    let message: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case patientId = "patient_id"
        case role
        case message
        case createdAt = "created_at"
    }
}

// MARK: - Coach Chat ViewModel

@MainActor
class CoachChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false

    private let supabase = SupabaseManager.shared.client

    func loadChatHistory() async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }

        do {
            let chats: [ChironChatMessage] = try await supabase
                .from("patient_chiron_chats")
                .select("*")
                .eq("patient_id", value: userId)
                .order("created_at", ascending: true)
                .limit(50)
                .execute()
                .value

            // Convert to ChatMessage
            messages = chats.map { chat in
                ChatMessage(
                    id: chat.chatId,
                    content: chat.message,
                    isFromUser: chat.role == "user",
                    timestamp: ISO8601DateFormatter().date(from: chat.createdAt) ?? Date()
                )
            }

            // Add welcome if empty
            if messages.isEmpty {
                messages.append(ChatMessage(
                    id: "welcome",
                    content: "Hi! I'm Chiron, your longevity coach. I'm here to help you optimize your healthspan and reach your goals. How can I help you today?",
                    isFromUser: false,
                    timestamp: Date()
                ))
            }

        } catch {
            print("[CoachChat] Error loading history: \(error)")
            // Show welcome on error too
            if messages.isEmpty {
                messages.append(ChatMessage(
                    id: "welcome",
                    content: "Hi! I'm Chiron, your longevity coach. I'm here to help you optimize your healthspan and reach your goals. How can I help you today?",
                    isFromUser: false,
                    timestamp: Date()
                ))
            }
        }
    }

    func sendMessage(_ text: String) async {
        guard let userId = try? await supabase.auth.session.user.id.uuidString else { return }

        let userMessageId = UUID().uuidString

        // Add user message to UI
        let userMessage = ChatMessage(
            id: userMessageId,
            content: text,
            isFromUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)

        // Save user message to DB
        do {
            try await supabase
                .from("patient_chiron_chats")
                .insert([
                    "patient_id": userId,
                    "role": "user",
                    "message": text
                ])
                .execute()
        } catch {
            print("[CoachChat] Error saving user message: \(error)")
        }

        isLoading = true

        do {
            // Call AI health coach
            let response: CoachResponse = try await supabase.functions.invoke(
                "ai-health-coach",
                options: .init(body: [
                    "patient_id": userId,
                    "trigger_type": "user_message",
                    "user_message": text
                ])
            )

            let responseText = response.message?.message ?? "I'm here to help!"

            // Add coach message to UI
            let coachMessage = ChatMessage(
                id: UUID().uuidString,
                content: responseText,
                isFromUser: false,
                timestamp: Date()
            )
            messages.append(coachMessage)

            // Save coach response to DB
            try await supabase
                .from("patient_chiron_chats")
                .insert([
                    "patient_id": userId,
                    "role": "assistant",
                    "message": responseText
                ])
                .execute()

        } catch {
            print("[CoachChat] Error sending message: \(error)")
            // Add error message
            messages.append(ChatMessage(
                id: UUID().uuidString,
                content: "Sorry, I couldn't process that. Please try again.",
                isFromUser: false,
                timestamp: Date()
            ))
        }

        isLoading = false
    }
}

#Preview {
    CoachChatSheet()
}
