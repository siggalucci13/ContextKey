import SwiftUI
import Combine

// MARK: - Color Scheme Manager
class ColorSchemeManager: ObservableObject {
    static let shared = ColorSchemeManager()

    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }

    private init() {
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
    }

    var background: Color {
        isDarkMode ? Color.black : Color.white
    }

    var secondaryBackground: Color {
        isDarkMode ? Color(white: 0.15) : Color(white: 0.95)
    }

    var tertiaryBackground: Color {
        isDarkMode ? Color(white: 0.2) : Color(white: 0.9)
    }

    var text: Color {
        isDarkMode ? Color(white: 1.0) : Color(white: 0.0)
    }

    var secondaryText: Color {
        isDarkMode ? Color.gray : Color(white: 0.4)
    }

    var userMessageBackground: Color {
        isDarkMode ? Color.white : Color.black
    }

    var assistantMessageBackground: Color {
        isDarkMode ? Color(white: 0.15) : Color(white: 0.95)
    }

    var userMessageText: Color {
        isDarkMode ? Color.black : Color.white
    }

    var assistantMessageText: Color {
        text
    }

    var divider: Color {
        isDarkMode ? Color.gray : Color(white: 0.8)
    }

    var border: Color {
        isDarkMode ? Color(white: 0.3) : Color(white: 0.85)
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    var content: String
    let isUser: Bool
    var imageURL: String?
    var imageData: Data?

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isTyping: Bool = false
    
    func addMessage(_ message: ChatMessage) {
        messages.append(message)
    }
    
    func updateLastMessage(content: String) {
        if var lastMessage = messages.last, !lastMessage.isUser {
            lastMessage.content += content
            messages[messages.count - 1] = lastMessage
        } else {
            addMessage(ChatMessage(content: content, isUser: false))
        }
    }
    
    func clearChat() {
        messages.removeAll()
    }
}

struct CompactQueryView: View {
    @ObservedObject var llmManager: LLMManager
    @ObservedObject var dataManager: DataManager
    @StateObject private var chatManager = ChatManager()
    @ObservedObject var colorScheme = ColorSchemeManager.shared
    @State private var initialContext: String = ""
    @State private var question: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showFullInitialContext: Bool = false
    @FocusState private var isQuestionFocused: Bool
    @State private var currentHistoryItem: HistoryItem?
    @State private var conversationStarted: Bool = false
    @State private var attachedFiles: [FileAttachment] = []
    @State private var copiedMessageId: UUID?
    @State private var includeContextAndHistory: Bool = true
    @State private var includeContextOnly: Bool = false

    init(llmManager: LLMManager, dataManager: DataManager, initialContext: String, attachedFiles: [FileAttachment] = []) {
        self.llmManager = llmManager
        self.dataManager = dataManager
        self._initialContext = State(initialValue: initialContext)
        self._attachedFiles = State(initialValue: attachedFiles)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            chatView

            Divider()
                .background(colorScheme.divider)

            inputView
        }
        .frame(width: 400, height: 500)
        .background(colorScheme.background)
        .onAppear {
            initializeHistoryItem()
        }
        .onChange(of: initialContext) {
            // Reset conversation state when context changes (window reused)
            conversationStarted = false
            showFullInitialContext = false
            chatManager.clearChat()
            initializeHistoryItem()
        }
    }
    
    private func initializeHistoryItem() {
        currentHistoryItem = HistoryItem(
            id: UUID(),
            timestamp: Date(),
            initialContext: initialContext,
            conversation: [],
            configName: llmManager.activeConfiguration?.name,
            modelName: llmManager.activeConfiguration?.model,
            attachedFiles: attachedFiles.isEmpty ? nil : attachedFiles
        )
    }

    // Helper: Load file contents on-demand
    private func getFullContext() -> String {
        // If we have attached files, load their contents
        if !attachedFiles.isEmpty {
            var context = ""
            for (index, file) in attachedFiles.enumerated() {
                if !file.isImage {
                    let fileURL = URL(fileURLWithPath: file.path)
                    if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                        if index > 0 {
                            context += "\n\n---\n\n"
                        }
                        context += content
                    } else {
                        if index > 0 {
                            context += "\n\n---\n\n"
                        }
                        context += "[Could not read file: \(file.name)]"
                    }
                }
            }
            return context
        }

        // Otherwise use the initial context
        return initialContext
    }

    // Helper: Calculate context for display (token counter)
    private func calculateContextForDisplay() -> String {
        var fullContextText = ""

        if includeContextAndHistory {
            // Include both context and history
            fullContextText = getFullContext()

            if !chatManager.messages.isEmpty {
                let conversationHistory = chatManager.messages.map { $0.content }.joined(separator: "\n\n")
                if !fullContextText.isEmpty {
                    fullContextText += "\n\n"
                }
                fullContextText += conversationHistory
            }

            if !fullContextText.isEmpty {
                fullContextText += "\n\n\(question)"
            } else {
                fullContextText = question
            }
        } else if includeContextOnly {
            // Include only context
            fullContextText = getFullContext()
            if !fullContextText.isEmpty {
                fullContextText += "\n\n\(question)"
            } else {
                fullContextText = question
            }
        } else {
            // Include neither
            fullContextText = question
        }

        return fullContextText
    }
    
    private var chatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    // Show initial context ONLY if no files are attached
                    if !initialContext.isEmpty && attachedFiles.isEmpty {
                        initialContextView
                    }

                    // Show attached files
                    if !attachedFiles.isEmpty {
                        attachedFilesView
                    }

                    ForEach(chatManager.messages) { message in
                        messageView(for: message)
                    }

                    if chatManager.isTyping {
                        typingIndicator
                            .id("typing")
                    }

                    // Invisible anchor for scrolling to bottom
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding()
            }
            .onChange(of: chatManager.messages.count) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .onChange(of: chatManager.isTyping) { _, newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private var attachedFilesView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "paperclip")
                    .font(.caption)
                Text("Attached Files (\(attachedFiles.count))")
                    .font(.caption)
                    .foregroundColor(colorScheme.secondaryText)
                Spacer()
            }

            VStack(spacing: 4) {
                ForEach(attachedFiles) { file in
                    if file.isImage, let imageData = file.imageData, let nsImage = NSImage(data: imageData) {
                        // Image preview
                        VStack(alignment: .leading, spacing: 4) {
                            Button(action: {
                                let fileURL = URL(fileURLWithPath: file.path)
                                NSWorkspace.shared.open(fileURL)
                            }) {
                                VStack(spacing: 4) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 150)
                                        .cornerRadius(4)

                                    HStack {
                                        Image(systemName: "photo.fill")
                                            .foregroundColor(.blue)
                                            .font(.caption2)
                                        Text(file.name)
                                            .font(.caption2)
                                            .foregroundColor(colorScheme.text)
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.caption2)
                                            .foregroundColor(colorScheme.secondaryText)
                                    }
                                }
                                .padding(6)
                                .background(colorScheme.tertiaryBackground)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
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
                        }
                    } else {
                        // Regular file
                        Button(action: {
                            let fileURL = URL(fileURLWithPath: file.path)
                            NSWorkspace.shared.open(fileURL)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption2)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(file.name)
                                        .font(.caption2)
                                        .foregroundColor(colorScheme.text)
                                        .fontWeight(.medium)
                                    Text(file.path)
                                        .font(Font.system(size: 9))
                                        .foregroundColor(colorScheme.secondaryText)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption2)
                                    .foregroundColor(colorScheme.secondaryText)
                            }
                            .padding(6)
                            .background(colorScheme.tertiaryBackground)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
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
        }
        .padding(8)
        .background(colorScheme.secondaryBackground)
        .cornerRadius(8)
    }
    
    private var initialContextView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Initial Context")
                .font(.caption)
                .foregroundColor(colorScheme.secondaryText)

            TextWithExpandButton(
                text: initialContext,
                isExpanded: $showFullInitialContext,
                font: .body,
                lineLimit: 10,
                colorScheme: colorScheme
            )
            .padding(8)
            .background(colorScheme.secondaryBackground)
            .cornerRadius(8)
        }
    }
    
    private func messageView(for message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 5) {
                if !message.isUser {
                    Text("ContextKey")
                        .font(.caption)
                        .foregroundColor(colorScheme.secondaryText)
                } else {
                    Text("You")
                        .font(.caption)
                        .foregroundColor(colorScheme.secondaryText)
                }

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
                        } else {
                            // Assistant messages: render markdown, no bubble, full width
                            let textColor = colorScheme.text
                            let _ = print("🎨 Assistant message - using color: \(textColor)")
                            MarkdownText(content: message.content, colorScheme: colorScheme)
                                .foregroundColor(textColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: message.isUser ? 350 : .infinity, alignment: message.isUser ? .trailing : .leading)
            }

            if !message.isUser {
                VStack(spacing: 2) {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                        copiedMessageId = message.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedMessageId = nil
                        }
                    }) {
                        Image(systemName: copiedMessageId == message.id ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(copiedMessageId == message.id ? .green : colorScheme.secondaryText)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if copiedMessageId == message.id {
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
    
    private var typingIndicator: some View {
        HStack {
            Text("ContextKey is thinking")
                .font(.caption)
                .foregroundColor(colorScheme.secondaryText)
            TypingAnimation(colorScheme: colorScheme)
        }
        .padding(8)
        .background(colorScheme.secondaryBackground)
        .cornerRadius(15)
    }
    
    private var inputView: some View {
        VStack(spacing: 10) {
            // Config Display/Selector
            HStack(spacing: 8) {
                Text("Config:")
                    .font(.caption)
                    .foregroundColor(colorScheme.secondaryText)

                if llmManager.configurations.isEmpty {
                    Text("No configs - go to Settings")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if conversationStarted {
                    // Show as read-only label once conversation started
                    if let activeConfig = llmManager.activeConfiguration {
                        HStack(spacing: 4) {
                            Text(activeConfig.name)
                                .font(.caption)
                                .foregroundColor(.blue)
                            if let model = activeConfig.model {
                                Text("(\(model))")
                                    .font(.caption2)
                                    .foregroundColor(colorScheme.secondaryText)
                            }
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundColor(colorScheme.secondaryText)
                        }
                    }
                } else {
                    // Show as dropdown before conversation starts
                    Picker("", selection: Binding(
                        get: { llmManager.activeConfiguration?.id ?? "" },
                        set: { newId in
                            if let config = llmManager.configurations.first(where: { $0.id == newId }) {
                                llmManager.setActiveConfiguration(config)
                                // Update current history item with new config
                                currentHistoryItem?.configName = config.name
                                currentHistoryItem?.modelName = config.model
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
                    .foregroundColor(colorScheme.text)
                }

                Spacer()
            }
            .padding(.horizontal, 8)

            // Context usage indicator
            if !attachedFiles.isEmpty || !initialContext.isEmpty || !question.isEmpty || !chatManager.messages.isEmpty {
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
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(contextCheck.exceeds ? Color.orange.opacity(0.1) : Color.clear)
                .cornerRadius(6)
            }

            // Context options checkboxes
            if !attachedFiles.isEmpty || !initialContext.isEmpty || !chatManager.messages.isEmpty {
                HStack(spacing: 16) {
                    Toggle(isOn: Binding(
                        get: { includeContextAndHistory },
                        set: { newValue in
                            includeContextAndHistory = newValue
                            if newValue { includeContextOnly = false }
                        }
                    )) {
                        Text("Initial Context + Chat")
                            .font(.caption)
                            .foregroundColor(colorScheme.text)
                    }
                    .toggleStyle(.checkbox)
                    .disabled(attachedFiles.isEmpty && initialContext.isEmpty)

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
                    .disabled(attachedFiles.isEmpty && initialContext.isEmpty)

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            HStack {
                FocusableTextField(text: $question, textColor: colorScheme.text, onSubmit: submitQuery)
                    .padding(8)
                    .background(colorScheme.tertiaryBackground)
                    .cornerRadius(8)

                Button(action: submitQuery) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(colorScheme.text)
                        .padding(8)
                        .cornerRadius(8)
                }
                .disabled(question.isEmpty || isLoading || llmManager.activeConfiguration == nil)
            }
        }
        .padding()
        .background(colorScheme.secondaryBackground)
    }
    
    private func submitQuery() {
        guard !question.isEmpty && !isLoading else { return }
        isLoading = true
        errorMessage = nil

        // If this is the first message and there's no initial context, use the question as initial context
        if !conversationStarted && initialContext.isEmpty && attachedFiles.isEmpty {
            initialContext = question
            initializeHistoryItem()
        }

        // Lock the config after first message
        conversationStarted = true

        let userMessage = ChatMessage(content: question, isUser: true)
        chatManager.addMessage(userMessage)
        updateHistoryItem(with: userMessage)

        // Build combined input based on user's context preferences
        var combinedInput = ""

        if includeContextAndHistory {
            let fullContext = getFullContext()
            if !fullContext.isEmpty {
                combinedInput = fullContext
            }

            if chatManager.messages.count > 1 {
                let conversationHistory = chatManager.messages.dropLast().map { $0.content }.joined(separator: "\n\n")
                if !conversationHistory.isEmpty {
                    if !combinedInput.isEmpty {
                        combinedInput += "\n\n"
                    }
                    combinedInput += conversationHistory
                }
            }

            if !combinedInput.isEmpty {
                combinedInput += "\n\n\(question)"
            } else {
                combinedInput = question
            }
        } else if includeContextOnly {
            let fullContext = getFullContext()
            if !fullContext.isEmpty {
                combinedInput = "\(fullContext)\n\n\(question)"
            } else {
                combinedInput = question
            }
        } else {
            combinedInput = question
        }
        
        guard let activeConfig = llmManager.activeConfiguration else {
            isLoading = false
            errorMessage = "No active LLM configuration"
            return
        }
        
        chatManager.isTyping = true

        switch activeConfig.type {
        case .custom:
            processCustomAPIQuery(input: combinedInput, config: activeConfig)
        case .ollama:
            processOllamaQuery(input: combinedInput, config: activeConfig)
        }
        
        question = ""
    }
    
    private func processOllamaQuery(input: String, config: LLMConfiguration) {
        guard let apiEndpoint = config.apiEndpoint, let model = config.model else {
            isLoading = false
            errorMessage = "Invalid Ollama configuration"
            return
        }

        let url = URL(string: "\(apiEndpoint)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let fullPrompt = input

        var body: [String: Any] = [
            "model": model,
            "prompt": fullPrompt,
            "stream": true
        ]

        // Add images if present
        let imageFiles = attachedFiles.filter { $0.isImage }
        if !imageFiles.isEmpty {
            var base64Images: [String] = []
            for imageFile in imageFiles {
                if let imageData = imageFile.imageData {
                    let base64String = imageData.base64EncodedString()
                    base64Images.append(base64String)
                }
            }
            if !base64Images.isEmpty {
                body["images"] = base64Images
            }
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Error creating request body: \(error)")
            self.isLoading = false
            self.errorMessage = "Error creating request: \(error.localizedDescription)"
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.chatManager.isTyping = false
                    self.errorMessage = error?.localizedDescription ?? "No data received"
                }
                return
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            data.split(separator: UInt8(ascii: "\n")).forEach { line in
                if let ollamaResponse = try? decoder.decode(OllamaResponse.self, from: Data(line)) {
                    DispatchQueue.main.async {
                        self.chatManager.updateLastMessage(content: ollamaResponse.response)
                        
                        if ollamaResponse.done {
                            self.isLoading = false
                            self.chatManager.isTyping = false
                            if let lastMessage = self.chatManager.messages.last {
                                self.updateHistoryItem(with: lastMessage)
                            }
                        }
                    }
                } else {
                    print("Failed to decode JSON: \(String(data: Data(line), encoding: .utf8) ?? "Invalid data")")
                }
            }
        }

        task.resume()
    }

    private func processCustomAPIQuery(input: String, config: LLMConfiguration) {
        // Use DataManager's custom API handling which properly handles templates, headers, etc.
        dataManager.processQuestionWithSelectedLLM(question: "", context: input) { response in
            DispatchQueue.main.async {
                self.isLoading = false
                self.chatManager.isTyping = false

                if response.hasPrefix("Error:") {
                    self.errorMessage = response
                } else {
                    let assistantMessage = ChatMessage(content: response, isUser: false)
                    self.chatManager.addMessage(assistantMessage)
                    self.updateHistoryItem(with: assistantMessage)
                }
            }
        }
    }

    private func updateHistoryItem(with message: ChatMessage) {
        guard var historyItem = currentHistoryItem else {
            print("Error: No current history item")
            return
        }
        
        let historyMessage = HistoryItem.Message(id: message.id, content: message.content, isUser: message.isUser)
        historyItem.conversation.append(historyMessage)
        historyItem.timestamp = Date()  // Update timestamp
        
        currentHistoryItem = historyItem
        
        // Update the history in DataManager
        if let index = dataManager.history.firstIndex(where: { $0.id == historyItem.id }) {
            dataManager.history[index] = historyItem
        } else {
            dataManager.history.append(historyItem)
        }
        
        dataManager.saveHistory(dataManager.history)
    }
    
    func resetChat(with newContext: String) {
        chatManager.clearChat()
        initialContext = newContext
        showFullInitialContext = false
        conversationStarted = false
        initializeHistoryItem()
    }
}

struct TypingAnimation: View {
    let colorScheme: ColorSchemeManager
    @State private var showFirstDot = false
    @State private var showSecondDot = false
    @State private var showThirdDot = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(colorScheme.secondaryText)
                .frame(width: 6, height: 6)
                .scaleEffect(showFirstDot ? 1 : 0.5)
            Circle()
                .fill(colorScheme.secondaryText)
                .frame(width: 6, height: 6)
                .scaleEffect(showSecondDot ? 1 : 0.5)
            Circle()
                .fill(colorScheme.secondaryText)
                .frame(width: 6, height: 6)
                .scaleEffect(showThirdDot ? 1 : 0.5)
        }
        .onAppear {
            animateDots()
        }
    }
    
    private func animateDots() {
        withAnimation(Animation.easeInOut(duration: 0.4).repeatForever()) {
            showFirstDot.toggle()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(Animation.easeInOut(duration: 0.4).repeatForever()) {
                showSecondDot.toggle()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(Animation.easeInOut(duration: 0.4).repeatForever()) {
                showThirdDot.toggle()
            }
        }
    }
}

struct OllamaResponse: Codable {
    let model: String
    let createdAt: String
    let response: String
    let done: Bool
}

// Custom TextField wrapper that can be focused via notification
struct FocusableTextField: NSViewRepresentable {
    @Binding var text: String
    var textColor: Color
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = "Ask a question..."
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.drawsBackground = false

        // Store reference for later focus
        context.coordinator.textField = textField

        // Listen for focus notification
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.focusTextField),
            name: .focusTextField,
            object: nil
        )

        // Try to focus immediately when created
        DispatchQueue.main.async {
            textField.window?.makeFirstResponder(textField)
        }

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Only update text if it's different to avoid interfering with typing
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        // Update text color based on color scheme
        nsView.textColor = NSColor(textColor)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FocusableTextField
        weak var textField: NSTextField?

        init(_ parent: FocusableTextField) {
            self.parent = parent
        }

        @objc func focusTextField() {
            print("🎯 focusTextField notification received")
            DispatchQueue.main.async { [weak self] in
                if let textField = self?.textField, let window = textField.window {
                    print("🎯 Attempting to make textField first responder")
                    print("🎯 Window is key: \(window.isKeyWindow)")
                    print("🎯 Window is main: \(window.isMainWindow)")

                    // Make window key first
                    window.makeKey()
                    window.makeMain()

                    // Then focus the text field
                    let success = window.makeFirstResponder(textField)
                    print("🎯 Focus success: \(success)")

                    // Force cursor to appear by selecting all then deselecting
                    if success {
                        textField.currentEditor()?.selectedRange = NSRange(location: 0, length: 0)
                    }
                } else {
                    print("🎯 ERROR: textField or window is nil")
                }
            }
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
