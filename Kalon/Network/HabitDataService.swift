//
//  HabitDataService.swift
//  Kalon
//
//  Created by Sowndharya Maheswaran on 10/27/25.
//

import Foundation
import Combine
// NOTE: The data models (Routine, HabitDefinition, DailyLogEntry) are assumed to be available
// and conform to Identifiable and Codable protocols.

// MARK: - 1. Protocol Definition (The Contract)

/// Defines the contract for all data operations, allowing us to swap between
/// local Mock data and external database implementations seamlessly.
protocol HabitDataService: ObservableObject {
    // Publishers to stream real-time data to SwiftUI views
    var routines: [Routine] { get }
    var habitDefinitions: [HabitDefinition] { get }
    var dailyLog: [DailyLogEntry] { get }
    var habitGroups: [HabitGroup] { get }

    // Asynchronous Functions
    func fetchAllRoutines() async
    func saveDailyLogEntry(_ entry: DailyLogEntry) async
    func getHabits(for routineId: String) -> [HabitDefinition]

    // ⭐️ NEW: Management Functions
    func deleteRoutine(routineId: String)
    func moveHabits(routineId: String, from source: IndexSet, to destination: Int)
    func deleteHabit(habitId: String) // ⭐️ ADDED: Delete Habit function

    // Future: func authenticate() async throws -> String
}

// MARK: - 2. Mock Implementation (For Local Development)

/// A concrete implementation of HabitDataService using hardcoded local data.
/// This is used to build the UI and test logic before connecting to a live database.
class MockDataService: HabitDataService {

    // Observable Properties using @Published to mimic real-time updates
    @Published var routines: [Routine] = []
    @Published var habitDefinitions: [HabitDefinition] = []
    @Published var dailyLog: [DailyLogEntry] = []
    @Published var habitGroups: [HabitGroup] = []

    init() {
        // Load initial mock data upon initialization
        self.routines = mockRoutines
        self.habitDefinitions = mockHabits
        self.dailyLog = mockLogEntries
        self.habitGroups = mockHabitGroups
    }

    // MARK: Public Protocol Functions

    // Since this is mock data, we just use a tiny delay to simulate a network call
    func fetchAllRoutines() async {
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        self.routines = mockRoutines.sorted { $0.order < $1.order }
    }

    func saveDailyLogEntry(_ entry: DailyLogEntry) async {
        // Find if an entry for this habit on this day already exists
        if let index = dailyLog.firstIndex(where: { $0.habitId == entry.habitId && $0.dateKey == entry.dateKey }) {
            // Update existing entry
            dailyLog[index] = entry
            print("Mock: Updated log entry for \(entry.habitId) on \(entry.dateKey)")
        } else {
            // Add new entry
            var newEntry = entry
            // In a real database, the DB would assign the ID, here we use a UUID
            newEntry.id = UUID().uuidString
            dailyLog.append(newEntry)
            print("Mock: Added new log entry for \(newEntry.habitId) on \(newEntry.dateKey)")
        }
    }

    func getHabits(for routineId: String) -> [HabitDefinition] {
        // ⭐️ IMPORTANT: This mock logic is simple. In a real app, you would filter based on
        // a property in HabitDefinition that links back to the Routine.
        return habitDefinitions
            .sorted { $0.name < $1.name }
    }

    // ⭐️ NEW: Function to delete a routine
    func deleteRoutine(routineId: String) {
        // Remove the routine
        self.routines.removeAll { $0.id == routineId }
        // Clean up associated habits and groups (important for data integrity)
        self.habitGroups.removeAll { $0.routineId == routineId }
        // We must also remove the mock definition map entries
        let habitsToDelete = mockHabitGroupDefinitions.filter { $0.value.routineId == routineId }.keys
        habitsToDelete.forEach { mockHabitGroupDefinitions.removeValue(forKey: $0) }

        self.habitDefinitions.removeAll { habit in
            return mockHabitGroupDefinitions[habit.id!]?.routineId == routineId
        }
        print("Mock: Deleted routine \(routineId) and associated data.")
    }

    // ⭐️ NEW: Function to move habits within a list
    func moveHabits(routineId: String, from source: IndexSet, to destination: Int) {
        // WARNING: Moving habits in a flat list is complex because habits are currently
        // organized by HabitGroup in the display. We need a way to track habit order.
        //
        // For now, in this Mock, we will only allow moving the definitions array,
        // which will simulate the reordering effect visually on the list.
        self.habitDefinitions.move(fromOffsets: source, toOffset: destination)
        print("Mock: Reordered habit definitions.")
    }

    // ⭐️ NEW: Implementation for deleting a specific habit
    func deleteHabit(habitId: String) {
        self.habitDefinitions.removeAll { $0.id == habitId }
        mockHabitGroupDefinitions.removeValue(forKey: habitId)
        print("Mock: Deleted habit \(habitId).")
    }
}

// MARK: - Date Formatting Helper FIX

extension DateFormatter {
    static let mockDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // ⭐️ CRITICAL FIX: Changed 'YYYY' to 'yyyy' for reliable year formatting.
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}


// MARK: - Mock Data Generation

let mockRoutineMorningID = UUID().uuidString
let mockRoutineEveningID = UUID().uuidString

let mockHabitGroupOralID = UUID().uuidString
let mockHabitGroupMeditID = UUID().uuidString

// A. Mock Routine Definitions
let mockRoutines: [Routine] = [
    Routine(id: mockRoutineMorningID, name: "☀️ Morning Routine", order: 1, isActive: true),
    Routine(id: mockRoutineEveningID, name: "🌙 Evening Routine", order: 2, isActive: true)
]

// ⭐️ NEW: Mock Habit Groups
let mockHabitGroups: [HabitGroup] = [
    HabitGroup(id: mockHabitGroupOralID, name: "Oral Hygiene", order: 1, routineId: mockRoutineMorningID),
    HabitGroup(id: mockHabitGroupMeditID, name: "Mindfulness", order: 2, routineId: mockRoutineMorningID),
    HabitGroup(id: UUID().uuidString, name: "Wind Down", order: 1, routineId: mockRoutineEveningID)
]

// B. Mock Habit Definitions
let mockHabits: [HabitDefinition] = [
    HabitDefinition(id: UUID().uuidString, name: "Brush Teeth", type: "time", unit: "minutes", initialTarget: 2), // ID 1
    HabitDefinition(id: UUID().uuidString, name: "Floss", type: "boolean", unit: nil, initialTarget: 0), // ID 2
    HabitDefinition(id: UUID().uuidString, name: "Tongue Clean", type: "boolean", unit: nil, initialTarget: 0), // ID 3
    HabitDefinition(id: UUID().uuidString, name: "Deep Breaths", type: "count", unit: "breaths", initialTarget: 10), // ID 4
    HabitDefinition(id: UUID().uuidString, name: "Sit Quietly", type: "time", unit: "minutes", initialTarget: 5), // ID 5
    HabitDefinition(id: UUID().uuidString, name: "Read Fiction", type: "time", unit: "minutes", initialTarget: 30), // ID 6
    HabitDefinition(id: UUID().uuidString, name: "Prep Clothes for Tomorrow", type: "boolean", unit: nil, initialTarget: 0) // ID 7
]

// ⭐️ FIX: Changed from 'let' to 'var' to allow new habit mappings in HabitAdderView
var mockHabitGroupDefinitions: [String: (routineId: String, groupId: String)] = [
    mockHabits[0].id!: (mockRoutineMorningID, mockHabitGroupOralID),
    mockHabits[1].id!: (mockRoutineMorningID, mockHabitGroupOralID),
    mockHabits[2].id!: (mockRoutineMorningID, mockHabitGroupOralID),
    mockHabits[3].id!: (mockRoutineMorningID, mockHabitGroupMeditID),
    mockHabits[4].id!: (mockRoutineMorningID, mockHabitGroupMeditID),
    mockHabits[5].id!: (mockRoutineEveningID, mockHabitGroups[2].id!),
    mockHabits[6].id!: (mockRoutineEveningID, mockHabitGroups[2].id!)
]

// C. Mock Log Entries (for yesterday - updated to use new IDs)
let yesterdayDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
let yesterdayDateKey = DateFormatter.mockDateFormatter.string(from: yesterdayDate)

let mockLogEntries: [DailyLogEntry] = [
    DailyLogEntry(
        id: UUID().uuidString,
        dateKey: yesterdayDateKey,
        habitId: mockHabits[0].id!,
        routineId: mockRoutineMorningID,
        groupId: mockHabitGroupOralID,
        completed: true,
        quantityActual: 2,
        completionTime: Calendar.current.date(bySettingHour: 7, minute: 15, second: 0, of: yesterdayDate)!,
        completionOrder: 1,
        dayOfMonth: Calendar.current.component(.day, from: yesterdayDate),
        cycleDay: nil
    ),
    DailyLogEntry(
        id: UUID().uuidString,
        dateKey: yesterdayDateKey,
        habitId: mockHabits[3].id!,
        routineId: mockRoutineMorningID,
        groupId: mockHabitGroupMeditID,
        completed: true,
        quantityActual: 8,
        completionTime: Calendar.current.date(bySettingHour: 7, minute: 40, second: 0, of: yesterdayDate)!,
        completionOrder: 2,
        dayOfMonth: Calendar.current.component(.day, from: yesterdayDate),
        cycleDay: 10
    )
]
