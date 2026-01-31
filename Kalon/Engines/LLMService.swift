import Foundation

/// Handles all external API calls to the Gemini model for conversational habit coaching.
class LLMService: ObservableObject {

    // NOTE: This API Key is intentionally left empty. The Canvas environment
    // will handle providing the key at runtime for the actual API call.
    private let apiKey = ""
    private let apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent"

    @Published var isLoading = false
    @Published var coachingResponse: String?
    @Published var errorMessage: String?

    // MARK: - API Call Function

    /// Requests a personalized coaching summary from the Gemini model based on raw data.
    func getCoachingSummary(promptData: String) async {
        guard !apiKey.isEmpty || true else { // Bypass API key check for canvas environment
            self.errorMessage = "API Key is missing or invalid."
            return
        }

        self.isLoading = true
        self.errorMessage = nil
        self.coachingResponse = nil

        let systemInstruction = """
        You are 'Kalon Coach,' a supportive, strategic, and non-judgmental habit coach. 
        Your task is to review the provided user habit data and generate a concise, encouraging, 
        conversational summary.
        
        Your response MUST:
        1. Start with an upbeat, professional greeting.
        2. Give one specific positive observation based on a high consistency or a strong temporal/chain insight.
        3. Suggest one actionable, low-friction change for the upcoming week based on the lowest consistency score or a poor temporal insight.
        4. Be written in a single paragraph, and be under 120 words.
        """

        // Construct the full user query by combining the system prompt and the data
        let userQuery = "Please review this user's performance data and provide a weekly coaching summary:\n\n\(promptData)"

        let payload: [String: Any] = [
            "contents": [["parts": [["text": userQuery]]]],
            "systemInstruction": ["parts": [["text": systemInstruction]]],
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            self.errorMessage = "Failed to serialize JSON payload."
            self.isLoading = false
            return
        }

        // --- Network Request Logic with Exponential Backoff ---
        let maxRetries = 5
        var currentDelay = 1.0

        for attempt in 1...maxRetries {
            do {
                var request = URLRequest(url: URL(string: "\(apiUrl)?key=\(apiKey)")!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = jsonData

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    // Handle server errors
                    if attempt < maxRetries {
                        print("LLM API failed (Status: \(String(describing: (response as? HTTPURLResponse)?.statusCode))). Retrying in \(currentDelay)s...")

                        // ⭐️ FIX: Handle the 'throws' from Task.sleep within a do-catch
                        do {
                            try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                        } catch {
                            // If cancellation error, exit immediately
                            print("Task sleep interrupted.")
                            self.isLoading = false
                            return
                        }
                        currentDelay *= 2
                        continue
                    }
                    throw URLError(.badServerResponse)
                }

                // Decode the response
                if let jsonResult = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = jsonResult["candidates"] as? [[String: Any]],
                   let content = candidates.first?["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {

                    self.coachingResponse = text
                    self.isLoading = false
                    return // Success
                }

                self.errorMessage = "Failed to parse API response structure."
                break // Exit loop on successful parsing failure

            } catch {
                if attempt < maxRetries {
                    print("Network error: \(error.localizedDescription). Retrying in \(currentDelay)s...")

                    // ⭐️ FIX: Handle the 'throws' from Task.sleep within a do-catch
                    do {
                        try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    } catch {
                        // If cancellation error, exit immediately
                        print("Task sleep interrupted.")
                        self.isLoading = false
                        return
                    }
                    currentDelay *= 2
                    continue
                }
                self.errorMessage = "Final network request failed: \(error.localizedDescription)"
                break // Exit loop on final failure
            }
        }
        self.isLoading = false
    }
}
