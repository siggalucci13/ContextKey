import Foundation
import AppKit

// Manages local data storage including conversation history and LLM configurations
class DataManager: NSObject, ObservableObject {
    static let shared = DataManager()
    static let fileAccessGrantedNotification = Notification.Name("fileAccessGrantedNotification")
    static let fileAccessErrorNotification = Notification.Name("fileAccessErrorNotification")

    @Published var history: [HistoryItem] = []
    @Published var currentContext: String = ""
    @Published var currentConversation: [HistoryItem.Message] = []
    @Published var quickWindowPosition: CGPoint?

    private let bookmarkKey = "DirectoryBookmark"
    private let quickWindowPositionKey = "QuickWindowPosition"
    @Published private(set) var hasFileAccess: Bool = false
    private var accessedDirectoryURL: URL?

    var currentDirectoryPath: String {
        accessedDirectoryURL?.path ?? "Not set"
    }

    @Published var llmManager: LLMManager!

    private override init() {
        super.init()
        restoreFileAccess()
        loadQuickWindowPosition()
    }

    func saveQuickWindowPosition(_ position: CGPoint) {
        quickWindowPosition = position
        let dict = ["x": position.x, "y": position.y]
        UserDefaults.standard.set(dict, forKey: quickWindowPositionKey)
    }

    private func loadQuickWindowPosition() {
        if let dict = UserDefaults.standard.dictionary(forKey: quickWindowPositionKey),
           let x = dict["x"] as? CGFloat,
           let y = dict["y"] as? CGFloat {
            quickWindowPosition = CGPoint(x: x, y: y)
        }
    }

    private func restoreFileAccess() {
        if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

                if !isStale && url.startAccessingSecurityScopedResource() {
                    hasFileAccess = true
                    accessedDirectoryURL = url
                    llmManager = LLMManager(dataManager: self)
                    loadHistory()
                    print("Restored access to directory: \(url.path)")
                    NotificationCenter.default.post(name: DataManager.fileAccessGrantedNotification, object: nil, userInfo: ["path": url.path])
                } else {
                    requestFileAccess()
                }
            } catch {
                print("Error resolving bookmark: \(error)")
                requestFileAccess()
            }
        } else {
            requestFileAccess()
        }
    }

    func requestFileAccess() {
        DispatchQueue.main.async {
            let openPanel = NSOpenPanel()
            openPanel.message = "Select the directory to save history and configurations"
            openPanel.prompt = "Choose"
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.allowsMultipleSelection = false

            if openPanel.runModal() == .OK {
                if let url = openPanel.url {
                    do {
                        let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                        UserDefaults.standard.set(bookmarkData, forKey: self.bookmarkKey)

                        if url.startAccessingSecurityScopedResource() {
                            self.hasFileAccess = true
                            self.accessedDirectoryURL = url
                            self.llmManager = LLMManager(dataManager: self)
                            self.loadHistory()
                            print("Granted access to directory: \(url.path)")

                            NotificationCenter.default.post(name: DataManager.fileAccessGrantedNotification, object: nil, userInfo: ["path": url.path])
                        }
                    } catch {
                        print("Failed to create bookmark: \(error)")
                        NotificationCenter.default.post(name: DataManager.fileAccessErrorNotification, object: nil, userInfo: ["error": error.localizedDescription])
                    }
                }
            } else {
                print("User canceled file access request.")
            }
        }
    }

    func getFileURL(for filename: String) -> URL? {
        return accessedDirectoryURL?.appendingPathComponent(filename)
    }

    func saveHistory(_ history: [HistoryItem]) {
        guard let fileURL = getFileURL(for: "history.json") else {
            print("Unable to get history file URL")
            return
        }

        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save history: \(error)")
        }
    }

    func loadHistory() -> [HistoryItem] {
        guard let fileURL = getFileURL(for: "history.json") else {
            print("Unable to get history file URL")
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let loadedHistory = try JSONDecoder().decode([HistoryItem].self, from: data)
            self.history = loadedHistory
            return loadedHistory
        } catch {
            print("Failed to load history: \(error)")
            return []
        }
    }

    func processQuestionWithSelectedLLM(question: String, context: String, completion: @escaping (String) -> Void) {
        let combinedInput = "\(context)\n\nQuestion: \(question)"

        guard let activeConfig = llmManager.activeConfiguration else {
            completion("Error: No active LLM configuration")
            return
        }

        switch activeConfig.type {
        case .ollama:
            runOllamaLLM(input: combinedInput, config: activeConfig) { response in
                completion(response)
            }
        case .custom:
            runCustomAPILLM(input: combinedInput, context: context, question: question, config: activeConfig) { response in
                completion(response)
            }
        }
    }

    private func runOllamaLLM(input: String, config: LLMConfiguration, completion: @escaping (String) -> Void) {
        guard let apiEndpoint = config.apiEndpoint, let model = config.model else {
            completion("Error: Invalid Ollama configuration")
            return
        }

        let url = URL(string: "\(apiEndpoint)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "prompt": input,
            "stream": false
        ]

        do {
            let httpBody = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = httpBody
        } catch {
            completion("Error creating request body: \(error.localizedDescription)")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion("Error: \(error.localizedDescription)")
                return
            }
            guard let data = data else {
                completion("Error: No data received")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let response = json["response"] as? String {
                    completion(response.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    completion("Error: Invalid response format")
                }
            } catch {
                completion("Error parsing response: \(error.localizedDescription)")
            }
        }
        task.resume()
    }

    struct OllamaResponse: Codable {
        let model: String
        let createdAt: String
        let response: String
        let done: Bool

        enum CodingKeys: String, CodingKey {
            case model
            case createdAt = "created_at"
            case response
            case done
        }
    }


    func handleResponse(_ response: String, question: String, context: String) {
        let historyItem = HistoryItem(
            timestamp: Date(),
            initialContext: context,
            conversation: [
                HistoryItem.Message(id: UUID(), content: question, isUser: true),
                HistoryItem.Message(id: UUID(), content: response, isUser: false)
            ],
            configName: llmManager.activeConfiguration?.name,
            modelName: llmManager.activeConfiguration?.model
        )

        DispatchQueue.main.async {
            self.history.append(historyItem)
            self.saveHistory(self.history)
            NotificationCenter.default.post(name: NSNotification.Name("UpdateCurrentAnswer"), object: nil, userInfo: ["question": question, "answer": response])
        }
    }

    func addMessageToCurrentConversation(_ message: HistoryItem.Message) {
        currentConversation.append(message)
    }

    // MARK: - Custom API Implementation

    private func runCustomAPILLM(input: String, context: String, question: String, config: LLMConfiguration, completion: @escaping (String) -> Void) {
        guard let apiEndpoint = config.apiEndpoint,
              let requestTemplate = config.customRequestTemplate,
              let responsePath = config.customResponsePath,
              let httpMethod = config.customHttpMethod else {
            completion("Error: Invalid custom API configuration")
            return
        }

        guard let url = URL(string: apiEndpoint) else {
            completion("Error: Invalid API endpoint URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = httpMethod

        // Parse and apply custom headers
        var hasApiKeyInHeaders = false
        if let headersJSON = config.customHeaders, !headersJSON.isEmpty {
            if let headersData = headersJSON.data(using: .utf8),
               let headers = try? JSONSerialization.jsonObject(with: headersData) as? [String: String] {
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                    // Check if API key is already in headers
                    if key.lowercased() == "x-goog-api-key" ||
                       (key.lowercased() == "authorization" && value.contains(config.apiKey ?? "")) {
                        hasApiKeyInHeaders = true
                    }
                }
            }
        }

        // If API key exists and wasn't added in custom headers, add it automatically
        if let apiKey = config.apiKey, !apiKey.isEmpty, !hasApiKeyInHeaders {
            if apiEndpoint.contains("googleapis.com") {
                request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            } else {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        }

        // Replace {{input}} variable in the request template with the combined input
        // Need to properly escape the input as a JSON string
        let escapedInput = input
            .replacingOccurrences(of: "\\", with: "\\\\")  // Escape backslashes first
            .replacingOccurrences(of: "\"", with: "\\\"")  // Escape quotes
            .replacingOccurrences(of: "\n", with: "\\n")   // Escape newlines
            .replacingOccurrences(of: "\r", with: "\\r")   // Escape carriage returns
            .replacingOccurrences(of: "\t", with: "\\t")   // Escape tabs

        var processedTemplate = requestTemplate
        processedTemplate = processedTemplate.replacingOccurrences(of: "{{input}}", with: escapedInput)

        // Set request body
        if httpMethod != "GET" {
            if let bodyData = processedTemplate.data(using: .utf8) {
                request.httpBody = bodyData
            } else {
                completion("Error: Failed to encode request body")
                return
            }
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion("Error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                completion("Error: No data received")
                return
            }

            // Extract response using JSONPath
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])

                if let json = jsonObject as? [String: Any] {
                    if let extractedText = self.extractValueFromJSON(json, path: responsePath) {
                        completion(extractedText.trimmingCharacters(in: .whitespacesAndNewlines))
                    } else {
                        completion("Error: Failed to extract response using path '\(responsePath)'. Available keys: \(json.keys.joined(separator: ", "))")
                    }
                } else if let _ = jsonObject as? [Any] {
                    completion("Error: Response is an array. Update your JSONPath to handle array responses.")
                } else {
                    completion("Error: Invalid JSON response structure")
                }
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    completion("Error: Response is not valid JSON. Response: \(responseString.prefix(200))...")
                } else {
                    completion("Error parsing response: \(error.localizedDescription)")
                }
            }
        }

        task.resume()
    }

    // Simple JSONPath-like extraction (supports dot notation and array indexing)
    private func extractValueFromJSON(_ json: Any, path: String) -> String? {
        var current: Any = json
        let components = path.components(separatedBy: ".")

        for component in components {
            // Handle array indexing like "choices[0]"
            if component.contains("[") && component.contains("]") {
                let parts = component.components(separatedBy: "[")
                let key = parts[0]
                let indexString = parts[1].replacingOccurrences(of: "]", with: "")

                // First, navigate to the key
                if let dict = current as? [String: Any], let array = dict[key] as? [Any] {
                    if let index = Int(indexString), index < array.count {
                        current = array[index]
                    } else {
                        return nil
                    }
                } else {
                    return nil
                }
            } else {
                // Regular key access
                if let dict = current as? [String: Any], let value = dict[component] {
                    current = value
                } else {
                    return nil
                }
            }
        }

        // Convert final value to string
        if let string = current as? String {
            return string
        } else if let number = current as? NSNumber {
            return number.stringValue
        } else if let bool = current as? Bool {
            return bool ? "true" : "false"
        } else {
            return nil
        }
    }

    deinit {
        if let url = accessedDirectoryURL, hasFileAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
