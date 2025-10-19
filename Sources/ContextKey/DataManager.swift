import Foundation
import AppKit

// Note: This was previously called MQTTManager but renamed to DataManager
// since MQTT functionality has been removed
class MQTTManager: NSObject, ObservableObject {
    static let shared = MQTTManager()
    static let fileAccessGrantedNotification = Notification.Name("fileAccessGrantedNotification")
    static let fileAccessErrorNotification = Notification.Name("fileAccessErrorNotification")

    @Published var history: [HistoryItem] = []
    @Published var currentContext: String = ""
    @Published var currentConversation: [HistoryItem.Message] = []

    private let bookmarkKey = "DirectoryBookmark"
    @Published private(set) var hasFileAccess: Bool = false
    private var accessedDirectoryURL: URL?

    var currentDirectoryPath: String {
        accessedDirectoryURL?.path ?? "Not set"
    }

    @Published var llmManager: LLMManager!

    private override init() {
        super.init()
        restoreFileAccess()
    }

    private func restoreFileAccess() {
        if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

                if !isStale && url.startAccessingSecurityScopedResource() {
                    hasFileAccess = true
                    accessedDirectoryURL = url
                    llmManager = LLMManager(mqttManager: self)
                    loadHistory()
                    print("Restored access to directory: \(url.path)")
                    NotificationCenter.default.post(name: MQTTManager.fileAccessGrantedNotification, object: nil, userInfo: ["path": url.path])
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
                            self.llmManager = LLMManager(mqttManager: self)
                            self.loadHistory()
                            print("Granted access to directory: \(url.path)")

                            NotificationCenter.default.post(name: MQTTManager.fileAccessGrantedNotification, object: nil, userInfo: ["path": url.path])
                        }
                    } catch {
                        print("Failed to create bookmark: \(error)")
                        NotificationCenter.default.post(name: MQTTManager.fileAccessErrorNotification, object: nil, userInfo: ["error": error.localizedDescription])
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
            print("No active LLM configuration.")
            completion("Error: No active LLM configuration")
            return
        }

        switch activeConfig.type {
        case .openAI:
            runOpenAILLM(input: combinedInput, config: activeConfig) { response in
                completion(response)
            }
        case .ollama:
            runOllamaLLM(input: combinedInput, config: activeConfig) { response in
                completion(response)
            }
        }
    }

    private func runOpenAILLM(input: String, config: LLMConfiguration, completion: @escaping (String) -> Void) {
        guard let apiKey = config.apiKey, let model = config.model else {
            completion("Error: Invalid OpenAI configuration")
            return
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let messages: [[String: String]] = [
            ["role": "system", "content": "You are a helpful assistant. Use the provided context and conversation history to answer the user's questions."],
            ["role": "user", "content": input]
        ]

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 150
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

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
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(content.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    completion("Error: Invalid response format")
                }
            } catch {
                completion("Error parsing response: \(error.localizedDescription)")
            }
        }
        task.resume()
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
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
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
            ]
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

    deinit {
        if let url = accessedDirectoryURL, hasFileAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
