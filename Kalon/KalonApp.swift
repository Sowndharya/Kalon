//
//  KalonApp.swift
//  Kalon
//
//  Created by Sowndharya Maheswaran on 10/27/25.
//

import SwiftUI

// NOTE: Ensure DataModels.swift, DataService.swift, SuggestionEngine.swift,
// and LLMService.swift are in your project.

@main
struct KalonApp: App {

    // 1. Core Data: Holds the mock data locally.
    @StateObject var dataService = MockDataService()

    // 2. Logic: Reads from the DataService for analysis.
    // We declare it here but initialize it below.
    @StateObject var suggestionEngine: SuggestionEngine

    // 3. LLM Integration: Handles API calls.
    @StateObject var llmService = LLMService()

    // ⭐️ FIX: Use the custom initializer to inject the dependency.
    // The previous error was a tricky one related to the compiler's strictness
    // on property initialization order. This explicit init is the intended solution.
    init() {
        // Initialize the dependent StateObject by accessing the dataService which
        // is considered initialized before this point.
        let service = MockDataService()
        _dataService = StateObject(wrappedValue: service)

        // Initialize the other StateObjects, relying on 'service' for the dependency.
        _suggestionEngine = StateObject(wrappedValue: SuggestionEngine(dataService: service))
        _llmService = StateObject(wrappedValue: LLMService())
    }

    var body: some Scene {
        WindowGroup {
            // Inject all three core ObservableObjects into the environment.
            ContentView()
                .environmentObject(dataService)
                .environmentObject(suggestionEngine)
                .environmentObject(llmService)
        }
    }
}
