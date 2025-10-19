import Foundation

enum LLMType: String, Codable, CaseIterable {
    case ollama = "Ollama"
    case custom = "Custom"

    var defaultEndpoint: String {
        switch self {
        case .ollama:
            return "http://localhost:11434"
        case .custom:
            return ""
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .custom:
            return true
        case .ollama:
            return false
        }
    }

    var icon: String {
        switch self {
        case .ollama:
            return "server.rack"
        case .custom:
            return "network"
        }
    }
}

struct LLMConfiguration: Identifiable, Codable {
    let id: String
    var name: String
    var type: LLMType
    var apiKey: String?
    var model: String?
    var apiEndpoint: String?
    var isActive: Bool
    var contextLength: Int? // Context window size in tokens

    // Custom API fields
    var customHeaders: String? // JSON string of headers
    var customRequestTemplate: String? // JSON template with {{variables}}
    var customResponsePath: String? // JSONPath to extract response (e.g., "choices[0].message.content")
    var customHttpMethod: String? // GET, POST, PUT, etc.

    enum CodingKeys: String, CodingKey {
        case id, name, type, apiKey, model, apiEndpoint, isActive, contextLength
        case customHeaders, customRequestTemplate, customResponsePath, customHttpMethod
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unnamed Configuration"
        type = try container.decode(LLMType.self, forKey: .type)
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        apiEndpoint = try container.decodeIfPresent(String.self, forKey: .apiEndpoint)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        contextLength = try container.decodeIfPresent(Int.self, forKey: .contextLength)
        customHeaders = try container.decodeIfPresent(String.self, forKey: .customHeaders)
        customRequestTemplate = try container.decodeIfPresent(String.self, forKey: .customRequestTemplate)
        customResponsePath = try container.decodeIfPresent(String.self, forKey: .customResponsePath)
        customHttpMethod = try container.decodeIfPresent(String.self, forKey: .customHttpMethod)
    }

    init(id: String = UUID().uuidString, name: String, type: LLMType, apiKey: String? = nil, model: String? = nil, apiEndpoint: String? = nil, isActive: Bool = false, contextLength: Int? = nil, customHeaders: String? = nil, customRequestTemplate: String? = nil, customResponsePath: String? = nil, customHttpMethod: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.apiKey = apiKey
        self.model = model
        self.apiEndpoint = apiEndpoint
        self.isActive = isActive
        self.contextLength = contextLength
        self.customHeaders = customHeaders
        self.customRequestTemplate = customRequestTemplate
        self.customResponsePath = customResponsePath
        self.customHttpMethod = customHttpMethod
    }
}

class LLMManager: ObservableObject {
    @Published var configurations: [LLMConfiguration] = []
    @Published var activeConfigurationId: String?

    private var dataManager: DataManager

    static let llmConfigSaveErrorNotification = Notification.Name("llmConfigSaveErrorNotification")

    // Estimate token count (rough approximation: 1 token ≈ 4 characters)
    static func estimateTokenCount(_ text: String) -> Int {
        return text.count / 4
    }

    // Check if context exceeds the model's limit
    func checkContextLimit(text: String, config: LLMConfiguration?) -> (estimated: Int, limit: Int?, exceeds: Bool, warning: String?) {
        let estimatedTokens = LLMManager.estimateTokenCount(text)

        guard let contextLimit = config?.contextLength else {
            return (estimatedTokens, nil, false, nil)
        }

        let exceeds = estimatedTokens > contextLimit
        let warning: String? = exceeds ? "Context (~\(estimatedTokens.formatted()) tokens) exceeds model limit of \(contextLimit.formatted()) tokens. Content may be truncated." : nil

        return (estimatedTokens, contextLimit, exceeds, warning)
    }

    init(dataManager: DataManager) {
        self.dataManager = dataManager
        loadConfigurations()
    }

    func addConfiguration(_ configuration: LLMConfiguration) {
        configurations.append(configuration)
        if configurations.count == 1 {
            activeConfigurationId = configuration.id
        }
        saveConfigurations()
    }

    func updateConfiguration(_ oldConfig: LLMConfiguration, with newConfig: LLMConfiguration) {
        if let index = configurations.firstIndex(where: { $0.id == oldConfig.id }) {
            configurations[index] = newConfig

            if oldConfig.isActive {
                activeConfigurationId = newConfig.id
                configurations[index].isActive = true
            }

            saveConfigurations()
        }
    }

    func removeConfiguration(_ configuration: LLMConfiguration) {
        configurations.removeAll { $0.id == configuration.id }
        if activeConfigurationId == configuration.id {
            activeConfigurationId = configurations.first?.id
        }
        saveConfigurations()
    }

    func setActiveConfiguration(_ configuration: LLMConfiguration) {
        if let activeIndex = configurations.firstIndex(where: { $0.isActive }) {
            configurations[activeIndex].isActive = false
        }

        if let index = configurations.firstIndex(where: { $0.id == configuration.id }) {
            configurations[index].isActive = true
            activeConfigurationId = configuration.id
        }

        saveConfigurations()
    }

    var activeConfiguration: LLMConfiguration? {
        configurations.first { $0.id == activeConfigurationId }
    }

    // Fetch available models from Ollama
    func fetchOllamaModels(from endpoint: String, completion: @escaping ([String]) -> Void) {
        guard let url = URL(string: "\(endpoint)/api/tags") else {
            completion([])
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let models = json["models"] as? [[String: Any]] {
                    let modelNames = models.compactMap { $0["name"] as? String }
                    DispatchQueue.main.async {
                        completion(modelNames)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }

        task.resume()
    }

    // Fetch Ollama model info (context_length) using CLI
    func fetchOllamaModelInfo(endpoint: String, modelName: String, completion: @escaping (Int?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
            process.arguments = ["show", modelName]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.lowercased().contains("context length") {
                            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                            if components.count >= 3, let contextLength = Int(components.last ?? "") {
                                DispatchQueue.main.async {
                                    completion(contextLength)
                                }
                                return
                            }
                        }
                    }

                    DispatchQueue.main.async {
                        completion(nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }

    private func saveConfigurations() {
        guard let fileURL = dataManager.getFileURL(for: "llm_configurations.json") else {
            return
        }

        do {
            let data = try JSONEncoder().encode(configurations)
            try data.write(to: fileURL)

            if let activeConfigFileURL = dataManager.getFileURL(for: "active_config.json") {
                let activeConfigData = try JSONEncoder().encode(activeConfigurationId)
                try activeConfigData.write(to: activeConfigFileURL)
            }
        } catch {
            NotificationCenter.default.post(name: LLMManager.llmConfigSaveErrorNotification, object: nil, userInfo: ["error": error])
        }
    }

    private func loadConfigurations() {
        guard let fileURL = dataManager.getFileURL(for: "llm_configurations.json") else {
            return
        }

        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                configurations = try JSONDecoder().decode([LLMConfiguration].self, from: data)

                if let activeConfigFileURL = dataManager.getFileURL(for: "active_config.json"),
                   FileManager.default.fileExists(atPath: activeConfigFileURL.path),
                   let activeConfigData = try? Data(contentsOf: activeConfigFileURL) {
                    activeConfigurationId = try JSONDecoder().decode(String.self, from: activeConfigData)
                }
            } else {
                configurations = []
                activeConfigurationId = nil
            }
        } catch {
            configurations = []
            activeConfigurationId = nil
        }
    }
}
