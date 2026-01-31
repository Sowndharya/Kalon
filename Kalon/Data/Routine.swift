//
//  Routine.swift
//  Kalon
//
//  Created by Sowndharya Maheswaran on 10/27/25.
//

import Foundation

// MARK: - Definition Models

/// 1. Top-level container for a collection of habits (e.g., "Morning Routine").
/// Conforms to Codable and Identifiable for SwiftUI use.
struct Routine: Codable, Identifiable {
    // Standard ID for local use, populated by UUID.
    var id: String?

    let name: String
    let order: Int // For display order in the app
    var isActive: Bool = true
}

/// 2. Mid-level organization within a Routine (e.g., "Oral Hygiene Group").
struct HabitGroup: Codable, Identifiable {
    var id: String?

    let name: String
    let order: Int
    let routineId: String // Links this group back to its parent Routine
}

/// 3. The specific, actionable steps (e.g., "Take deep breaths", "Floss").
struct HabitDefinition: Codable, Identifiable {
    var id: String?

    let name: String

    // Defines how the habit is tracked
    let type: String // Must be one of: "time", "count", or "boolean"
    let unit: String? // e.g., "minutes", "breaths", nil for boolean type
    let initialTarget: Int? // The user's starting goal quantity
}


// MARK: - Daily Log Model

/// Stores a single completion entry for a habit on a specific day.
struct DailyLogEntry: Codable, Identifiable {
    var id: String?

    // Contextual References
    let dateKey: String // Date formatted as "YYYY-MM-DD" for efficient querying
    let habitId: String // Reference to the HabitDefinition
    let routineId: String
    let groupId: String

    // Tracking Data
    var completed: Bool = false
    var quantityActual: Int = 0 // The specific amount achieved (e.g., 5 minutes, 20 breaths)
    var completionTime: Date // Standard Swift Date object for logging time of day

    // Temporal Data for Analysis
    var completionOrder: Int = 0 // Sequence completed that day (1st, 2nd, 3rd, etc.)
    let dayOfMonth: Int
    let cycleDay: Int? // Optional: Day of the menstrual cycle
}


