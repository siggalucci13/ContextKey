import SwiftUI
import Carbon

struct SettingsView: View {
    @ObservedObject var llmManager: LLMManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var dataManager: DataManager
    @ObservedObject var themeManager = ColorSchemeManager.shared
    @State private var editingConfiguration: LLMConfiguration?
    @State private var showingAddModal = false
    @State private var showingDeleteAlert = false
    @State private var configToDelete: LLMConfiguration?
    @State private var selectedTab = 0
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.text)
                Spacer()
            }
            .padding()
            .background(themeManager.background)

            Divider()
                .background(themeManager.divider)

            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("Configurations").tag(0)
                Text("Hotkeys").tag(1)
                Text("Folder").tag(2)
                Text("Appearance").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()
                .background(themeManager.divider)

            // Tab content
            Group {
                if selectedTab == 0 {
                    llmConfigView
                } else if selectedTab == 1 {
                    hotkeyConfigView
                } else if selectedTab == 2 {
                    folderSelectionView
                } else if selectedTab == 3 {
                    appearanceView
                }
            }
            .alert(isPresented: $showingDeleteAlert) {
                Alert(
                    title: Text("Delete Configuration"),
                    message: Text("Are you sure you want to delete this configuration?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let config = configToDelete {
                            llmManager.removeConfiguration(config)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .frame(width: 600, height: 550)
        .background(themeManager.background)
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
    }

    var folderSelectionView: some View {
        VStack(spacing: 20) {
            Text("Chat History Location")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.text)

            Divider()
                .background(themeManager.divider)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Location")
                        .font(.headline)
                        .foregroundColor(themeManager.text)

                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                            .font(.title3)

                        Text(dataManager.currentDirectoryPath)
                            .foregroundColor(themeManager.secondaryText)
                            .font(.system(size: 13))
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeManager.secondaryBackground)
                    .cornerRadius(8)
                }

                Button(action: {
                    dataManager.requestFileAccess()
                }) {
                    HStack {
                        Image(systemName: "folder.badge.gearshape")
                        Text("Change Folder Location")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text("About Chat History")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(themeManager.text)

                    Text("All your conversations are saved as a JSON file in this location. Changing the folder will not move existing history.")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer()
        }
        .padding()
        .background(themeManager.background)
    }

    var appearanceView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Appearance")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.text)

            Divider()
                .background(themeManager.divider)

            VStack(alignment: .leading, spacing: 16) {
                // Theme Toggle
                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme")
                        .font(.headline)
                        .foregroundColor(themeManager.text)

                    HStack(spacing: 16) {
                        // Light Mode Button
                        Button(action: {
                            themeManager.isDarkMode = false
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .frame(height: 80)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(themeManager.isDarkMode ? Color.gray.opacity(0.3) : Color.blue, lineWidth: themeManager.isDarkMode ? 1 : 3)
                                        )

                                    VStack(spacing: 4) {
                                        Image(systemName: "sun.max.fill")
                                            .font(.title)
                                            .foregroundColor(.orange)
                                        Text("Aa")
                                            .font(.caption)
                                            .foregroundColor(.black)
                                    }
                                }

                                Text("Light")
                                    .font(.subheadline)
                                    .fontWeight(themeManager.isDarkMode ? .regular : .semibold)
                                    .foregroundColor(themeManager.text)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Dark Mode Button
                        Button(action: {
                            themeManager.isDarkMode = true
                        }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.black)
                                        .frame(height: 80)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(themeManager.isDarkMode ? Color.blue : Color.gray.opacity(0.3), lineWidth: themeManager.isDarkMode ? 3 : 1)
                                        )

                                    VStack(spacing: 4) {
                                        Image(systemName: "moon.fill")
                                            .font(.title)
                                            .foregroundColor(.blue)
                                        Text("Aa")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                }

                                Text("Dark")
                                    .font(.subheadline)
                                    .fontWeight(themeManager.isDarkMode ? .semibold : .regular)
                                    .foregroundColor(themeManager.text)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        Spacer()
                    }
                }

                Divider()
                    .background(themeManager.divider)

                // Preview Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(themeManager.text)

                    VStack(spacing: 12) {
                        // Preview of user message
                        HStack {
                            Spacer()
                            Text("This is a user message")
                                .padding(10)
                                .background(themeManager.userMessageBackground)
                                .foregroundColor(themeManager.userMessageText)
                                .cornerRadius(15)
                        }

                        // Preview of assistant message (no bubble)
                        HStack {
                            Text("This is an assistant message")
                                .foregroundColor(themeManager.text)
                            Spacer()
                        }
                    }
                    .padding(12)
                    .background(themeManager.secondaryBackground.opacity(0.5))
                    .cornerRadius(8)
                }
            }

            Spacer()
        }
        .padding()
        .background(themeManager.background)
    }

    var llmConfigView: some View {
        VStack {
            List {
                ForEach(llmManager.configurations) { config in
                    HStack {
                        Button(action: {
                            llmManager.setActiveConfiguration(config)
                        }) {
                            Image(systemName: config.isActive ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(config.isActive ? .green : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(config.name)
                                .font(.headline)
                                .foregroundColor(themeManager.text)
                            Text(config.model ?? "No model specified")
                                .font(.subheadline)
                                .foregroundColor(themeManager.secondaryText)
                            if let contextLength = config.contextLength {
                                Text("Context: \(contextLength.formatted()) tokens")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }

                        Spacer()

                        Button(action: {
                            editingConfiguration = config
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(themeManager.text)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            configToDelete = config
                            showingDeleteAlert = true
                        }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.red)
                    }
                    .listRowBackground(themeManager.background)
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .background(themeManager.background)

            Button(action: { showingAddModal = true }) {
                Text("Add New Configuration")
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .background(themeManager.background)
        .sheet(item: $editingConfiguration) { config in
            ConfigurationEditView(llmManager: llmManager, configuration: config)
        }
        .sheet(isPresented: $showingAddModal) {
            AddConfigurationView(llmManager: llmManager)
        }
    }

    var hotkeyConfigView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Global Hotkeys")
                    .font(.headline)
                    .foregroundColor(themeManager.text)

                // Side-by-side layout for both hotkeys
                HStack(spacing: 16) {
                    // First hotkey - Copy & Open
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Copy & Open")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.text)

                        Text(getHotkeyDisplayString())
                            .font(.title3)
                            .foregroundColor(themeManager.text)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(themeManager.secondaryBackground)
                            .cornerRadius(6)

                        CompactHotkeyRecorderField(
                            hotkeyManager: hotkeyManager,
                            onSave: { keyCode, modifiers in
                                hotkeyManager.updateHotkey(keyCode, modifiers: modifiers)
                            }
                        )

                        Text("Copies selection & opens with context")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(themeManager.secondaryBackground.opacity(0.5))
                    .cornerRadius(8)

                    // Second hotkey - Quick Open
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Open")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.text)

                        Text(getQuickWindowHotkeyDisplayString())
                            .font(.title3)
                            .foregroundColor(themeManager.text)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(themeManager.secondaryBackground)
                            .cornerRadius(6)

                        CompactQuickWindowHotkeyRecorderField(
                            hotkeyManager: hotkeyManager,
                            onSave: { keyCode, modifiers in
                                hotkeyManager.updateQuickWindowHotkey(keyCode, modifiers: modifiers)
                            }
                        )

                        Text("Opens window without context")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(themeManager.secondaryBackground.opacity(0.5))
                    .cornerRadius(8)
                }

                Spacer()
            }
            .padding()
        }
        .background(themeManager.background)
    }

    private func getHotkeyDisplayString() -> String {
        var modifierString = ""

        if hotkeyManager.currentModifiers & UInt32(cmdKey) != 0 {
            modifierString += "⌘"
        }
        if hotkeyManager.currentModifiers & UInt32(shiftKey) != 0 {
            modifierString += "⇧"
        }
        if hotkeyManager.currentModifiers & UInt32(optionKey) != 0 {
            modifierString += "⌥"
        }
        if hotkeyManager.currentModifiers & UInt32(controlKey) != 0 {
            modifierString += "⌃"
        }

        let keyString = keyCodeToString(hotkeyManager.currentHotkey)
        return "\(modifierString)\(keyString)"
    }

    private func getQuickWindowHotkeyDisplayString() -> String {
        var modifierString = ""

        if hotkeyManager.quickWindowModifiers & UInt32(cmdKey) != 0 {
            modifierString += "⌘"
        }
        if hotkeyManager.quickWindowModifiers & UInt32(shiftKey) != 0 {
            modifierString += "⇧"
        }
        if hotkeyManager.quickWindowModifiers & UInt32(optionKey) != 0 {
            modifierString += "⌥"
        }
        if hotkeyManager.quickWindowModifiers & UInt32(controlKey) != 0 {
            modifierString += "⌃"
        }

        let keyString = keyCodeToString(hotkeyManager.quickWindowHotkey)
        return "\(modifierString)\(keyString)"
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        default: return "?"
        }
    }
}

struct AddConfigurationView: View {
    @ObservedObject var llmManager: LLMManager
    @ObservedObject var themeManager = ColorSchemeManager.shared
    @State private var name: String = ""
    @State private var type: LLMType = .ollama
    @State private var apiKey: String = ""
    @State private var model: String = ""
    @State private var customModel: String = ""
    @State private var apiEndpoint: String = ""
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false
    @State private var useCustomModel = false
    @State private var ollamaInstalled = false
    @State private var checkingOllama = true
    @State private var showModelPullSheet = false
    @State private var modelToPull = ""
    @State private var isPullingModel = false
    @State private var pullProgress = ""

    // Custom API fields
    @State private var customHeaders: String = ""
    @State private var customRequestTemplate: String = ""
    @State private var customResponsePath: String = ""
    @State private var customHttpMethod: String = "POST"
    @State private var customContextLength: Int? = nil

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    nameSection
                    providerTypeSection

                    if type == .ollama {
                        // Ollama-specific fields
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Endpoint")
                                .font(.headline)
                                .foregroundColor(themeManager.text)
                            TextField("API Endpoint", text: $apiEndpoint)
                                .textFieldStyle(.roundedBorder)
                            Text("Default: \(type.defaultEndpoint)")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryText)
                        }

                        HStack {
                            Button(action: fetchOllamaModels) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Fetch Models")
                                }
                            }
                            .disabled(isLoadingModels || checkingOllama)

                            if !ollamaInstalled && !checkingOllama {
                                Text("⚠️ Ollama not detected")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }

                            Spacer()

                            Button(action: {
                                showModelPullSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle")
                                    Text("Download Model")
                                }
                            }
                            .disabled(checkingOllama || !ollamaInstalled)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Model")
                                .font(.headline)
                                .foregroundColor(themeManager.text)

                            if !availableModels.isEmpty {
                                Picker("Model", selection: $model) {
                                    Text("Select a model...").tag("")
                                    ForEach(availableModels, id: \.self) { modelName in
                                        Text(modelName)
                                            .foregroundColor(themeManager.text)
                                            .tag(modelName)
                                    }
                                }
                                .labelsHidden()
                                .foregroundColor(themeManager.text)

                                Text("Showing your installed Ollama models")
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryText)
                            } else if availableModels.isEmpty && !isLoadingModels {
                                Text("No models found. Click 'Fetch Models' above or install models using: ollama pull <model-name>")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(8)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(4)

                                TextField("Enter model name manually", text: $customModel)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    } else if type == .custom {
                        // Custom API fields
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Key")
                                .font(.headline)
                                .foregroundColor(themeManager.text)
                            SecureField("Enter your API key if required", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Endpoint")
                                .font(.headline)
                                .foregroundColor(themeManager.text)
                            TextField("https://api.example.com/v1/chat", text: $apiEndpoint)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Context Length (Optional)")
                                .font(.headline)
                                .foregroundColor(themeManager.text)
                            TextField("e.g., 8192", value: $customContextLength, format: .number)
                                .textFieldStyle(.roundedBorder)
                            Text("Maximum number of tokens the model can handle")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryText)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            Divider()
                                .background(themeManager.divider)

                            Text("Request Configuration")
                                .font(.headline)
                                .foregroundColor(themeManager.text)

                            // HTTP Method
                            VStack(alignment: .leading, spacing: 8) {
                                Text("HTTP Method")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(themeManager.text)
                                Picker("Method", selection: $customHttpMethod) {
                                    Text("POST").tag("POST")
                                    Text("GET").tag("GET")
                                    Text("PUT").tag("PUT")
                                }
                                .pickerStyle(.segmented)
                            }

                            // Headers
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Headers (JSON) - Optional")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(themeManager.text)
                                TextEditor(text: $customHeaders)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(height: 60)
                                    .border(Color.gray.opacity(0.3))
                                Text("Example: {\"Content-Type\": \"application/json\", \"Authorization\": \"Bearer YOUR_KEY\"}")
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryText)
                            }

                            // Request Template
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Request Body Template")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(themeManager.text)
                                TextEditor(text: $customRequestTemplate)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(height: 100)
                                    .border(Color.gray.opacity(0.3))
                                HStack(spacing: 4) {
                                    Text("Use")
                                        .font(.caption)
                                        .foregroundColor(themeManager.secondaryText)
                                    Text("{{input}}")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                    Text("for the user's message (includes context, history, and question)")
                                        .font(.caption)
                                        .foregroundColor(themeManager.secondaryText)
                                }
                                Text("Example: {\"messages\": [{\"role\": \"user\", \"content\": \"{{input}}\"}]}")
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryText)
                            }

                            // Response Path
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Response JSONPath")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(themeManager.text)
                                TextField("e.g., choices[0].message.content", text: $customResponsePath)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                Text("Path to extract AI response from JSON (e.g., \"data.response\", \"choices[0].text\")")
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryText)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(themeManager.background)

            Divider()
                .background(themeManager.divider)

            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: addConfiguration) {
                    Text("Add Configuration")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 500, height: 550)
        .background(themeManager.background)
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .onAppear {
            type = .ollama
            apiEndpoint = type.defaultEndpoint
            checkOllamaInstallation()
        }
        .sheet(isPresented: $showModelPullSheet) {
            ModelPullSheet(
                apiEndpoint: apiEndpoint,
                isPulling: $isPullingModel,
                progress: $pullProgress,
                onComplete: {
                    showModelPullSheet = false
                    fetchOllamaModels()
                }
            )
        }
    }

    private var isFormValid: Bool {
        guard !name.isEmpty else { return false }
        guard type.requiresAPIKey ? !apiKey.isEmpty : true else { return false }

        // For Custom type, validate custom API fields
        if type == .custom {
            guard !apiEndpoint.isEmpty else { return false }
            guard !customRequestTemplate.isEmpty else { return false }
            guard !customResponsePath.isEmpty else { return false }
            return true
        }

        // For other types, validate model
        let finalModel = useCustomModel ? customModel : model
        guard !finalModel.isEmpty else { return false }

        return true
    }

    private func fetchOllamaModels() {
        isLoadingModels = true
        llmManager.fetchOllamaModels(from: apiEndpoint) { models in
            self.availableModels = models
            self.isLoadingModels = false
        }
    }

    private func addConfiguration() {
        let finalModel = (type == .custom) ? nil : (useCustomModel ? customModel : model)

        var newConfig = LLMConfiguration(
            id: UUID().uuidString,
            name: name,
            type: type,
            apiKey: type.requiresAPIKey ? apiKey.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            model: finalModel,
            apiEndpoint: apiEndpoint.isEmpty ? type.defaultEndpoint : apiEndpoint,
            isActive: false,
            contextLength: type == .custom ? customContextLength : nil,
            customHeaders: type == .custom ? customHeaders.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            customRequestTemplate: type == .custom ? customRequestTemplate.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            customResponsePath: type == .custom ? customResponsePath.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            customHttpMethod: type == .custom ? customHttpMethod : nil
        )

        // If Ollama and model is selected, fetch context length before adding
        if type == .ollama, let modelName = finalModel, !modelName.isEmpty {
            llmManager.fetchOllamaModelInfo(endpoint: apiEndpoint.isEmpty ? type.defaultEndpoint : apiEndpoint, modelName: modelName) { contextLength in
                if let contextLength = contextLength {
                    newConfig.contextLength = contextLength
                    print("✅ Set context length for new config: \(contextLength)")
                }
                self.llmManager.addConfiguration(newConfig)
            }
        } else {
            llmManager.addConfiguration(newConfig)
        }

        presentationMode.wrappedValue.dismiss()
    }

    private func checkOllamaInstallation() {
        checkingOllama = true
        llmManager.fetchOllamaModels(from: apiEndpoint) { models in
            DispatchQueue.main.async {
                self.checkingOllama = false
                self.ollamaInstalled = !models.isEmpty || models.isEmpty
                if !models.isEmpty {
                    self.availableModels = models
                    self.ollamaInstalled = true
                } else {
                    guard let url = URL(string: "\(self.apiEndpoint)/api/version") else {
                        self.ollamaInstalled = false
                        return
                    }

                    URLSession.shared.dataTask(with: url) { data, response, error in
                        DispatchQueue.main.async {
                            self.ollamaInstalled = (error == nil && response != nil)
                        }
                    }.resume()
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Configuration Name")
                .font(.headline)
                .foregroundColor(themeManager.text)
            TextField("e.g., My Ollama Model", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var providerTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Provider Type")
                .font(.headline)
                .foregroundColor(themeManager.text)

            Picker("Provider", selection: $type) {
                Text("Ollama").tag(LLMType.ollama)
                Text("Custom").tag(LLMType.custom)
            }
            .pickerStyle(.segmented)

            if type == .ollama {
                Text("Local Ollama instance")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryText)
            } else {
                Text("Custom API with full control")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryText)
            }
        }
        .onChange(of: type) { oldType, newType in
            if apiEndpoint.isEmpty || apiEndpoint == LLMType.ollama.defaultEndpoint || apiEndpoint == LLMType.custom.defaultEndpoint {
                apiEndpoint = newType.defaultEndpoint
            }
        }
    }
}

class OllamaStreamDelegate: NSObject, URLSessionDataDelegate {
    var onProgress: (String) -> Void
    var onComplete: () -> Void
    var receivedData = Data()

    init(onProgress: @escaping (String) -> Void, onComplete: @escaping () -> Void) {
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)

        if let string = String(data: receivedData, encoding: .utf8) {
            let lines = string.components(separatedBy: "\n")

            for i in 0..<(lines.count - 1) {
                let line = lines[i].trimmingCharacters(in: .whitespaces)
                if !line.isEmpty {
                    if let lineData = line.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                       let status = json["status"] as? String {

                        if let completed = json["completed"] as? Int64,
                           let total = json["total"] as? Int64, total > 0 {
                            let percentage = Int((Double(completed) / Double(total)) * 100)
                            let completedMB = Double(completed) / (1024 * 1024)
                            let totalMB = Double(total) / (1024 * 1024)
                            DispatchQueue.main.async {
                                self.onProgress(String(format: "%@: %.1f/%.1f MB (%d%%)", status, completedMB, totalMB, percentage))
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.onProgress(status)
                            }
                        }
                    }
                }
            }

            if lines.count > 0 {
                receivedData = lines.last?.data(using: .utf8) ?? Data()
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.onProgress("Error: \(error.localizedDescription)")
            } else {
                self.onProgress("Download complete!")
            }
            self.onComplete()
        }
    }
}

struct ModelPullSheet: View {
    let apiEndpoint: String
    @Binding var isPulling: Bool
    @Binding var progress: String
    var onComplete: () -> Void

    @State private var modelName = ""
    @ObservedObject var themeManager = ColorSchemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var streamDelegate: OllamaStreamDelegate?
    @State private var urlSession: URLSession?
    @State private var currentTask: URLSessionDataTask?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Browse Available Models")
                            .font(.headline)
                            .foregroundColor(themeManager.text)

                        Button(action: {
                            NSWorkspace.shared.open(URL(string: "https://ollama.com/library")!)
                        }) {
                            HStack {
                                Image(systemName: "globe")
                                Text("Visit Ollama Library")
                                Image(systemName: "arrow.up.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Divider()
                        .background(themeManager.divider)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter Model Name")
                            .font(.headline)
                            .foregroundColor(themeManager.text)

                        TextField("e.g., llama3.2:3b", text: $modelName)
                            .textFieldStyle(.roundedBorder)

                        Text("Copy the model name from the Ollama library and paste it here")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryText)
                    }

                    if isPulling {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text(progress)
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.secondaryBackground)
                        .cornerRadius(8)
                    }
                }
                .padding(20)
            }
            .background(themeManager.background)

            Divider()
                .background(themeManager.divider)

            // Footer
            HStack {
                Button(isPulling ? "Cancel Download" : "Close") {
                    if isPulling {
                        cancelDownload()
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: pullModel) {
                    Text("Download")
                }
                .buttonStyle(.borderedProminent)
                .disabled(modelName.isEmpty || isPulling)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .background(themeManager.background)
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .onDisappear {
            if isPulling {
                cancelDownload()
            }
        }
    }

    private func pullModel() {
        guard !modelName.isEmpty else { return }
        isPulling = true
        progress = "Starting download..."

        guard let url = URL(string: "\(apiEndpoint)/api/pull") else {
            progress = "Invalid endpoint URL"
            isPulling = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["name": modelName, "stream": true]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let delegate = OllamaStreamDelegate(
            onProgress: { progressText in
                self.progress = progressText
            },
            onComplete: {
                self.isPulling = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.onComplete()
                }
            }
        )

        self.streamDelegate = delegate
        self.urlSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        let task = urlSession!.dataTask(with: request)
        self.currentTask = task
        task.resume()
    }

    private func cancelDownload() {
        currentTask?.cancel()
        currentTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        streamDelegate = nil
        isPulling = false
        progress = "Download cancelled"
    }
}

struct ConfigurationEditView: View {
    @ObservedObject var llmManager: LLMManager
    @ObservedObject var themeManager = ColorSchemeManager.shared
    @State private var name: String
    @State private var apiKey: String
    @State private var model: String
    @State private var customModel: String = ""
    @State private var apiEndpoint: String
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false
    @State private var useCustomModel = false
    @State private var contextLength: Int?

    // Custom API fields
    @State private var customHeaders: String
    @State private var customRequestTemplate: String
    @State private var customResponsePath: String
    @State private var customHttpMethod: String
    @State private var customContextLength: Int?

    @Environment(\.presentationMode) var presentationMode

    let configuration: LLMConfiguration?

    init(llmManager: LLMManager, configuration: LLMConfiguration?) {
        self.llmManager = llmManager
        self.configuration = configuration
        _name = State(initialValue: configuration?.name ?? "")
        _apiKey = State(initialValue: configuration?.apiKey ?? "")
        _model = State(initialValue: configuration?.model ?? "")
        _apiEndpoint = State(initialValue: configuration?.apiEndpoint ?? configuration?.type.defaultEndpoint ?? "")
        _contextLength = State(initialValue: configuration?.contextLength)
        _customHeaders = State(initialValue: configuration?.customHeaders ?? "")
        _customRequestTemplate = State(initialValue: configuration?.customRequestTemplate ?? "")
        _customResponsePath = State(initialValue: configuration?.customResponsePath ?? "")
        _customHttpMethod = State(initialValue: configuration?.customHttpMethod ?? "POST")
        _customContextLength = State(initialValue: configuration?.type == .custom ? configuration?.contextLength : nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    nameEditSection

                    if configuration?.type.requiresAPIKey == true {
                        apiKeySection
                    }

                    endpointSection

                    if configuration?.type == .ollama {
                        fetchModelsButton
                    }

                    if configuration?.type != .custom {
                        modelSection
                    }

                    if configuration?.type == .custom {
                        customAPISection
                    }
                }
                .padding(20)
            }
            .background(themeManager.background)

            Divider()
                .background(themeManager.divider)

            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: saveConfiguration) {
                    Text("Update Configuration")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdateButtonDisabled)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 500, height: 500)
        .background(themeManager.background)
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .onAppear {
            print("🔍 ConfigurationEditView.onAppear - model: \(model), type: \(String(describing: configuration?.type))")
            if configuration?.type == .ollama {
                fetchOllamaModels()
                // If editing existing config with a model already selected, fetch its context length
                if !model.isEmpty && contextLength == nil {
                    print("🔍 Fetching context length for existing model on appear: \(model)")
                    fetchOllamaModelInfo(modelName: model)
                }
            }
        }
    }

    private func fetchOllamaModels() {
        isLoadingModels = true
        llmManager.fetchOllamaModels(from: apiEndpoint) { models in
            self.availableModels = models
            self.isLoadingModels = false
        }
    }

    private var isUpdateButtonDisabled: Bool {
        // Name must not be empty
        guard !name.isEmpty else { return true }

        // For custom type, validate custom API fields
        if configuration?.type == .custom {
            guard !apiEndpoint.isEmpty else { return true }
            guard !customRequestTemplate.isEmpty else { return true }
            guard !customResponsePath.isEmpty else { return true }
            return false
        }

        // For other types, validate model
        let finalModel = useCustomModel ? customModel : model
        return finalModel.isEmpty
    }

    private func fetchOllamaModelInfo(modelName: String) {
        print("🔍 fetchOllamaModelInfo called for model: \(modelName)")
        llmManager.fetchOllamaModelInfo(endpoint: apiEndpoint, modelName: modelName) { contextLen in
            print("🔍 fetchOllamaModelInfo callback - contextLen: \(String(describing: contextLen))")
            self.contextLength = contextLen
            print("🔍 Set contextLength to: \(String(describing: self.contextLength))")
        }
    }

    private func saveConfiguration() {
        let finalModel = (configuration?.type == .custom) ? nil : (useCustomModel ? customModel : model)

        print("🔍 saveConfiguration - contextLength: \(String(describing: contextLength))")

        // For custom type, use customContextLength; for Ollama use contextLength
        let finalContextLength = configuration?.type == .custom ? customContextLength : contextLength

        let newConfig = LLMConfiguration(
            id: configuration?.id ?? UUID().uuidString,
            name: name,
            type: configuration?.type ?? .custom,
            apiKey: configuration?.type.requiresAPIKey == true ? apiKey.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            model: finalModel,
            apiEndpoint: apiEndpoint,
            isActive: configuration?.isActive ?? false,
            contextLength: finalContextLength,
            customHeaders: configuration?.type == .custom ? customHeaders.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            customRequestTemplate: configuration?.type == .custom ? customRequestTemplate.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            customResponsePath: configuration?.type == .custom ? customResponsePath.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            customHttpMethod: configuration?.type == .custom ? customHttpMethod : nil
        )

        print("🔍 newConfig.contextLength: \(String(describing: newConfig.contextLength))")

        if let existingConfig = configuration {
            llmManager.updateConfiguration(existingConfig, with: newConfig)
        } else {
            llmManager.addConfiguration(newConfig)
        }

        presentationMode.wrappedValue.dismiss()
    }

    // MARK: - Computed Properties

    private var nameEditSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Configuration Name")
                .font(.headline)
                .foregroundColor(themeManager.text)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Key")
                .font(.headline)
                .foregroundColor(themeManager.text)
            SecureField("API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var endpointSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Endpoint")
                .font(.headline)
                .foregroundColor(themeManager.text)
            TextField("API Endpoint", text: $apiEndpoint)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var fetchModelsButton: some View {
        Button(action: fetchOllamaModels) {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Fetch Models")
            }
        }
        .disabled(isLoadingModels)
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model")
                .font(.headline)
                .foregroundColor(themeManager.text)

            if configuration?.type == .ollama && !availableModels.isEmpty {
                Picker("Model", selection: $model) {
                    Text("Select a model...").tag("")
                    ForEach(availableModels, id: \.self) { modelName in
                        Text(modelName)
                            .foregroundColor(themeManager.text)
                            .tag(modelName)
                    }
                }
                .labelsHidden()
                .foregroundColor(themeManager.text)
                .onChange(of: model) { oldModel, newModel in
                    if !newModel.isEmpty && configuration?.type == .ollama {
                        fetchOllamaModelInfo(modelName: newModel)
                    }
                }
            } else {
                TextField("Model", text: $model)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var customAPISection: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                Text("Context Length (Optional)")
                    .font(.headline)
                    .foregroundColor(themeManager.text)
                TextField("e.g., 8192", value: $customContextLength, format: .number)
                    .textFieldStyle(.roundedBorder)
                Text("Maximum number of tokens the model can handle")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryText)
            }

            VStack(alignment: .leading, spacing: 16) {
                Divider()
                    .background(themeManager.divider)

                Text("Request Configuration")
                    .font(.headline)
                    .foregroundColor(themeManager.text)

                httpMethodPicker
                headersEditor
                requestTemplateEditor
                responsePathField
            }
        }
    }

    private var httpMethodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HTTP Method")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(themeManager.text)
            Picker("Method", selection: $customHttpMethod) {
                Text("POST").tag("POST")
                Text("GET").tag("GET")
                Text("PUT").tag("PUT")
            }
            .pickerStyle(.segmented)
        }
    }

    private var headersEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Headers (JSON)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(themeManager.text)
            TextEditor(text: $customHeaders)
                .font(.system(.body, design: .monospaced))
                .frame(height: 60)
                .border(Color.gray.opacity(0.3))
            Text("Example: {\"Content-Type\": \"application/json\", \"Authorization\": \"Bearer YOUR_KEY\"}")
                .font(.caption)
                .foregroundColor(themeManager.secondaryText)
        }
    }

    private var requestTemplateEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Request Body Template")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(themeManager.text)
            TextEditor(text: $customRequestTemplate)
                .font(.system(.body, design: .monospaced))
                .frame(height: 100)
                .border(Color.gray.opacity(0.3))
            HStack(spacing: 4) {
                Text("Use")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryText)
                Text("{{input}}")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                Text("for the user's message (includes context, history, and question)")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryText)
            }
            Text("Example: {\"messages\": [{\"role\": \"user\", \"content\": \"{{input}}\"}]}")
                .font(.caption)
                .foregroundColor(themeManager.secondaryText)
        }
    }

    private var responsePathField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Response JSONPath")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(themeManager.text)
            TextField("e.g., choices[0].message.content", text: $customResponsePath)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Text("Path to extract AI response from JSON (e.g., \"data.response\", \"choices[0].text\")")
                .font(.caption)
                .foregroundColor(themeManager.secondaryText)
        }
    }
}

// MARK: - Hotkey Recorder Field
struct HotkeyRecorderField: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var themeManager = ColorSchemeManager.shared
    var onSave: (UInt32, UInt32) -> Void

    @State private var recordedKeyCode: UInt32?
    @State private var recordedModifiers: UInt32?
    @State private var displayText: String = "Click here and press a new hotkey"

    var body: some View {
        VStack(spacing: 12) {
            Text("New Hotkey:")
                .font(.headline)
                .foregroundColor(themeManager.text)

            HotkeyRecorderTextField(
                displayText: $displayText,
                recordedKeyCode: $recordedKeyCode,
                recordedModifiers: $recordedModifiers,
                themeManager: themeManager
            )
            .frame(height: 44)

            Button(action: {
                if let keyCode = recordedKeyCode, let modifiers = recordedModifiers {
                    onSave(keyCode, modifiers)
                    // Reset after save
                    displayText = "Click here and press a new hotkey"
                    recordedKeyCode = nil
                    recordedModifiers = nil
                }
            }) {
                Text("Save Hotkey")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(recordedKeyCode == nil || recordedModifiers == nil)
        }
    }
}

struct QuickWindowHotkeyRecorderField: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var themeManager = ColorSchemeManager.shared
    var onSave: (UInt32, UInt32) -> Void

    @State private var recordedKeyCode: UInt32?
    @State private var recordedModifiers: UInt32?
    @State private var displayText: String = "Click here and press a new hotkey"

    var body: some View {
        VStack(spacing: 12) {
            Text("New Hotkey:")
                .font(.headline)
                .foregroundColor(themeManager.text)

            HotkeyRecorderTextField(
                displayText: $displayText,
                recordedKeyCode: $recordedKeyCode,
                recordedModifiers: $recordedModifiers,
                themeManager: themeManager
            )
            .frame(height: 44)

            Button(action: {
                if let keyCode = recordedKeyCode, let modifiers = recordedModifiers {
                    onSave(keyCode, modifiers)
                    // Reset after save
                    displayText = "Click here and press a new hotkey"
                    recordedKeyCode = nil
                    recordedModifiers = nil
                }
            }) {
                Text("Save Hotkey")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(recordedKeyCode == nil || recordedModifiers == nil)
        }
    }
}

struct CompactHotkeyRecorderField: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var themeManager = ColorSchemeManager.shared
    var onSave: (UInt32, UInt32) -> Void

    @State private var recordedKeyCode: UInt32?
    @State private var recordedModifiers: UInt32?
    @State private var displayText: String = "Press new hotkey"

    var body: some View {
        VStack(spacing: 8) {
            HotkeyRecorderTextField(
                displayText: $displayText,
                recordedKeyCode: $recordedKeyCode,
                recordedModifiers: $recordedModifiers,
                themeManager: themeManager
            )
            .frame(height: 32)

            Button(action: {
                if let keyCode = recordedKeyCode, let modifiers = recordedModifiers {
                    onSave(keyCode, modifiers)
                    displayText = "Press new hotkey"
                    recordedKeyCode = nil
                    recordedModifiers = nil
                }
            }) {
                Text("Save")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(recordedKeyCode == nil || recordedModifiers == nil)
        }
    }
}

struct CompactQuickWindowHotkeyRecorderField: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var themeManager = ColorSchemeManager.shared
    var onSave: (UInt32, UInt32) -> Void

    @State private var recordedKeyCode: UInt32?
    @State private var recordedModifiers: UInt32?
    @State private var displayText: String = "Press new hotkey"

    var body: some View {
        VStack(spacing: 8) {
            HotkeyRecorderTextField(
                displayText: $displayText,
                recordedKeyCode: $recordedKeyCode,
                recordedModifiers: $recordedModifiers,
                themeManager: themeManager
            )
            .frame(height: 32)

            Button(action: {
                if let keyCode = recordedKeyCode, let modifiers = recordedModifiers {
                    onSave(keyCode, modifiers)
                    displayText = "Press new hotkey"
                    recordedKeyCode = nil
                    recordedModifiers = nil
                }
            }) {
                Text("Save")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(recordedKeyCode == nil || recordedModifiers == nil)
        }
    }
}

struct HotkeyRecorderTextField: NSViewRepresentable {
    @Binding var displayText: String
    @Binding var recordedKeyCode: UInt32?
    @Binding var recordedModifiers: UInt32?
    @ObservedObject var themeManager: ColorSchemeManager

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.isEditable = false
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.backgroundColor = NSColor(themeManager.secondaryBackground)
        textField.textColor = NSColor(themeManager.text)
        textField.alignment = .center
        textField.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        textField.placeholderString = "Click here and press a new hotkey"
        textField.stringValue = displayText

        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick))
        textField.addGestureRecognizer(clickGesture)

        context.coordinator.textField = textField

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.backgroundColor = NSColor(themeManager.secondaryBackground)
        nsView.textColor = NSColor(themeManager.text)
        nsView.stringValue = displayText
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            displayText: $displayText,
            recordedKeyCode: $recordedKeyCode,
            recordedModifiers: $recordedModifiers,
            themeManager: themeManager
        )
    }

    class Coordinator: NSObject {
        @Binding var displayText: String
        @Binding var recordedKeyCode: UInt32?
        @Binding var recordedModifiers: UInt32?
        var themeManager: ColorSchemeManager
        weak var textField: NSTextField?
        var isRecording = false
        var eventMonitor: Any?

        init(displayText: Binding<String>, recordedKeyCode: Binding<UInt32?>, recordedModifiers: Binding<UInt32?>, themeManager: ColorSchemeManager) {
            self._displayText = displayText
            self._recordedKeyCode = recordedKeyCode
            self._recordedModifiers = recordedModifiers
            self.themeManager = themeManager
        }

        @objc func handleClick() {
            startRecording()
        }

        func startRecording() {
            guard !isRecording else { return }
            isRecording = true

            displayText = "Press a key combination..."
            textField?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2)

            // Monitor for key events
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self else { return event }

                // Get the key code
                let keyCode = UInt32(event.keyCode)

                // Get modifiers
                var modifiers: UInt32 = 0
                if event.modifierFlags.contains(.command) {
                    modifiers |= UInt32(cmdKey)
                }
                if event.modifierFlags.contains(.shift) {
                    modifiers |= UInt32(shiftKey)
                }
                if event.modifierFlags.contains(.option) {
                    modifiers |= UInt32(optionKey)
                }
                if event.modifierFlags.contains(.control) {
                    modifiers |= UInt32(controlKey)
                }

                // Require at least one modifier
                if modifiers != 0 {
                    // Store the recorded values
                    self.recordedKeyCode = keyCode
                    self.recordedModifiers = modifiers

                    // Display the new hotkey
                    let displayString = self.getDisplayString(keyCode: keyCode, modifiers: modifiers)
                    self.displayText = displayString
                    self.textField?.backgroundColor = NSColor(self.themeManager.secondaryBackground)

                    // Stop recording
                    self.stopRecording()

                    return nil // Consume the event
                }

                return event
            }
        }

        func stopRecording() {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
            isRecording = false
        }

        func getDisplayString(keyCode: UInt32, modifiers: UInt32) -> String {
            var modifierString = ""
            if modifiers & UInt32(cmdKey) != 0 {
                modifierString += "⌘"
            }
            if modifiers & UInt32(shiftKey) != 0 {
                modifierString += "⇧"
            }
            if modifiers & UInt32(optionKey) != 0 {
                modifierString += "⌥"
            }
            if modifiers & UInt32(controlKey) != 0 {
                modifierString += "⌃"
            }

            let keyString = keyCodeToString(keyCode)
            return "\(modifierString)\(keyString)"
        }

        func keyCodeToString(_ keyCode: UInt32) -> String {
            switch Int(keyCode) {
            case kVK_ANSI_A: return "A"
            case kVK_ANSI_B: return "B"
            case kVK_ANSI_C: return "C"
            case kVK_ANSI_D: return "D"
            case kVK_ANSI_E: return "E"
            case kVK_ANSI_F: return "F"
            case kVK_ANSI_G: return "G"
            case kVK_ANSI_H: return "H"
            case kVK_ANSI_I: return "I"
            case kVK_ANSI_J: return "J"
            case kVK_ANSI_K: return "K"
            case kVK_ANSI_L: return "L"
            case kVK_ANSI_M: return "M"
            case kVK_ANSI_N: return "N"
            case kVK_ANSI_O: return "O"
            case kVK_ANSI_P: return "P"
            case kVK_ANSI_Q: return "Q"
            case kVK_ANSI_R: return "R"
            case kVK_ANSI_S: return "S"
            case kVK_ANSI_T: return "T"
            case kVK_ANSI_U: return "U"
            case kVK_ANSI_V: return "V"
            case kVK_ANSI_W: return "W"
            case kVK_ANSI_X: return "X"
            case kVK_ANSI_Y: return "Y"
            case kVK_ANSI_Z: return "Z"
            case kVK_ANSI_0: return "0"
            case kVK_ANSI_1: return "1"
            case kVK_ANSI_2: return "2"
            case kVK_ANSI_3: return "3"
            case kVK_ANSI_4: return "4"
            case kVK_ANSI_5: return "5"
            case kVK_ANSI_6: return "6"
            case kVK_ANSI_7: return "7"
            case kVK_ANSI_8: return "8"
            case kVK_ANSI_9: return "9"
            case kVK_Space: return "Space"
            case kVK_Return: return "Return"
            case kVK_Tab: return "Tab"
            case kVK_Delete: return "Delete"
            case kVK_Escape: return "Escape"
            case kVK_ForwardDelete: return "Del"
            case kVK_LeftArrow: return "←"
            case kVK_RightArrow: return "→"
            case kVK_UpArrow: return "↑"
            case kVK_DownArrow: return "↓"
            default: return "?"
            }
        }

        deinit {
            stopRecording()
        }
    }
}
