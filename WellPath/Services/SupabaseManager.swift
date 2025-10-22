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
        // TODO: Replace with your Supabase project URL and anon key
        client = SupabaseClient(
            supabaseURL: URL(string: "https://YOUR_PROJECT.supabase.co")!,
            supabaseKey: "YOUR_ANON_KEY"
        )
    }
}
