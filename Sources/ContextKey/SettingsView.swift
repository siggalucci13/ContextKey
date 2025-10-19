import SwiftUI
import Carbon

struct SettingsView: View {
    @ObservedObject var llmManager: LLMManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var mqttManager: MQTTManager  // Add this line
    @State private var editingConfiguration: LLMConfiguration?
    @State private var showingAddModal = false
    @State private var showingDeleteAlert = false
    @State private var configToDelete: LLMConfiguration?
    @State private var selectedTab = 0
    @State private var newHotkey: UInt32 = 0
    @State private var newModifiers: UInt32 = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            llmConfigView
                .tabItem {
                    Label("LLM Configurations", systemImage: "list.bullet")
                }
                .tag(0)

            hotkeyConfigView
                .tabItem {
                    Label("Hotkey", systemImage: "keyboard")
                }
                .tag(1)
            
            folderSelectionView  // Add this new tab
                .tabItem {
                    Label("Folder", systemImage: "folder")
                }
                .tag(2)
        }
        .frame(width: 500, height: 400)
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
    
    var folderSelectionView: some View {
            VStack(spacing: 20) {
                Text("Current folder: \(mqttManager.currentDirectoryPath)")
                    .lineLimit(1)
                    .truncationMode(.middle)

                Button("Change Folder") {
                    mqttManager.requestFileAccess()
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
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

                           VStack(alignment: .leading) {
                               Text(config.name)
                                   .font(.headline)
                               Text(config.model ?? "No model specified")
                                   .font(.subheadline)
                                   .foregroundColor(.gray)
                           }

                           Spacer()

                           Button(action: {
                               editingConfiguration = config
                           }) {
                               Image(systemName: "pencil")
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
                   }
               }
               .listStyle(PlainListStyle())

               Button(action: { showingAddModal = true }) {
                   Text("Add New Configuration")
               }
               .buttonStyle(.borderedProminent)
               .padding()
           }
           .sheet(item: $editingConfiguration) { config in
               ConfigurationEditView(llmManager: llmManager, configuration: config)
           }
           .sheet(isPresented: $showingAddModal) {
               AddConfigurationView(llmManager: llmManager)
           }
       }
    
    var hotkeyConfigView: some View {
           VStack(spacing: 20) {
               Text("Current Hotkey: \(keyCodeToString(hotkeyManager.currentHotkey)) + \(modifiersToString(hotkeyManager.currentModifiers))")

               HStack {
                   Text("New Hotkey:")
                   TextField("Press key", text: .constant(""))
                       .textFieldStyle(RoundedBorderTextFieldStyle())
                       .onReceive(NotificationCenter.default.publisher(for: NSControl.textDidChangeNotification)) { _ in
                           if let event = NSApp.currentEvent, event.type == .keyDown {
                               newHotkey = UInt32(event.keyCode)
                               newModifiers = UInt32(event.modifierFlags.rawValue)
                           }
                       }
               }

               Button("Save New Hotkey") {
                   hotkeyManager.updateHotkey(newHotkey, modifiers: newModifiers)
               }
               .disabled(newHotkey == 0)

               Spacer()
           }
           .padding()
       }
    
    func keyCodeToString(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Grave: return "`"
        case kVK_ANSI_KeypadDecimal: return "."
        case kVK_ANSI_KeypadMultiply: return "*"
        case kVK_ANSI_KeypadPlus: return "+"
        case kVK_ANSI_KeypadClear: return "Clear"
        case kVK_ANSI_KeypadDivide: return "/"
        case kVK_ANSI_KeypadEnter: return "Enter"
        case kVK_ANSI_KeypadMinus: return "-"
        case kVK_ANSI_KeypadEquals: return "="
        case kVK_ANSI_Keypad0: return "0"
        case kVK_ANSI_Keypad1: return "1"
        case kVK_ANSI_Keypad2: return "2"
        case kVK_ANSI_Keypad3: return "3"
        case kVK_ANSI_Keypad4: return "4"
        case kVK_ANSI_Keypad5: return "5"
        case kVK_ANSI_Keypad6: return "6"
        case kVK_ANSI_Keypad7: return "7"
        case kVK_ANSI_Keypad8: return "8"
        case kVK_ANSI_Keypad9: return "9"
        default: return "Unknown"
        }
    }
    
    func modifiersToString(_ modifiers: UInt32) -> String {
        var modifierStrings: [String] = []
        if modifiers & UInt32(cmdKey) != 0 { modifierStrings.append("Cmd") }
        if modifiers & UInt32(shiftKey) != 0 { modifierStrings.append("Shift") }
        if modifiers & UInt32(optionKey) != 0 { modifierStrings.append("Option") }
        if modifiers & UInt32(controlKey) != 0 { modifierStrings.append("Control") }
        return modifierStrings.joined(separator: " + ")
    }
}

struct AddConfigurationView: View {
    @ObservedObject var llmManager: LLMManager
    @State private var name: String = ""
    @State private var type: LLMType = .openAI
    @State private var apiKey: String = ""
    @State private var model: String = ""
    @State private var apiEndpoint: String = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            TextField("Configuration Name", text: $name)

            Picker("Type", selection: $type) {
                Text("OpenAI").tag(LLMType.openAI)
                Text("Ollama").tag(LLMType.ollama)
            }
            .pickerStyle(SegmentedPickerStyle())

            if type == .openAI {
                TextField("API Key", text: $apiKey)
                TextField("Model", text: $model)
            } else if type == .ollama {
                TextField("API Endpoint", text: $apiEndpoint)
                TextField("Model", text: $model)
            }

            HStack {
                Button(action: addConfiguration) {
                    Text("Add Configuration")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }

            Spacer()
        }
        .padding()
        .frame(width: 300, height: 300)
    }

    private func addConfiguration() {
        let newConfig = LLMConfiguration(
            id: UUID().uuidString,
            name: name,
            type: type,
            apiKey: type == .openAI ? apiKey : nil,
            model: model,
            apiEndpoint: type == .ollama ? apiEndpoint : nil,
            isActive: false
        )

        llmManager.addConfiguration(newConfig)
        presentationMode.wrappedValue.dismiss()
    }
}
struct ConfigurationEditView: View {
    @ObservedObject var llmManager: LLMManager
    @State private var name: String
    @State private var apiKey: String
    @State private var model: String
    @State private var apiEndpoint: String
    @Environment(\.presentationMode) var presentationMode

    let configuration: LLMConfiguration?

    init(llmManager: LLMManager, configuration: LLMConfiguration?) {
        self.llmManager = llmManager
        self.configuration = configuration
        _name = State(initialValue: configuration?.name ?? "")
        _apiKey = State(initialValue: configuration?.apiKey ?? "")
        _model = State(initialValue: configuration?.model ?? "")
        _apiEndpoint = State(initialValue: configuration?.apiEndpoint ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            TextField("Configuration Name", text: $name)
            
            if configuration?.type == .openAI {
                TextField("API Key", text: $apiKey)
                TextField("Model", text: $model)
            } else if configuration?.type == .ollama {
                TextField("API Endpoint", text: $apiEndpoint)
                TextField("Model", text: $model)
            }

            HStack {
                Button(action: saveConfiguration) {
                    Text(configuration == nil ? "Add Configuration" : "Update Configuration")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }

            Spacer()
        }
        .padding()
        .frame(width: 300, height: 250)
    }

    private func saveConfiguration() {
        let newConfig = LLMConfiguration(
            id: configuration?.id ?? UUID().uuidString,
            name: name,
            type: configuration?.type ?? .openAI,
            apiKey: configuration?.type == .openAI ? apiKey : nil,
            model: model,
            apiEndpoint: configuration?.type == .ollama ? apiEndpoint : nil,
            isActive: configuration?.isActive ?? false
        )

        if let existingConfig = configuration {
            llmManager.updateConfiguration(existingConfig, with: newConfig)
        } else {
            llmManager.addConfiguration(newConfig)
        }

        presentationMode.wrappedValue.dismiss()
    }
}
