import SwiftUI

struct FileAttachment: Identifiable, Codable {
    let id: UUID
    let name: String
    let path: String
    var imageData: Data? // For image files - base64 encoded
    var isImage: Bool // Flag to indicate if this is an image

    init(id: UUID = UUID(), name: String, path: String, imageData: Data? = nil, isImage: Bool = false) {
        self.id = id
        self.name = name
        self.path = path
        self.imageData = imageData
        self.isImage = isImage
    }
}

struct HistoryItem: Identifiable, Codable {
    let id: UUID
    var timestamp: Date
    let initialContext: String
    var conversation: [Message]
    var configName: String?
    var modelName: String?
    var attachedFiles: [FileAttachment]?

    struct Message: Identifiable, Codable {
        let id: UUID
        var content: String
        let isUser: Bool
        var imageURL: String? // URL to image (returned by image generation models)
        var imageData: Data? // Base64 decoded image data for display
    }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, initialContext, conversation, configName, modelName, attachedFiles
    }

    init(id: UUID = UUID(), timestamp: Date = Date(), initialContext: String, conversation: [Message], configName: String? = nil, modelName: String? = nil, attachedFiles: [FileAttachment]? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.initialContext = initialContext
        self.conversation = conversation
        self.configName = configName
        self.modelName = modelName
        self.attachedFiles = attachedFiles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        initialContext = try container.decode(String.self, forKey: .initialContext)
        conversation = try container.decode([Message].self, forKey: .conversation)
        configName = try? container.decodeIfPresent(String.self, forKey: .configName)
        modelName = try? container.decodeIfPresent(String.self, forKey: .modelName)
        attachedFiles = try? container.decodeIfPresent([FileAttachment].self, forKey: .attachedFiles)

        if let timestamp = try? container.decode(Date.self, forKey: .timestamp) {
            self.timestamp = timestamp
        } else if let timestampDouble = try? container.decode(Double.self, forKey: .timestamp) {
            self.timestamp = Date(timeIntervalSince1970: timestampDouble)
        } else if let timestampString = try? container.decode(String.self, forKey: .timestamp),
                  let date = ISO8601DateFormatter().date(from: timestampString) {
            self.timestamp = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .timestamp, in: container, debugDescription: "Unable to decode timestamp")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(ISO8601DateFormatter().string(from: timestamp), forKey: .timestamp)
        try container.encode(initialContext, forKey: .initialContext)
        try container.encode(conversation, forKey: .conversation)
        try container.encodeIfPresent(configName, forKey: .configName)
        try container.encodeIfPresent(modelName, forKey: .modelName)
        try container.encodeIfPresent(attachedFiles, forKey: .attachedFiles)
    }
}

struct ContentView: View {
    @ObservedObject var llmManager: LLMManager
    @ObservedObject var dataManager: DataManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var colorScheme = ColorSchemeManager.shared
    @State private var currentContext: String = ""
    @State private var currentQuestion: String = ""
    @State private var isHistoryVisible = true
    @State private var showSettings = false
    @State private var showCompactWindow = false
    @State private var compactWindowContext = ""
    @State private var selectedHistoryItem: HistoryItem?
    @State private var isTyping: Bool = false
    @State private var showFullInitialContext: Bool = false
    @State private var includeContextAndHistory: Bool = true
    @State private var includeContextOnly: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: {
                    isHistoryVisible.toggle()
                }) {
                    Text(isHistoryVisible ? "Close History" : "Show History")
                        .foregroundColor(colorScheme.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .cornerRadius(5)
                }
                .padding(.leading)

                Button(action: {
                    AppDelegate.shared.openSettingsWindow()
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(colorScheme.text)
                        .font(.title2)
                }
                .padding(.leading, 10)

                Button(action: {
                    startNewConversation()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                        Text("New")
                    }
                    .foregroundColor(colorScheme.text)
                }
                .padding(.leading, 10)

                Spacer()

                // Config selector - locked when viewing history
                HStack(spacing: 4) {
                    Text("Config:")
                        .font(.caption)
                        .foregroundColor(colorScheme.secondaryText)

                    if let selectedItem = selectedHistoryItem, let configName = selectedItem.configName {
                        // Locked to history item's config
                        HStack(spacing: 4) {
                            Text(configName)
                                .foregroundColor(.blue)
                            if let modelName = selectedItem.modelName {
                                Text("(\(modelName))")
                                    .font(.caption)
                                    .foregroundColor(colorScheme.secondaryText)
                            }
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else if let activeConfig = llmManager.activeConfiguration {
                        // Unlocked - can change config
                        Picker("", selection: Binding(
                            get: { llmManager.activeConfiguration?.id ?? "" },
                            set: { newId in
                                if let config = llmManager.configurations.first(where: { $0.id == newId }) {
                                    llmManager.setActiveConfiguration(config)
                                }
                            }
                        )) {
                            ForEach(llmManager.configurations) { config in
                                HStack {
                                    Text(config.name)
                                        .foregroundColor(colorScheme.text)
                                    if let model = config.model {
                                        Text("(\(model))")
                                            .font(.caption2)
                                            .foregroundColor(colorScheme.text)
                                    }
                                }
                                .tag(config.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .accentColor(colorScheme.text)
                    } else {
                        Text("No config")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(.trailing, 10)

                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
                    .padding()
            }
            .frame(height: 70)
            .background(colorScheme.background)
            .environment(\.colorScheme, colorScheme.isDarkMode ? .dark : .light)

            // Separator line
            Divider()
                .background(colorScheme.border)

            // Main content
            HStack(spacing: 0) {
                if isHistoryVisible {
                    HistorySection(
                        history: dataManager.history,
                        selectedItem: selectedHistoryItem,
                        onSelectItem: { item in
                            selectedHistoryItem = item
                            currentContext = item.initialContext
                        },
                        onDeleteItem: { item in
                            deleteHistoryItem(item)
                        },
                        onDeleteAll: {
                            clearAllHistory()
                        },
                        onDeleteFiltered: { filteredItems in
                            deleteFilteredHistory(filteredItems)
                        },
                        llmManager: llmManager
                    )
                }

                // Main Area
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                            if let selectedItem = selectedHistoryItem {
                                // Show initial context for historical conversations
                                // Show initial context ONLY if no files are attached
                                if !selectedItem.initialContext.isEmpty && (selectedItem.attachedFiles?.isEmpty ?? true) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Initial Context")
                                                .font(.caption)
                                                .foregroundColor(colorScheme.secondaryText)
                                            Spacer()
                                        }
                                        .padding(.bottom, 2)

                                        VStack(alignment: .leading, spacing: 8) {
                                            TextWithExpandButton(
                                                text: selectedItem.initialContext,
                                                isExpanded: $showFullInitialContext,
                                                font: .system(size: 13),
                                                lineLimit: 10,
                                                colorScheme: colorScheme
                                            )
                                        }
                                        .padding(12)
                                        .background(colorScheme.secondaryBackground)
                                        .cornerRadius(8)
                                    }
                                }

                                // Show attached files
                                if let files = selectedItem.attachedFiles, !files.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "paperclip")
                                                .font(.caption)
                                            Text("Attached Files (\(files.count))")
                                                .font(.caption)
                                                .foregroundColor(colorScheme.secondaryText)
                                            Spacer()
                                        }

                                        ForEach(files) { file in
                                            if file.isImage, let imageData = file.imageData, let nsImage = NSImage(data: imageData) {
                                                // Image preview
                                                Button(action: {
                                                    let fileURL = URL(fileURLWithPath: file.path)
                                                    NSWorkspace.shared.open(fileURL)
                                                }) {
                                                    VStack(spacing: 6) {
                                                        Image(nsImage: nsImage)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(maxHeight: 200)
                                                            .cornerRadius(6)

                                                        HStack {
                                                            Image(systemName: "photo.fill")
                                                                .foregroundColor(.blue)
                                                                .font(.caption)
                                                            Text(file.name)
                                                                .font(.caption)
                                                                .foregroundColor(colorScheme.text)
                                                            Spacer()
                                                            Image(systemName: "arrow.up.right.square")
                                                                .font(.caption)
                                                                .foregroundColor(colorScheme.secondaryText)
                                                        }
                                                    }
                                                    .padding(8)
                                                    .background(colorScheme.tertiaryBackground)
                                                    .cornerRadius(6)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                                    )
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                                .help("Click to open image in default application")
                                                .onHover { hovering in
                                                    if hovering {
                                                        NSCursor.pointingHand.push()
                                                    } else {
                                                        NSCursor.pop()
                                                    }
                                                }
                                            } else {
                                                // Regular file
                                                Button(action: {
                                                    let fileURL = URL(fileURLWithPath: file.path)
                                                    NSWorkspace.shared.open(fileURL)
                                                }) {
                                                    HStack(spacing: 8) {
                                                        Image(systemName: "doc.text.fill")
                                                            .foregroundColor(.blue)
                                                            .font(.caption)

                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(file.name)
                                                                .font(.caption)
                                                                .foregroundColor(colorScheme.text)
                                                                .fontWeight(.medium)
                                                            Text(file.path)
                                                                .font(.caption2)
                                                                .foregroundColor(colorScheme.secondaryText)
                                                                .lineLimit(1)
                                                                .truncationMode(.middle)
                                                        }

                                                        Spacer()

                                                        Image(systemName: "arrow.up.right.square")
                                                            .font(.caption)
                                                            .foregroundColor(colorScheme.secondaryText)
                                                    }
                                                    .padding(8)
                                                    .background(colorScheme.tertiaryBackground)
                                                    .cornerRadius(6)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                                    )
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                                .help("Click to open file in default application")
                                                .onHover { hovering in
                                                    if hovering {
                                                        NSCursor.pointingHand.push()
                                                    } else {
                                                        NSCursor.pop()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(colorScheme.secondaryBackground)
                                    .cornerRadius(8)
                                }

                                ForEach(selectedItem.conversation) { message in
                                    ChatBubble(message: message, colorScheme: colorScheme)
                                        .id(message.id)
                                }

                                if isTyping {
                                    TypingIndicator(colorScheme: colorScheme)
                                        .id("typing-history")
                                }

                                // Invisible anchor for scrolling to bottom in history view
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom-history")
                            } else {
                                // Active conversation - show initial context only if conversation has started
                                if !dataManager.currentConversation.isEmpty && !currentContext.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Initial Context")
                                                .font(.caption)
                                                .foregroundColor(colorScheme.secondaryText)
                                            Spacer()
                                        }
                                        .padding(.bottom, 2)

                                        VStack(alignment: .leading, spacing: 8) {
                                            TextWithExpandButton(
                                                text: currentContext,
                                                isExpanded: $showFullInitialContext,
                                                font: .system(size: 13),
                                                lineLimit: 10,
                                                colorScheme: colorScheme
                                            )
                                        }
                                        .padding(12)
                                        .background(colorScheme.secondaryBackground)
                                        .cornerRadius(8)
                                    }
                                }

                                ForEach(dataManager.currentConversation) { message in
                                    ChatBubble(message: message, colorScheme: colorScheme)
                                        .id(message.id)
                                }

                                if isTyping {
                                    TypingIndicator(colorScheme: colorScheme)
                                        .id("typing")
                                }

                                // Invisible anchor for scrolling to bottom
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                            }
                        }
                        .padding()
                        }
                        .onChange(of: dataManager.currentConversation.count) {
                            if selectedHistoryItem == nil {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        proxy.scrollTo("bottom", anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .onChange(of: selectedHistoryItem?.conversation.count) {
                            if selectedHistoryItem != nil {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        proxy.scrollTo("bottom-history", anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .onChange(of: isTyping) { oldValue, newValue in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation {
                                    if selectedHistoryItem != nil {
                                        proxy.scrollTo("bottom-history", anchor: .bottom)
                                    } else {
                                        proxy.scrollTo("bottom", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .background(colorScheme.background)

                    // Context usage indicator
                    if !currentContext.isEmpty || !currentQuestion.isEmpty || (selectedHistoryItem?.attachedFiles?.isEmpty == false) {
                        let contextCheck = llmManager.checkContextLimit(text: calculateContextForDisplay(), config: llmManager.activeConfiguration)

                        HStack(spacing: 8) {
                            Image(systemName: contextCheck.exceeds ? "exclamationmark.triangle.fill" : "doc.text")
                                .foregroundColor(contextCheck.exceeds ? .orange : .blue)
                                .font(.caption)

                            if let limit = contextCheck.limit {
                                Text("\(contextCheck.estimated.formatted()) / \(limit.formatted()) tokens")
                                    .font(.caption)
                                    .foregroundColor(contextCheck.exceeds ? .orange : colorScheme.secondaryText)
                            } else {
                                Text("~\(contextCheck.estimated.formatted()) tokens")
                                    .font(.caption)
                                    .foregroundColor(colorScheme.secondaryText)
                            }

                            if contextCheck.exceeds {
                                Text("⚠️ May be truncated")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }

                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(contextCheck.exceeds ? Color.orange.opacity(0.1) : Color.clear)
                    }

                    // Context options checkboxes
                    if !currentContext.isEmpty || (selectedHistoryItem?.attachedFiles?.isEmpty == false) || (selectedHistoryItem?.conversation.isEmpty == false) {
                        HStack(spacing: 16) {
                            Toggle(isOn: Binding(
                                get: { includeContextAndHistory },
                                set: { newValue in
                                    includeContextAndHistory = newValue
                                    if newValue { includeContextOnly = false }
                                }
                            )) {
                                Text("Initial Context + Conversation")
                                    .font(.caption)
                                    .foregroundColor(colorScheme.text)
                            }
                            .toggleStyle(.checkbox)
                            .disabled(currentContext.isEmpty && (selectedHistoryItem?.attachedFiles?.isEmpty ?? true) && (selectedHistoryItem?.initialContext.isEmpty ?? true))

                            Toggle(isOn: Binding(
                                get: { includeContextOnly },
                                set: { newValue in
                                    includeContextOnly = newValue
                                    if newValue { includeContextAndHistory = false }
                                }
                            )) {
                                Text("Initial Context Only")
                                    .font(.caption)
                                    .foregroundColor(colorScheme.text)
                            }
                            .toggleStyle(.checkbox)
                            .disabled(currentContext.isEmpty && (selectedHistoryItem?.attachedFiles?.isEmpty ?? true) && (selectedHistoryItem?.initialContext.isEmpty ?? true))

                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }

                    // Input area
                    HStack {
                        TextField("Ask a question...", text: $currentQuestion)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(8)
                            .background(colorScheme.secondaryBackground)
                            .cornerRadius(8)
                            .foregroundColor(colorScheme.text)
                            .onSubmit(submitQuestion)

                        Button(action: submitQuestion) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(colorScheme.text)
                                .padding(8)
                                .cornerRadius(8)
                        }
                        .disabled(currentQuestion.isEmpty)
                    }
                    .padding()
                    .background(colorScheme.background)
                }
            }
        }
        .background(colorScheme.background)
        .sheet(isPresented: $showCompactWindow) {
            CompactQueryView(llmManager: llmManager, dataManager: dataManager, initialContext: compactWindowContext)
        }
        .onAppear {
            setupNotificationObserver()
            dataManager.history = dataManager.loadHistory()
        }
    }

    private func submitQuestion() {
        guard !currentQuestion.isEmpty && !isTyping else { return }
        isTyping = true
        let userMessage = HistoryItem.Message(id: UUID(), content: currentQuestion, isUser: true)
        
        if var selectedItem = selectedHistoryItem {
            // Update existing conversation
            selectedItem.conversation.append(userMessage)
            selectedItem.timestamp = Date()
            selectedHistoryItem = selectedItem
            
            let context = buildConversationContext(for: selectedItem)
                       dataManager.processQuestionWithSelectedLLM(question: currentQuestion, context: context) { response in
                           DispatchQueue.main.async {
                               let assistantMessage = HistoryItem.Message(id: UUID(), content: response, isUser: false)
                               selectedItem.conversation.append(assistantMessage)
                               selectedItem.timestamp = Date()
                               self.selectedHistoryItem = selectedItem
                               self.updateHistoryItem(selectedItem)
                               self.isTyping = false
                           }
                       }
        } else {
            // Start a new conversation
            // If there's no initial context, use the first question as the initial context
            let contextToUse = currentContext.isEmpty ? currentQuestion : currentContext

            var newItem = HistoryItem(
                id: UUID(),
                timestamp: Date(),
                initialContext: contextToUse,
                conversation: [userMessage],
                configName: llmManager.activeConfiguration?.name,
                modelName: llmManager.activeConfiguration?.model
            )

            // Set selectedHistoryItem immediately so user message appears
            selectedHistoryItem = newItem

            // Get the full context (loads files on-demand if selectedHistoryItem has attached files)
            let contextToSend = getFullContextWithFiles(newItem)
            dataManager.processQuestionWithSelectedLLM(question: currentQuestion, context: contextToSend) { response in
               DispatchQueue.main.async {
                   let assistantMessage = HistoryItem.Message(id: UUID(), content: response, isUser: false)
                   newItem.conversation.append(assistantMessage)
                   newItem.timestamp = Date()
                   self.selectedHistoryItem = newItem
                   self.updateHistoryItem(newItem)
                   self.isTyping = false
               }
           }
        }

        currentQuestion = ""
    }

    private func getFullContextWithFiles(_ item: HistoryItem?) -> String {
        var context = currentContext

        // Load files from the history item if it has attached files
        if let item = item, let files = item.attachedFiles, !files.isEmpty {
            context = ""
            for (index, file) in files.enumerated() {
                if !file.isImage {
                    let fileURL = URL(fileURLWithPath: file.path)
                    if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                        if index > 0 {
                            context += "\n\n---\n\n"
                        }
                        context += content
                    }
                }
            }
        }

        return context
    }

    // Helper: Calculate context for display (token counter)
    private func calculateContextForDisplay() -> String {
        var fullContextText = ""

        if includeContextAndHistory {
            // Include both context and history
            fullContextText = getFullContextWithFiles(selectedHistoryItem)

            if let selectedItem = selectedHistoryItem, !selectedItem.conversation.isEmpty {
                let conversationHistory = selectedItem.conversation.map { $0.isUser ? "User: \($0.content)" : "Assistant: \($0.content)" }.joined(separator: "\n")
                if !fullContextText.isEmpty {
                    fullContextText += "\n\nConversation history:\n"
                } else {
                    fullContextText = "Conversation history:\n"
                }
                fullContextText += conversationHistory
            }

            if !currentQuestion.isEmpty {
                if !fullContextText.isEmpty {
                    fullContextText += "\n\n\(currentQuestion)"
                } else {
                    fullContextText = currentQuestion
                }
            }
        } else if includeContextOnly {
            // Include only context
            fullContextText = getFullContextWithFiles(selectedHistoryItem)
            if !currentQuestion.isEmpty {
                if !fullContextText.isEmpty {
                    fullContextText += "\n\n\(currentQuestion)"
                } else {
                    fullContextText = currentQuestion
                }
            }
        } else {
            // Include neither
            fullContextText = currentQuestion
        }

        return fullContextText
    }

    private func buildConversationContext(for item: HistoryItem) -> String {
        var context = ""

        if includeContextAndHistory {
            // Include both context and history
            // Load file contents if there are attached files
            if let files = item.attachedFiles, !files.isEmpty {
                print("📄 Loading \(files.count) file(s) for context")
                for (index, file) in files.enumerated() {
                    if file.isImage {
                        // For images, just add a placeholder
                        if index > 0 {
                            context += "\n\n---\n\n"
                        }
                        context += "[Image: \(file.name)]"
                    } else {
                        // Load text file content
                        let fileURL = URL(fileURLWithPath: file.path)
                        if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                            if index > 0 {
                                context += "\n\n---\n\n"
                            }
                            context += content
                            print("✅ Loaded file: \(file.name), \(content.count) chars")
                        } else {
                            print("❌ Failed to load file: \(file.path)")
                            if index > 0 {
                                context += "\n\n---\n\n"
                            }
                            context += "[Could not read file: \(file.name)]"
                        }
                    }
                }
            } else if !item.initialContext.isEmpty {
                // Use stored context if no files
                context = item.initialContext
            }

            // Add conversation history
            if !item.conversation.isEmpty {
                let conversationHistory = item.conversation.map { $0.isUser ? "User: \($0.content)" : "Assistant: \($0.content)" }.joined(separator: "\n")
                if !context.isEmpty {
                    context += "\n\nConversation history:\n"
                } else {
                    context = "Conversation history:\n"
                }
                context += conversationHistory
            }
        } else if includeContextOnly {
            // Include only context, no history
            // Load file contents if there are attached files
            if let files = item.attachedFiles, !files.isEmpty {
                print("📄 Loading \(files.count) file(s) for context only")
                for (index, file) in files.enumerated() {
                    if file.isImage {
                        if index > 0 {
                            context += "\n\n---\n\n"
                        }
                        context += "[Image: \(file.name)]"
                    } else {
                        let fileURL = URL(fileURLWithPath: file.path)
                        if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                            if index > 0 {
                                context += "\n\n---\n\n"
                            }
                            context += content
                            print("✅ Loaded file: \(file.name), \(content.count) chars")
                        } else {
                            print("❌ Failed to load file: \(file.path)")
                            if index > 0 {
                                context += "\n\n---\n\n"
                            }
                            context += "[Could not read file: \(file.name)]"
                        }
                    }
                }
            } else if !item.initialContext.isEmpty {
                context = item.initialContext
            }
        }
        // If neither checkbox is selected, return empty context

        return context
    }

    private func updateHistoryItem(_ item: HistoryItem) {
        if let index = dataManager.history.firstIndex(where: { $0.id == item.id }) {
            dataManager.history[index] = item
        } else {
            dataManager.history.append(item)
        }
        dataManager.saveHistory(dataManager.history)
    }

    func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RequestHighlightedText"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo, let text = userInfo["highlightedText"] as? String {
                self.currentContext = text
                self.dataManager.currentContext = text
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UpdateCurrentAnswer"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let question = userInfo["question"] as? String,
               let answer = userInfo["answer"] as? String {
                self.selectedHistoryItem = nil
                let loadedHistory = self.dataManager.loadHistory()
                self.dataManager.history = loadedHistory
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NewHighlightedText"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo, let text = userInfo["text"] as? String {
                self.selectedHistoryItem = nil
                self.currentContext = text
                self.dataManager.currentContext = text
                self.dataManager.currentConversation = []
            }
        }

        NotificationCenter.default.addObserver(
            forName: .openCompactWindow,
            object: nil,
            queue: .main
        ) { notification in
            if let text = notification.userInfo?["text"] as? String {
                self.compactWindowContext = text
                self.showCompactWindow = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: .triggerCompactWindow,
            object: nil,
            queue: .main
        ) { _ in
            self.showCompactWindow = true
        }

        NotificationCenter.default.addObserver(
            forName: .openCompactWindowWithFiles,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let context = userInfo["context"] as? String,
               let filesData = userInfo["files"] as? [[String: String]] {
                let files = filesData.compactMap { dict -> FileAttachment? in
                    guard let name = dict["name"], let path = dict["path"] else { return nil }
                    return FileAttachment(name: name, path: path)
                }
                self.handleFilesContext(context: context, files: files)
            }
        }
    }

    private func handleFilesContext(context: String, files: [FileAttachment]) {
        // Clear any existing conversation and set file context
        selectedHistoryItem = nil
        currentContext = context
        dataManager.currentContext = context

        // Create a new history item with attached files
        let newItem = HistoryItem(
            id: UUID(),
            timestamp: Date(),
            initialContext: context,
            conversation: [],
            configName: llmManager.activeConfiguration?.name,
            modelName: llmManager.activeConfiguration?.model,
            attachedFiles: files
        )

        // Update history
        dataManager.history.append(newItem)
        dataManager.saveHistory(dataManager.history)

        // Open compact window
        AppDelegate.shared.openCompactQueryWindow()
    }

    func deleteHistoryItem(_ item: HistoryItem) {
        dataManager.history.removeAll { $0.id == item.id }
        dataManager.saveHistory(dataManager.history)
        if selectedHistoryItem?.id == item.id {
            selectedHistoryItem = nil
        }
    }

    func clearAllHistory() {
        dataManager.history.removeAll()
        dataManager.saveHistory(dataManager.history)
        selectedHistoryItem = nil
    }

    func deleteFilteredHistory(_ filteredItems: [HistoryItem]) {
        let filteredIDs = Set(filteredItems.map { $0.id })
        dataManager.history.removeAll { filteredIDs.contains($0.id) }
        dataManager.saveHistory(dataManager.history)
        if let selectedID = selectedHistoryItem?.id, filteredIDs.contains(selectedID) {
            selectedHistoryItem = nil
        }
    }

    func startNewConversation() {
        selectedHistoryItem = nil
        currentContext = ""
        currentQuestion = ""
        dataManager.currentConversation = []
        showFullInitialContext = false
    }
}

struct HistorySection: View {
    var history: [HistoryItem]
    var selectedItem: HistoryItem?
    var onSelectItem: (HistoryItem) -> Void
    var onDeleteItem: (HistoryItem) -> Void
    var onDeleteAll: () -> Void
    var onDeleteFiltered: ([HistoryItem]) -> Void
    @ObservedObject var colorScheme = ColorSchemeManager.shared
    @ObservedObject var llmManager: LLMManager

    @State private var searchText = ""
    @State private var selectedConfig: String = "All"
    @State private var showDeleteConfirmation = false
    @State private var deleteType: DeleteType = .all

    enum DeleteType {
        case all
        case filtered
    }

    var filteredHistory: [HistoryItem] {
        var filtered = history

        // Filter by selected config dropdown
        if selectedConfig != "All" {
            filtered = filtered.filter { $0.configName == selectedConfig }
        }

        // Filter by search text - searches through all conversation messages
        if !searchText.isEmpty {
            filtered = filtered.filter { item in
                // Search through all messages in the conversation
                item.conversation.contains { message in
                    message.content.localizedCaseInsensitiveContains(searchText)
                }
            }
        }

        return filtered.sorted(by: { $0.timestamp > $1.timestamp })
    }

    var uniqueConfigs: [String] {
        ["All"] + Array(Set(history.compactMap { $0.configName })).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("History")
                    .font(.headline)
                    .foregroundColor(colorScheme.text)

                Spacer()

                // Show filter count
                if selectedConfig != "All" || !searchText.isEmpty {
                    Text("\(filteredHistory.count)")
                        .font(.caption)
                        .foregroundColor(colorScheme.secondaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .background(colorScheme.background)

            // Config Dropdown Filter
            VStack(alignment: .leading, spacing: 4) {
                Text("Filter by Config")
                    .font(.caption)
                    .foregroundColor(colorScheme.secondaryText)
                    .padding(.horizontal, 8)

                Picker("Config", selection: $selectedConfig) {
                    ForEach(uniqueConfigs, id: \.self) { config in
                        Text(config)
                            .foregroundColor(colorScheme.text)
                            .tag(config)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .padding(.horizontal, 8)
                .foregroundColor(colorScheme.text)
            }
            .padding(.top, 8)
            .background(colorScheme.background)

            // Search Field
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(colorScheme.secondaryText)
                        .font(.system(size: 12))

                    TextField("Search conversations...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(colorScheme.text)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(colorScheme.secondaryText)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(8)
                .background(colorScheme.secondaryBackground)
                .cornerRadius(8)

                if !searchText.isEmpty {
                    Text("Searching all messages in conversations")
                        .font(.caption2)
                        .foregroundColor(colorScheme.secondaryText)
                        .italic()
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(colorScheme.background)

            // Delete buttons
            VStack(spacing: 4) {
                // Show "Delete Filtered" button when filter is active
                if selectedConfig != "All" || !searchText.isEmpty {
                    Button(action: {
                        deleteType = .filtered
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.caption)
                            Text("Delete Filtered (\(filteredHistory.count))")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Always show "Clear All History" button
                Button(action: {
                    deleteType = .all
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.caption)
                        Text("Clear All History")
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .background(colorScheme.background)
            .alert(
                deleteType == .all ? "Clear All History" : "Delete Filtered History",
                isPresented: $showDeleteConfirmation
            ) {
                Button("Cancel", role: .cancel) { }
                Button(
                    deleteType == .all ? "Delete All (\(history.count))" : "Delete \(filteredHistory.count) Items",
                    role: .destructive
                ) {
                    if deleteType == .all {
                        onDeleteAll()
                    } else {
                        onDeleteFiltered(filteredHistory)
                    }
                }
            } message: {
                if deleteType == .all {
                    Text("Are you sure you want to delete all \(history.count) conversation(s)? This cannot be undone.")
                } else {
                    Text("Are you sure you want to delete \(filteredHistory.count) filtered conversation(s)? This cannot be undone.")
                }
            }

            // History List
            ScrollViewReader { proxy in
                List {
                    ForEach(filteredHistory) { item in
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.conversation.first?.content ?? "")
                                    .font(.system(size: 14))
                                    .foregroundColor(colorScheme.text)
                                    .lineLimit(2)
                                    .truncationMode(.tail)

                                HStack(spacing: 4) {
                                    if let configName = item.configName {
                                        Text(configName)
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(4)
                                    }

                                    if let modelName = item.modelName {
                                        Text(modelName)
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.2))
                                            .cornerRadius(4)
                                    }

                                    // Check if context was truncated
                                    if wasTruncated(item) {
                                        HStack(spacing: 2) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.system(size: 8))
                                            Text("Truncated")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .cornerRadius(4)
                                    }
                                }

                                Text("\(item.timestamp, formatter: itemFormatter)")
                                    .font(.caption2)
                                    .foregroundColor(colorScheme.secondaryText)
                            }

                            Spacer()

                            Button(action: {
                                onDeleteItem(item)
                            }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(
                            selectedItem?.id == item.id
                                ? (colorScheme.isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.1))
                                : Color.clear
                        )
                        .cornerRadius(6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectItem(item)
                        }
                        .id(item.id)
                }
                .listRowBackground(colorScheme.background)
                .listRowInsets(EdgeInsets())
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .background(colorScheme.background)
            .onChange(of: filteredHistory.first?.id) { oldId, newId in
                if let newId = newId {
                    withAnimation {
                        proxy.scrollTo(newId, anchor: .top)
                    }
                }
            }
        }
        }
        .frame(width: 280)
        .background(colorScheme.background)
    }

    // Helper function to check if a history item was truncated
    private func wasTruncated(_ item: HistoryItem) -> Bool {
        guard let config = llmManager.configurations.first(where: { $0.name == item.configName }) else {
            return false
        }

        var contextText = ""

        // Load file contents if there are attached files
        if let files = item.attachedFiles, !files.isEmpty {
            for file in files {
                if !file.isImage {
                    let fileURL = URL(fileURLWithPath: file.path)
                    if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                        contextText += content + "\n\n"
                    }
                }
            }
        } else if !item.initialContext.isEmpty {
            contextText = item.initialContext
        }

        guard !contextText.isEmpty else {
            return false
        }

        let contextCheck = llmManager.checkContextLimit(text: contextText, config: config)
        return contextCheck.exceeds
    }
}

struct ChatBubble: View {
    let message: HistoryItem.Message
    @ObservedObject var colorScheme: ColorSchemeManager
    @State private var showCopiedMessage = false
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            if message.isUser { Spacer() }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.isUser ? "You" : "ContextKey")
                    .font(.caption)
                    .foregroundColor(colorScheme.secondaryText)

                VStack(alignment: .leading, spacing: 8) {
                    // Display image if present
                    if let imageData = message.imageData, let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 300)
                            .cornerRadius(8)
                    } else if let imageURL = message.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 200, height: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 300)
                                    .cornerRadius(8)
                            case .failure:
                                VStack {
                                    Image(systemName: "photo.fill")
                                        .foregroundColor(.gray)
                                    Text("Failed to load image")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 200, height: 100)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }

                    // Display text if present
                    if !message.content.isEmpty {
                        if message.isUser {
                            // User messages: plain text with bubble
                            Text(message.content)
                                .padding(10)
                                .background(colorScheme.userMessageBackground)
                                .foregroundColor(colorScheme.userMessageText)
                                .cornerRadius(15)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: 500, alignment: .trailing)
                        } else {
                            // Assistant messages: render markdown, no bubble, full width
                            MarkdownText(content: message.content, colorScheme: colorScheme)
                                .foregroundColor(colorScheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if !message.isUser {
                VStack(spacing: 2) {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                        showCopiedMessage = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopiedMessage = false
                        }
                    }) {
                        Image(systemName: showCopiedMessage ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(showCopiedMessage ? .green : colorScheme.secondaryText)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if showCopiedMessage {
                        Text("Copied")
                            .font(.caption2)
                            .foregroundColor(colorScheme.secondaryText)
                    }
                }
                .frame(width: 40)
            }

            if !message.isUser { Spacer() }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct TypingIndicator: View {
    let colorScheme: ColorSchemeManager

    var body: some View {
        HStack {
            Text("ContextKey is thinking")
                .font(.caption)
                .foregroundColor(colorScheme.secondaryText)
            TypingAnimation(colorScheme: colorScheme)
        }
        .padding(8)
        .background(colorScheme.assistantMessageBackground)
        .cornerRadius(15)
    }
}

import SwiftUI

struct MarkdownText: View {
    let content: String
    let colorScheme: ColorSchemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseMarkdown(content), id: \.id) { block in
                block.view(colorScheme: colorScheme)
            }
        }
    }

    private func parseMarkdown(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var currentText = ""
        var inCodeBlock = false
        var codeLanguage = ""
        var codeContent = ""

        let lines = text.components(separatedBy: .newlines)
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Check for code block start
            if line.hasPrefix("```") {
                // Save any accumulated text
                if !currentText.isEmpty {
                    blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentText = ""
                }

                if inCodeBlock {
                    // End of code block
                    blocks.append(.code(language: codeLanguage, content: codeContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                    codeContent = ""
                    codeLanguage = ""
                    inCodeBlock = false
                } else {
                    // Start of code block
                    codeLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                    inCodeBlock = true
                }
            } else if inCodeBlock {
                codeContent += line + "\n"
            } else {
                currentText += line + "\n"
            }

            i += 1
        }

        // Add remaining text
        if !currentText.isEmpty {
            blocks.append(.text(currentText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        return blocks
    }
}

enum MarkdownBlock: Identifiable {
    case text(String)
    case code(language: String, content: String)

    var id: String {
        switch self {
        case .text(let content):
            return "text-\(content.hashValue)"
        case .code(let language, let content):
            return "code-\(language)-\(content.hashValue)"
        }
    }

    @ViewBuilder
    func view(colorScheme: ColorSchemeManager) -> some View {
        switch self {
        case .text(let content):
            InlineMarkdownText(content: content, colorScheme: colorScheme)
        case .code(let language, let content):
            CodeBlockView(language: language, content: content, colorScheme: colorScheme)
        }
    }
}

struct InlineMarkdownText: View {
    let content: String
    @ObservedObject var colorScheme: ColorSchemeManager

    var body: some View {
        Text(parseInlineMarkdown(content))
            .textSelection(.enabled)
    }

    private func parseInlineMarkdown(_ text: String) -> AttributedString {
        // Use built-in markdown parser
        var result: AttributedString
        do {
            result = try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnly))
        } catch {
            // Fallback to plain text if markdown parsing fails
            result = AttributedString(text)
        }

        // Set base text color
        result.foregroundColor = colorScheme.isDarkMode ? .white : .black

        // Apply custom styling to inline code (add grey background)
        var currentIndex = result.startIndex
        while currentIndex < result.endIndex {
            let nextIndex = result.index(afterCharacter: currentIndex)

            // Check if this is inline code (has monospaced font from markdown parser)
            if let font = result[currentIndex..<nextIndex].inlinePresentationIntent,
               font.contains(.code) {
                // Apply custom background for inline code
                result[currentIndex..<nextIndex].backgroundColor = colorScheme.isDarkMode ? Color(white: 0.2) : Color(white: 0.9)
                result[currentIndex..<nextIndex].foregroundColor = colorScheme.isDarkMode ? Color.white : Color.black
            }

            currentIndex = nextIndex
        }

        return result
    }
}

struct CodeBlockView: View {
    let language: String
    let content: String
    let colorScheme: ColorSchemeManager
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language and copy button
            HStack {
                Text(language.isEmpty ? "code" : language)
                    .font(.caption)
                    .foregroundColor(colorScheme.secondaryText)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopied = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        Text(showCopied ? "Copied" : "Copy")
                    }
                    .font(.caption)
                    .foregroundColor(showCopied ? .green : colorScheme.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(colorScheme.isDarkMode ? Color(white: 0.15) : Color(white: 0.92))

            // Code content with syntax highlighting
            ScrollView(.horizontal, showsIndicators: true) {
                SyntaxHighlightedText(content: content, language: language, colorScheme: colorScheme)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .textSelection(.enabled)
            }
            .background(colorScheme.isDarkMode ? Color(white: 0.1) : Color(white: 0.95))
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(colorScheme.border, lineWidth: 1)
        )
    }
}

struct SyntaxHighlightedText: View {
    let content: String
    let language: String
    @ObservedObject var colorScheme: ColorSchemeManager

    var body: some View {
        Text(highlightSyntax())
    }

    private func highlightSyntax() -> AttributedString {
        var result = AttributedString(content)

        // Define color scheme
        let keywordColor: Color = .purple
        let stringColor: Color = .red
        let commentColor: Color = .green
        let numberColor: Color = .blue
        let functionColor: Color = .cyan

        // Common keywords across languages
        let keywords = [
            "func", "function", "def", "class", "struct", "enum", "var", "let", "const",
            "if", "else", "for", "while", "return", "import", "from", "as", "try", "catch",
            "switch", "case", "break", "continue", "in", "public", "private", "static",
            "async", "await", "throw", "throws", "guard", "override", "self", "this",
            "true", "false", "nil", "null", "void", "int", "string", "bool", "float", "double"
        ]

        // Highlight strings (simple approach)
        highlightPattern(in: &result, pattern: "\"[^\"]*\"", color: stringColor)
        highlightPattern(in: &result, pattern: "'[^']*'", color: stringColor)

        // Highlight comments
        highlightPattern(in: &result, pattern: "//.*", color: commentColor)
        highlightPattern(in: &result, pattern: "#.*", color: commentColor)

        // Highlight numbers
        highlightPattern(in: &result, pattern: "\\b\\d+\\b", color: numberColor)

        // Highlight keywords
        for keyword in keywords {
            highlightPattern(in: &result, pattern: "\\b\(keyword)\\b", color: keywordColor)
        }

        return result
    }

    private func highlightPattern(in text: inout AttributedString, pattern: String, color: Color) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let nsString = String(text.characters) as NSString
        let matches = regex.matches(in: String(text.characters), range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            if let range = Range(match.range, in: String(text.characters)) {
                let startIndex = text.index(text.startIndex, offsetByCharacters: range.lowerBound.utf16Offset(in: String(text.characters)))
                let endIndex = text.index(text.startIndex, offsetByCharacters: range.upperBound.utf16Offset(in: String(text.characters)))
                text[startIndex..<endIndex].foregroundColor = color
            }
        }
    }
}

// Smart text view with expand button that only shows when text is actually truncated
struct TextWithExpandButton: View {
    let text: String
    @Binding var isExpanded: Bool
    let font: Font
    let lineLimit: Int
    @ObservedObject var colorScheme: ColorSchemeManager

    @State private var isTruncated: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(font)
                .foregroundColor(colorScheme.secondaryText)
                .lineLimit(isExpanded ? nil : lineLimit)
                .background(
                    GeometryReader { geometry in
                        Color.clear.onAppear {
                            checkIfTruncated(geometry: geometry)
                        }
                        .onChange(of: geometry.size.width) {
                            checkIfTruncated(geometry: geometry)
                        }
                    }
                )

            if isTruncated || isExpanded {
                Button(action: { isExpanded.toggle() }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show Less" : "Show More")
                            .font(.caption)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func checkIfTruncated(geometry: GeometryProxy) {
        let fullText = Text(text).font(font)
        let limitedText = Text(text).font(font).lineLimit(lineLimit)

        // Create a temporary view to measure
        let fullHeight = fullText.fixedSize(horizontal: false, vertical: true).frame(width: geometry.size.width)
        let limitedHeight = limitedText.frame(width: geometry.size.width)

        // Simple heuristic: if text has more than lineLimit newlines or is very long, it's likely truncated
        let hasMultipleLines = text.split(separator: "\n").count > lineLimit
        let isLongText = text.count > 1000

        isTruncated = hasMultipleLines || isLongText
    }
}
