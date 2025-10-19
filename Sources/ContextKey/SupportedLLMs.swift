import Foundation

enum LLMType: String, Codable, CaseIterable {
    case openAI = "OpenAI"
    case ollama = "Ollama"
}

struct LLMConfiguration: Identifiable, Codable {
    let id: String
    var name: String
    var type: LLMType
    var apiKey: String?
    var model: String?
    var apiEndpoint: String?
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, type, apiKey, model, apiEndpoint, isActive
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
    }

    init(id: String = UUID().uuidString, name: String, type: LLMType, apiKey: String? = nil, model: String? = nil, apiEndpoint: String? = nil, isActive: Bool = false) {
        self.id = id
        self.name = name
        self.type = type
        self.apiKey = apiKey
        self.model = model
        self.apiEndpoint = apiEndpoint
        self.isActive = isActive
    }
}

class LLMManager: ObservableObject {
    @Published var configurations: [LLMConfiguration] = []
      @Published var activeConfigurationId: String?

      private var mqttManager: MQTTManager
      
      static let llmConfigSaveErrorNotification = Notification.Name("llmConfigSaveErrorNotification")

      init(mqttManager: MQTTManager) {
          self.mqttManager = mqttManager
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
            // Deactivate the currently active configuration
            if let activeIndex = configurations.firstIndex(where: { $0.isActive }) {
                configurations[activeIndex].isActive = false
            }
            
            // Activate the new configuration
            if let index = configurations.firstIndex(where: { $0.id == configuration.id }) {
                configurations[index].isActive = true
                activeConfigurationId = configuration.id
            }
            
            saveConfigurations()
        }

    var activeConfiguration: LLMConfiguration? {
        configurations.first { $0.id == activeConfigurationId }
    }

    

      private func saveConfigurations() {
          guard let fileURL = mqttManager.getFileURL(for: "llm_configurations.json") else {
              print("Unable to get configurations file URL")
              return
          }

          do {
              let data = try JSONEncoder().encode(configurations)
              try data.write(to: fileURL)
              
              // Save the active configuration ID
              if let activeConfigFileURL = mqttManager.getFileURL(for: "active_config.json") {
                  let activeConfigData = try JSONEncoder().encode(activeConfigurationId)
                  try activeConfigData.write(to: activeConfigFileURL)
              }
          } catch {
              print("Failed to save configurations: \(error)")
              NotificationCenter.default.post(name: LLMManager.llmConfigSaveErrorNotification, object: nil, userInfo: ["error": error])
          }
      }

      private func loadConfigurations() {
          guard let fileURL = mqttManager.getFileURL(for: "llm_configurations.json") else {
              print("Unable to get configurations file URL")
              return
          }

          do {
              if FileManager.default.fileExists(atPath: fileURL.path) {
                  let data = try Data(contentsOf: fileURL)
                  configurations = try JSONDecoder().decode([LLMConfiguration].self, from: data)
                  
                  // Load the active configuration ID
                  if let activeConfigFileURL = mqttManager.getFileURL(for: "active_config.json"),
                     FileManager.default.fileExists(atPath: activeConfigFileURL.path),
                     let activeConfigData = try? Data(contentsOf: activeConfigFileURL) {
                      activeConfigurationId = try JSONDecoder().decode(String.self, from: activeConfigData)
                  }
              } else {
                  print("Configurations file does not exist. Starting with empty configurations.")
                  configurations = []
                  activeConfigurationId = nil
              }
          } catch {
              print("Failed to load configurations: \(error)")
              configurations = []
              activeConfigurationId = nil
          }
      }
}
