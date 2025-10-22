//
//  SupabaseManager.swift
//  WellPath
//
//  Created on 2025-10-22
//

import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://csotzmardnvrpdhlogjm.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNzb3R6bWFyZG52cnBkaGxvZ2ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkzMjQ4MTEsImV4cCI6MjA3NDkwMDgxMX0.Kw5NRNL3uv35HFUaalLMSbXJLBOPXCceexs7Y-4U9S4"
        )
    }
}
