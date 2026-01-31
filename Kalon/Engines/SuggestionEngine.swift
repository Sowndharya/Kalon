//
//  SuggestionEngine.swift
//  Kalon
//
//  Created by Sowndharya Maheswaran on 11/16/25.
//


import Foundation
import Combine

/// Analyzes the historical log data to provide personalized insights and suggestions.
class SuggestionEngine: ObservableObject {

    // 1. INPUT: Receives all DailyLogEntry objects from the DataService
    @Published var logHistory: [DailyLogEntry] = []

    // 2. OUTPUT: A structure to hold the aggregated results for display
    struct HabitInsight: Identifiable {
        let id: String
        let habitName: String
        var consistencyScore: Double? // 0.0 to 1.0
        var quantityDelta: Double? // Avg difference from initial target
        var bestCompletionTime: String? // e.g., "7:30 AM"
        var primarySuggestion: String?
    }

    @Published var insights: [HabitInsight] = []

    // Requires the DataService and HabitDefinitions to function
    private var dataService: MockDataService
    private var cancellables = Set<AnyCancellable>()

    init(dataService: MockDataService) {
        self.dataService = dataService

        // Subscribe to the daily log from the data service
        dataService.$dailyLog
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLog in
                self?.logHistory = newLog
                self?.recalculateInsights() // Trigger analysis whenever log changes
            }
            .store(in: &cancellables)
    }

    // MARK: - Core Analysis Logic

    /// Entry point for all analysis, triggered when log data changes.
    private func recalculateInsights() {
        guard !logHistory.isEmpty else {
            self.insights = []
            return
        }

        var newInsights: [HabitInsight] = []
        let uniqueHabitIds = Set(logHistory.map { $0.habitId })

        for habitId in uniqueHabitIds {
            // Find the habit's definition to get its name and target
            guard let habitDef = dataService.habitDefinitions.first(where: { $0.id == habitId }) else { continue }

            let consistency = calculateConsistency(for: habitId)
            let delta = calculateQuantityDelta(for: habitId, target: habitDef.initialTarget)
            let bestTime = findBestCompletionTime(for: habitId)

            var insight = HabitInsight(
                id: habitId,
                habitName: habitDef.name,
                consistencyScore: consistency,
                quantityDelta: delta,
                bestCompletionTime: bestTime
            )

            // Generate a simple suggestion based on the consistency score (Example of Section 2.A)
            if consistency < 0.5 {
                insight.primarySuggestion = "This habit is inconsistent. Try pairing it with a stronger one!"
            } else if consistency > 0.8 && delta > 2 {
                insight.primarySuggestion = "Fantastic consistency! You're exceeding your goal—try raising your target by 1 unit."
            }

            newInsights.append(insight)
        }

        self.insights = newInsights
    }

    // MARK: LLM Data Preparation

    /// Compiles all relevant analysis into a single, structured string for the LLM prompt.
    /// This is the input the AI Routine Coach will use to generate its natural language advice.
    func generateLLMPromptData() -> String {
        guard !insights.isEmpty else {
            return "No recent habit data available for analysis. Ask the user to log at least a week of habits."
        }

        var promptData = "--- USER PERFORMANCE DATA ---\n"

        for insight in insights {
            let consistencyPercent = String(format: "%.0f%%", insight.consistencyScore ?? 0 * 100)
            let delta = String(format: "%.1f", insight.quantityDelta ?? 0)
            let bestTime = insight.bestCompletionTime ?? "No clear time pattern."

            promptData += "Habit: \(insight.habitName)\n"
            promptData += "  - Consistency: \(consistencyPercent)\n"
            promptData += "  - Avg. Quantity Delta vs. Target: \(delta)\n"
            promptData += "  - Best Success Time Slot: \(bestTime)\n"

            // Add other analysis here (e.g., Cycle Analysis, Habit Chaining)
            // Example of Habit Chaining Analysis (Section 2.B logic)
            if let chainInfo = analyzeHabitChaining(for: insight.id) {
                 promptData += "  - Successful Predecessor: Completed \(chainInfo.predecessorName) led to this habit being done \(String(format: "%.0f%%", chainInfo.successRate * 100)) of the time.\n"
            }
            promptData += "\n"
        }

        return promptData
    }

    // MARK: - Calculation Methods

    /// Calculates the Consistency Score (percentage of completion).
    func calculateConsistency(for habitId: String, days: Int = 30) -> Double {
        let oneMonthAgo = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        let recentLogs = logHistory.filter { entry in
            guard entry.habitId == habitId,
                  let logDate = DateFormatter.logDateFormatter.date(from: entry.dateKey) else { return false }
            return logDate >= oneMonthAgo
        }

        let totalLoggedDays = Double(Set(recentLogs.map { $0.dateKey }).count)
        guard totalLoggedDays > 0 else { return 0.0 }

        let completedLogs = recentLogs.filter { $0.completed }
        let completedDays = Double(Set(completedLogs.map { $0.dateKey }).count)

        return completedDays / totalLoggedDays
    }

    /// Calculates the average difference between quantity actual and initial target.
    func calculateQuantityDelta(for habitId: String, target: Int?) -> Double {
        guard let target = target, target > 0 else { return 0.0 }

        let logs = logHistory.filter { $0.habitId == habitId && $0.completed }
        guard !logs.isEmpty else { return 0.0 }

        let totalDelta = logs.reduce(0) { (sum, entry) -> Int in
            return sum + (entry.quantityActual - target)
        }

        return Double(totalDelta) / Double(logs.count)
    }

    /// Temporal Insight: Identifies the most consistent 30-minute time slot for completion.
    func findBestCompletionTime(for habitId: String) -> String? {
        let completedLogs = logHistory.filter { $0.habitId == habitId && $0.completed }
        guard !completedLogs.isEmpty else { return nil }

        var timeBuckets: [String: Int] = [:]
        let calendar = Calendar.current

        // Group completions into 30-minute buckets (e.g., 07:00, 07:30, 08:00)
        for log in completedLogs {
            let hour = calendar.component(.hour, from: log.completionTime)
            let minute = calendar.component(.minute, from: log.completionTime)

            // Determine the 30-minute bucket start time
            let bucketMinute = (minute < 30) ? 0 : 30

            // Format the bucket key (e.g., "07:30")
            let bucketKey = String(format: "%02d:%02d", hour, bucketMinute)

            timeBuckets[bucketKey, default: 0] += 1
        }

        // Find the bucket with the maximum count
        guard let (bestBucket, maxCount) = timeBuckets.max(by: { $0.value < $1.value }) else { return nil }

        // Ensure there is enough data for this to be meaningful
        if maxCount < 3 { return nil }

        // Convert the "HH:MM" key to a user-friendly time string (e.g., "7:30 AM")
        if let date = DateFormatter.hourMinuteFormatter.date(from: bestBucket) {
            return DateFormatter.displayTimeFormatter.string(from: date)
        }

        return nil
    }

    /// Habit Chaining: Analyzes which preceding habit most often leads to success.
    func analyzeHabitChaining(for habitId: String, days: Int = 30) -> (predecessorName: String, successRate: Double)? {
        let targetLogs = logHistory.filter { $0.habitId == habitId && $0.completed }
        guard !targetLogs.isEmpty else { return nil }

        var predecessorSuccess: [String: (count: Int, total: Int)] = [:]

        // Iterate through all days in the log history
        let uniqueDates = Set(logHistory.map { $0.dateKey })

        for dateKey in uniqueDates {
            let dailyLogs = logHistory.filter { $0.dateKey == dateKey }
                .sorted { $0.completionOrder < $1.completionOrder }

            guard dailyLogs.count > 1 else { continue }

            // Check if the target habit was completed that day
            if let targetIndex = dailyLogs.firstIndex(where: { $0.habitId == habitId && $0.completed }) {

                // Find the habit immediately preceding the target habit
                if targetIndex > 0 {
                    let predecessorLog = dailyLogs[targetIndex - 1]
                    let predecessorId = predecessorLog.habitId

                    // Increment count for the predecessor. We only care if the chain was successful (i.e., the target habit was completed)
                    predecessorSuccess[predecessorId, default: (0, 0)].count += 1
                }
            }

            // We need a way to count the total number of times the predecessor occurred before the target was attempted/possible.
            // For simplicity in this mock, we will just count the overall occurrences of the predecessor being logged.
            // A robust solution requires complex sequencing analysis, so we'll simplify:

            // Just count how many times the target habit was logged, regardless of outcome
            if dailyLogs.contains(where: { $0.habitId == habitId }) {
                for log in dailyLogs where log.habitId != habitId {
                    predecessorSuccess[log.habitId, default: (0, 0)].total += 1
                }
            }
        }

        // Find the predecessor with the highest success rate (completed / total logged)
        var bestPredecessor: (id: String, rate: Double) = ("", 0.0)

        for (id, data) in predecessorSuccess {
            // Avoid division by zero
            guard data.total > 0 else { continue }

            let rate = Double(data.count) / Double(data.total)
            if rate > bestPredecessor.rate {
                bestPredecessor = (id, rate)
            }
        }

        // Convert the ID back to a name for the LLM prompt
        if bestPredecessor.rate > 0.7, // Only report strong correlations
           let predecessorDef = dataService.habitDefinitions.first(where: { $0.id == bestPredecessor.id }) {
            return (predecessorName: predecessorDef.name, successRate: bestPredecessor.rate)
        }

        return nil
    }
}

// MARK: - Date Formatting Helpers

extension DateFormatter {
    // Used to parse the internal bucket key "HH:MM"
    static let hourMinuteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    // Used to display the time slot (e.g., 7:30 AM)
    static let displayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}
