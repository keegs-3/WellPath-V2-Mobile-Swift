//
//  PushNotificationService.swift
//  WellPath
//
//  Manages APNs push notification registration and handling
//

import Foundation
import UserNotifications
import UIKit

@MainActor
class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @Published var isAuthorized = false
    @Published var deviceToken: String?

    private let supabase = SupabaseManager.shared.client

    override private init() {
        super.init()
    }

    // MARK: - Request Permission

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                self.isAuthorized = granted
            }

            if granted {
                // Register for remote notifications on main thread
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("[Push] Authorization granted, registering for remote notifications")
            } else {
                print("[Push] Authorization denied")
            }

            return granted
        } catch {
            print("[Push] Authorization error: \(error)")
            return false
        }
    }

    // MARK: - Check Current Status

    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        await MainActor.run {
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Device Token Handling

    func handleDeviceToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString

        print("[Push] Device token received: \(tokenString.prefix(20))...")

        // Register with backend
        Task {
            await registerTokenWithBackend(tokenString)
        }
    }

    func handleTokenError(_ error: Error) {
        print("[Push] Failed to register for remote notifications: \(error)")
    }

    // MARK: - Backend Registration

    private func registerTokenWithBackend(_ token: String) async {
        guard let userId = try? await supabase.auth.session.user.id else {
            print("[Push] No authenticated user, skipping token registration")
            return
        }

        let patientId = userId.uuidString

        // Get device info
        let deviceName = await UIDevice.current.name
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        do {
            // Upsert the token (insert or update on conflict)
            try await supabase
                .from("push_notification_tokens")
                .upsert([
                    "patient_id": patientId,
                    "device_token": token,
                    "platform": "ios",
                    "is_active": "true",
                    "device_name": deviceName,
                    "app_version": appVersion,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ], onConflict: "patient_id, device_token")
                .execute()

            print("[Push] Token registered with backend successfully")

        } catch {
            print("[Push] Failed to register token with backend: \(error)")
        }
    }

    // MARK: - Deactivate Token

    func deactivateCurrentToken() async {
        guard let token = deviceToken,
              let userId = try? await supabase.auth.session.user.id else {
            return
        }

        let patientId = userId.uuidString

        do {
            try await supabase
                .from("push_notification_tokens")
                .update(["is_active": "false", "updated_at": ISO8601DateFormatter().string(from: Date())])
                .eq("patient_id", value: patientId)
                .eq("device_token", value: token)
                .execute()

            print("[Push] Token deactivated")

        } catch {
            print("[Push] Failed to deactivate token: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {

    // Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("[Push] Received notification in foreground: \(userInfo)")

        // Show banner and play sound even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("[Push] User tapped notification: \(userInfo)")

        // Handle the notification action
        Task { @MainActor in
            await handleNotificationTap(userInfo: userInfo)
        }

        completionHandler()
    }

    @MainActor
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) async {
        // Extract notification type and data
        guard let notificationType = userInfo["type"] as? String else {
            return
        }

        switch notificationType {
        case "nudge":
            // Mark nudge as read if nudge_id is provided
            if let nudgeId = userInfo["nudge_id"] as? String {
                await markNudgeAsRead(nudgeId)
            }
            // Navigate to Goals tab
            NotificationCenter.default.post(name: .navigateToGoals, object: nil)

        case "challenge":
            // Navigate to challenge
            NotificationCenter.default.post(name: .navigateToGoals, object: nil)

        case "insight":
            // Navigate to coach chat
            NotificationCenter.default.post(name: .openCoachChat, object: nil)

        default:
            break
        }
    }

    private func markNudgeAsRead(_ nudgeId: String) async {
        do {
            try await supabase
                .from("patient_nudges")
                .update(["read_at": ISO8601DateFormatter().string(from: Date())])
                .eq("nudge_id", value: nudgeId)
                .execute()
        } catch {
            print("[Push] Failed to mark nudge as read: \(error)")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToGoals = Notification.Name("navigateToGoals")
    static let openCoachChat = Notification.Name("openCoachChat")
}
