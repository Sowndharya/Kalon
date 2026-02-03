# Kalon: Dynamic Routine Tracking Application ☀️🌙

Kalon is an iOS application developed with SwiftUI for routine management. The system uses hierarchical data structures to organize habits and integrates an LLM-based service to provide summaries of user performance data. It is designed to eventually incorporate physiological data (such as menstrual cycle tracking) to contextualize habit success rates.

## 🚀 Core Features

Hierarchical Routine Management: Habits are organized within Groups, which are contained within top-level Routines (e.g., Morning, Evening).

Quantitative and Qualitative Tracking: Supports boolean (Yes/No), time-based (minutes/seconds), and count-based (reps/units) habit tracking.

LLM Coaching Engine 🤖: An asynchronous service that packages historical log data and sends it to a generative AI model to produce performance summaries.

Date Navigation 📅: A calendar-based navigation system allowing users to view and log data for specific historical or future dates.

Bio-Adaptive Logic: The backend and suggestion engine are structured to handle cycle-day data to analyze how physiological phases impact habit consistency.

## 🛠 Technical Specifications

Language/Framework: Swift 5.10+, SwiftUI.

Architecture: Protocol-Oriented Programming (POP) for data services and MVVM for view state management.

State Management: Utilization of `@StateObject` and `@EnvironmentObject` for dependency injection and global state synchronization.

Networking: URLSession-based implementation for API communication with support for exponential backoff.

Data Layer: A protocol-based data service currently utilizing a `MockDataService` for local state management and reactive updates.

## 🏗 Project Architecture

`DataModels.swift`: Defines Codable structs for Routines, HabitGroups, HabitDefinitions, and DailyLogEntries.

`DataService.swift`: Manages data persistence and retrieval. Includes logic for reordering habits and deleting routines.

`SuggestionEngine.swift`: Processes raw log entries to calculate consistency scores and temporal correlations (best time of day for specific habits).

`LLMService.swift`: Handles JSON serialization and network requests to external generative AI models.

`ContentView.swift`: Modular view components separated to minimize compiler type-checking overhead and improve rendering performance.

## 🏁 Installation and Requirements

Prerequisites

Xcode 15.0 or later.

Target: iOS 17.0 or later.

### Setup

Clone the repository.

Open the project in Xcode.

Verify `LLMService.swift` configuration for API access.

Build for the target device or simulator.

## ⚙️ Technical Implementations

State Synchronization: The application uses unique view identities via the `.id()` modifier to ensure local view state is reset during date navigation, preventing data overlap.

Performance Optimization: Complex List structures are broken into sub-views to stay within Swift compiler complexity limits.

Mock Implementation: The current version uses a synchronous local mock data layer to simulate database interactions.

## 🗺 Roadmap

HealthKit Integration: Direct synchronization with Apple Health for menstrual flow data to automate cycle-day calculations.

Persistent Storage: Transition from in-memory mock data to a persistent database solution.

Statistical Analysis: Visualizing correlations between physiological phases and habit completion metrics.

## 📄 License

Distributed under the Apache License
