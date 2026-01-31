//
//  ContentView.swift
//  Kalon
//
//  Created by Sowndharya Maheswaran on 10/27/25.
//

import SwiftUI

// NOTE: Assumes DataService, DataModels, SuggestionEngine, LLMService,
// and DateFormatter extension are available.

// MARK: - 1. Main App Shell View

struct ContentView: View {
    // Inject the DataService to read/write habits and logs
    @EnvironmentObject var dataService: MockDataService

    @State private var isShowingHabitAdder = false
    @State private var isLoading = true

    // ⭐️ NEW: State to track the currently selected date
    @State private var selectedDate = Date()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) { // VStack to stack the navigator above the list

                // ⭐️ NEW: Date navigation calendar view
                DateNavigatorView(selectedDate: $selectedDate)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // ⭐️ Refactored: Moved complex list logic into DailyHabitList
                // Pass the selected date down to the list view
                DailyHabitList(isLoading: $isLoading, selectedDate: $selectedDate)

            }
            .navigationTitle("Kalon Daily Habits")
            .navigationBarTitleDisplayMode(.inline) // Keep title compact
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton() // Enables drag-and-drop reordering
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Navigation to the LLM Coaching/Progress View
                    NavigationLink(destination: ProgressTabView()) {
                        Image(systemName: "chart.bar.xaxis")
                    }
                }
            }
            .onAppear {
                Task {
                    await dataService.fetchAllRoutines()
                    isLoading = false
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // Plus button for the Habit Adder
                Button {
                    isShowingHabitAdder = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 55, height: 55)
                        .foregroundColor(.teal)
                        .padding()
                        .shadow(radius: 5)
                }
            }
        }
        .sheet(isPresented: $isShowingHabitAdder) {
            HabitAdderView(dataService: dataService)
        }
        .overlay {
            if isLoading {
                ProgressView("Building Your Day...")
                    .padding()
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(10)
            }
        }
    }
}

// MARK: - 2. Date Navigator View (NEW COMPONENT)

struct DateNavigatorView: View {
    @Binding var selectedDate: Date

    // Helper function to update the date by a certain number of days
    private func changeDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }

    var body: some View {
        HStack {
            // Left Arrow: Go to previous day
            Button {
                changeDate(by: -1)
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundColor(.teal)
            }
            .buttonStyle(.plain)

            Spacer()

            // Current Date Display
            Text(selectedDate, style: .date)
                .font(.title2)
                .fontWeight(.bold)
                .onTapGesture {
                    // Optional: Reset to today's date
                    selectedDate = Date()
                }

            Spacer()

            // Right Arrow: Go to next day
            Button {
                changeDate(by: 1)
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.teal)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 3. Daily Habit List (The List Container)

struct DailyHabitList: View {
    @EnvironmentObject var dataService: MockDataService
    @Binding var isLoading: Bool
    // ⭐️ NEW: Selected Date is now a required binding
    @Binding var selectedDate: Date

    var body: some View {
        List {
            // --- Routine Sections ---
            ForEach(dataService.routines.sorted(by: { $0.order < $1.order })) { routine in

                RoutineHeaderView(routine: routine) {
                    // Action: Delete the routine via the data service
                    dataService.deleteRoutine(routineId: routine.id!)
                } content: {
                    // Delegation to a new view for the inner complexity (compiler fix)
                    // ⭐️ UPDATED: Pass selectedDate down
                    RoutineHabitGroupList(routine: routine, selectedDate: selectedDate)
                }
            }
        }
    }
}

// MARK: - 4. Routine Habit Group List (The Complexity Isolator)

struct RoutineHabitGroupList: View {
    let routine: Routine
    // ⭐️ NEW: Selected Date is now a required property
    let selectedDate: Date
    @EnvironmentObject var dataService: MockDataService

    private var todayDateKey: String {
        // ⭐️ UPDATED: Use the selectedDate for the key, not just Date()
        DateFormatter.logDateFormatter.string(from: selectedDate)
    }

    // This property filters the groups once and holds the result
    private var routineGroups: [HabitGroup] {
        dataService.habitGroups
            .filter { $0.routineId == routine.id! }
            .sorted { $0.order < $1.order }
    }

    var body: some View {
        // Display Habits INLINE based on Habit Group
        ForEach(routineGroups) { group in
            GroupedHabitSection(
                group: group,
                routineId: routine.id!,
                dataService: dataService,
                // ⭐️ UPDATED: Pass the specific date key
                todayDateKey: todayDateKey
            )
        }
    }
}


// MARK: - 5. Routine Header View (Handles Delete Button in Header)

struct RoutineHeaderView<Content: View>: View {
    let routine: Routine
    let onDelete: () -> Void
    let content: () -> Content

    var body: some View {
        Section {
            content()
        } header: {
            // ⭐️ FIX: Added horizontal padding to align the content with the List rows below.
            HStack {
                Text(routine.name)
                    .font(.headline)
                    .textCase(.uppercase)
                Spacer()
                // Delete Button Icon
                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 6. Grouped Habit Section (Handles Nested Groups and Reordering)

struct GroupedHabitSection: View {
    let group: HabitGroup
    let routineId: String
    @ObservedObject var dataService: MockDataService
    let todayDateKey: String

    private var habitsForGroup: [HabitDefinition] {
        // Filters the habits that belong to this specific group and routine combination
        dataService.habitDefinitions.filter { habit in
            let mapping = mockHabitGroupDefinitions[habit.id!] // Uses the mock mapping defined in DataService.swift
            return mapping?.routineId == routineId && mapping?.groupId == group.id
        }
    }

    var body: some View {
        // Nested section for the Habit Group name
        Section(header: Text("  \(group.name)").font(.subheadline).foregroundColor(.secondary)) {
            ForEach(habitsForGroup) { habit in
                HabitRowView(
                    habit: habit,
                    routineId: routineId,
                    dataService: dataService,
                    todayDateKey: todayDateKey
                )
                // Habit Deletion - Enables swipe-to-delete for individual habit rows
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        dataService.deleteHabit(habitId: habit.id!)
                    } label: {
                        Label("Delete Habit", systemImage: "trash.fill")
                    }
                }
            }
            // Enables drag-and-drop reordering for the habits within this group
            .onMove { source, destination in
                dataService.moveHabits(routineId: routineId, from: source, to: destination)
            }
        }
    }
}


// MARK: - 7. Remaining Views (HabitRowView, HabitAdderView, etc.)

struct HabitRowView: View {
    let habit: HabitDefinition
    let routineId: String
    @ObservedObject var dataService: MockDataService
    let todayDateKey: String // Date key for the selected day

    // ⭐️ FIX: Use a combined ID that changes when the date or habit changes. This is key for SwiftUI's redrawing logic.
    private var rowIdentity: String {
        "\(habit.id!)-\(todayDateKey)"
    }

    // Computed property to get the current log entry based on the DateKey
    private var currentLogEntry: DailyLogEntry? {
        dataService.dailyLog.first { $0.habitId == habit.id && $0.dateKey == todayDateKey }
    }

    // Local state variables for UI interaction
    @State private var isCompleted: Bool = false
    @State private var quantityInput: String = ""


    // Consolidated logic for loading state to ensure consistency
    private func loadEntryState() {
        if let entry = currentLogEntry {
            isCompleted = entry.completed
            // Only set quantity if habit is completed to prevent "half-baked" log confusion
            quantityInput = entry.completed ? String(entry.quantityActual) : ""
        } else {
            isCompleted = false
            quantityInput = ""
        }
    }

    var body: some View {
        HStack {
            // Habit Name and Goal (Initial Target)
            VStack(alignment: .leading) {
                Text(habit.name)
                    .font(.headline)
                if let target = habit.initialTarget, habit.type != "boolean" {
                    Text("Goal: \(target) \(habit.unit ?? "")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // Quantity Input (only if not a boolean habit)
            if habit.type != "boolean" {
                TextField("Qty", text: $quantityInput)
                    .keyboardType(.numberPad)
                    .frame(width: 50)
                    .multilineTextAlignment(.trailing)
                    // The quantity input should only be active if the habit is marked complete for that day
                    .disabled(!isCompleted)
                    .onChange(of: quantityInput) { _ in
                        // Save the entry whenever quantity changes (only if completed is true)
                        if isCompleted { saveEntry(isCompleted: true) }
                    }
            }

            // Completion Toggle Button
            Button {
                let newState = !isCompleted
                isCompleted = newState
                // If marking incomplete, clear quantity input for the UI immediately
                if !newState { quantityInput = "" }
                saveEntry(isCompleted: newState)
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(.teal)
                    .font(.title)
            }
            .buttonStyle(PlainButtonStyle())
        }
        // ⭐️ FIX: Crucial Change. Use the combined ID as the watch source.
        .id(rowIdentity) // Forces SwiftUI to completely rebuild the view when habitId or dateKey changes.
        .onAppear {
            // Load state when the view appears (or is rebuilt due to .id change)
            loadEntryState()
        }
        // Fallback sync: Watch the global log count (in case a save operation impacts other logs)
        .onChange(of: dataService.dailyLog.count) { _ in
            loadEntryState()
        }
    }

    private func saveEntry(isCompleted: Bool) {
        let quantity = Int(quantityInput) ?? 0
        // We retrieve the Date object corresponding to the date key for accurate logging
        let dateToLog = DateFormatter.logDateFormatter.date(from: todayDateKey) ?? Date()

        // 1. Determine if we are updating an existing log or creating a new one
        var entry: DailyLogEntry
        if let existing = currentLogEntry {
            entry = existing // Update existing log
        } else {
            // Create a new log entry
            entry = DailyLogEntry(
                id: UUID().uuidString,
                dateKey: todayDateKey, // Use the date from the navigator
                habitId: habit.id!,
                routineId: routineId,
                groupId: "mock_group_id",
                completionTime: dateToLog,
                dayOfMonth: Calendar.current.component(.day, from: dateToLog),
                cycleDay: nil
            )
        }

        // 2. Set the current state
        entry.completed = isCompleted
        // If incomplete, set quantity to 0 in the log (consistent with the app's rules)
        entry.quantityActual = isCompleted ? quantity : 0
        entry.completionTime = dateToLog
        entry.completionOrder = dataService.dailyLog.count + 1 // Simple order increment

        // 3. Commit the change via the MockDataService
        Task { await dataService.saveDailyLogEntry(entry) }
    }
}

// MARK: - 8. Habit Adder View (New Habit Creation)

struct HabitAdderView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var dataService: MockDataService

    // Input Fields
    @State private var habitName: String = ""
    @State private var selectedRoutineId: String? = nil
    @State private var habitType: String = "boolean" // Default to boolean
    @State private var initialTarget: String = ""
    @State private var unit: String = ""
    @State private var selectedGroupId: String? = nil // To select an existing or new group

    let habitTypes = ["boolean", "count", "time"]

    var body: some View {
        NavigationView {
            Form {
                // MARK: Habit Details
                Section("Habit Details") {
                    TextField("Habit Name (e.g., Floss, 10-Min Read)", text: $habitName)
                        .autocorrectionDisabled(true)

                    Picker("Tracking Type", selection: $habitType) {
                        Text("Yes/No (Boolean)").tag("boolean")
                        Text("Count (e.g., Reps, Steps)").tag("count")
                        Text("Time (e.g., Minutes, Seconds)").tag("time")
                    }

                    // Show Quantity/Unit fields only if not boolean
                    if habitType != "boolean" {
                        TextField("Initial Goal Quantity (e.g., 20)", text: $initialTarget)
                            .keyboardType(.numberPad)
                        TextField("Unit (e.g., minutes, breaths)", text: $unit)
                    }
                }

                // MARK: Routine and Group Association
                Section("Association") {
                    // 1. Routine Selection (Mandatory for group selection)
                    Picker("Select Routine", selection: $selectedRoutineId) {
                        Text("None (Standalone)").tag(nil as String?)
                        ForEach(dataService.routines) { routine in
                            Text(routine.name).tag(routine.id as String?)
                        }
                    }

                    // Option to add a new routine
                    NavigationLink("Create New Routine", destination: NewRoutineCreatorView(dataService: dataService, selectedRoutineId: $selectedRoutineId))

                    // 2. Habit Group Selection (Only available if a routine is selected)
                    if let routineId = selectedRoutineId {
                        Picker("Select Habit Group", selection: $selectedGroupId) {
                            Text("None (Ungrouped)").tag(nil as String?)

                            // Filter groups based on the selected routine
                            ForEach(dataService.habitGroups.filter { $0.routineId == routineId }) { group in
                                Text(group.name).tag(group.id as String?)
                            }
                        }

                        // Future: Link to create new group
                        // NavigationLink("Create New Group", destination: NewGroupCreatorView(routineId: routineId, dataService: dataService))
                    }
                }

                // MARK: Save Button
                Button("Save New Habit") {
                    saveNewHabit()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .disabled(habitName.isEmpty)
            }
            .navigationTitle("Add New Habit")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveNewHabit() {
        let newHabitID = UUID().uuidString

        // 1. Create a new habit definition
        let newHabit = HabitDefinition(
            id: newHabitID,
            name: habitName,
            type: habitType,
            unit: habitType == "boolean" ? nil : unit,
            initialTarget: Int(initialTarget)
        )

        // 2. Add the new habit to the MockDataService's definitions list
        dataService.habitDefinitions.append(newHabit)

        // 3. Update the MOCK MAPPING dictionary to include the new habit's association
        // NOTE: This uses the global mock map defined in DataService.swift and is for mock stability only.
        let groupID = selectedGroupId ?? UUID().uuidString // Use a new ID if ungrouped
        let routineID = selectedRoutineId ?? ""

        // Safely insert into the global mock map
        if let existingDefinition = mockHabitGroupDefinitions[newHabitID] {
             // Should not happen for a new habit, but for safety:
             print("Warning: Habit ID already exists in mock map.")
        } else {
             // ⭐️ Requires mockHabitGroupDefinitions to be 'var' in DataService.swift
             mockHabitGroupDefinitions[newHabitID] = (routineId: routineID, groupId: groupID)
             print("New habit '\(newHabit.name)' mapped to Routine:\(routineID), Group:\(groupID)")
        }
    }
}

// MARK: - 9. New Routine Creator View (Simplified)

struct NewRoutineCreatorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var dataService: MockDataService
    @Binding var selectedRoutineId: String? // Pass the new ID back to the adder view

    @State private var routineName: String = ""

    var body: some View {
        Form {
            TextField("Routine Name (e.g., Saturday Chores)", text: $routineName)
                .autocorrectionDisabled(true)

            Button("Create and Select Routine") {
                let newRoutineID = UUID().uuidString
                let newRoutine = Routine(
                    id: newRoutineID,
                    name: routineName,
                    order: dataService.routines.count + 1,
                    isActive: true
                )

                dataService.routines.append(newRoutine)
                selectedRoutineId = newRoutineID // Update the binding
                dismiss() // Go back to the Habit Adder view
            }
            .disabled(routineName.isEmpty)
        }
        .navigationTitle("Create New Routine")
    }
}


// MARK: - 10. Progress View (Simple Placeholder for now)

struct ProgressTabView: View {
    // These need to be injected via EnvironmentObject from KalonApp
    @EnvironmentObject var suggestionEngine: SuggestionEngine
    @EnvironmentObject var llmService: LLMService

    var body: some View {
        // ⭐️ FIX: Rename custom view to CoachingProgressView to avoid conflict with SwiftUI's ProgressView
        CoachingProgressView(engine: suggestionEngine, llmService: llmService)
    }
}


// MARK: - 11. AI Coaching Progress View (The renamed view)

struct CoachingProgressView: View { // ⭐️ FIX: Renamed from ProgressView
    @ObservedObject var engine: SuggestionEngine
    @ObservedObject var llmService: LLMService

    var body: some View {
        NavigationView {
            List {
                Section("AI Routine Coach Summary") {
                    VStack(alignment: .leading, spacing: 10) {

                        if llmService.isLoading {
                            // Using the built-in ProgressView here
                            ProgressView("Generating Coaching Summary...")
                        } else if let response = llmService.coachingResponse {
                            Text(response)
                                .font(.body)
                                .italic()
                        } else if let error = llmService.errorMessage {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                        } else {
                            Text("Ready to review your habits. Log a few more entries to get a meaningful analysis!")
                                .foregroundColor(.secondary)
                        }

                        Button("Get Weekly Coaching Summary") {
                            Task {
                                let promptData = engine.generateLLMPromptData()
                                await llmService.getCoachingSummary(promptData: promptData)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(engine.insights.isEmpty || llmService.isLoading)

                    }
                }

                Section("Raw Habit Insights") {
                    ForEach(engine.insights) { insight in
                        VStack(alignment: .leading) {
                            Text(insight.habitName)
                                .font(.headline)
                            HStack {
                                Text("Consistency:")
                                Spacer()
                                Text(String(format: "%.0f%%", (insight.consistencyScore ?? 0) * 100))
                                    .fontWeight(.medium)
                            }
                            if let time = insight.bestCompletionTime {
                                Text("Best Time: \(time)")
                                    .font(.caption)
                                    .foregroundColor(.teal)
                            }
                            if let suggestion = insight.primarySuggestion {
                                Text("Tip: \(suggestion)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Your Kalon Progress")
        }
    }
}

// MARK: - 12. Date Formatting Helpers (From DataService)

extension DateFormatter {
    static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM-DD"
        return formatter
    }()
}
