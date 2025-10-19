import SwiftUI
import Combine

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    var content: String
    let isUser: Bool
    
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
    @ObservedObject var mqttManager: MQTTManager
    @StateObject private var chatManager = ChatManager()
    @State private var initialContext: String = ""
    @State private var question: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showInitialContext: Bool = true
    @FocusState private var isQuestionFocused: Bool
    @State private var currentHistoryItem: HistoryItem?
    
    init(llmManager: LLMManager, mqttManager: MQTTManager, initialContext: String) {
        self.llmManager = llmManager
        self.mqttManager = mqttManager
        self._initialContext = State(initialValue: initialContext)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            chatView
            
            Divider()
                .background(Color.gray)
            
            if showInitialContext && !initialContext.isEmpty {
                initialContextView
            }
            
            inputView
        }
        .frame(width: 400, height: 500)
        .background(Color.black)
        .onAppear {
            isQuestionFocused = true
            initializeHistoryItem()
        }
    }
    
    private func initializeHistoryItem() {
        currentHistoryItem = HistoryItem(
            id: UUID(),
            timestamp: Date(),
            initialContext: initialContext,
            conversation: []
        )
    }
    
    private var chatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(chatManager.messages) { message in
                        messageView(for: message)
                    }
                    
                    if chatManager.isTyping {
                        typingIndicator
                    }
                }
                .padding()
            }
            .onChange(of: chatManager.messages) { _, _ in
                if let lastMessage = chatManager.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
    
    private var initialContextView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Initial Context")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Button(action: { showInitialContext = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            Text(initialContext)
                .font(.caption2)
                .foregroundColor(.white)
        }
        .padding(8)
        .background(Color.darkGray)
        .cornerRadius(8)
    }
    
    private func messageView(for message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if !message.isUser {
                Text("ContextKey:")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            HStack {
                if message.isUser {
                    Spacer()
                }
                Text(message.content)
                    .padding(10)
                    .background(Color.darkGray)
                    .foregroundColor(message.isUser ? .white : .lightBlue)
                    .cornerRadius(15)
                if !message.isUser {
                    Spacer()
                }
            }
        }
    }
    
    private var typingIndicator: some View {
        HStack {
            Text("ContextKey is thinking")
                .font(.caption)
                .foregroundColor(.gray)
            TypingAnimation()
        }
        .padding(8)
        .background(Color.darkGray)
        .cornerRadius(15)
    }
    
    private var inputView: some View {
        VStack(spacing: 10) {
            if !showInitialContext && !initialContext.isEmpty {
                Button("Show Initial Context") {
                    showInitialContext = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            HStack {
                TextField("Ask a question...", text: $question, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color.darkGray)
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .focused($isQuestionFocused)
                    .onSubmit(submitQuery)
                
                Button(action: submitQuery) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.gray)
                        .cornerRadius(8)
                }
                .disabled(question.isEmpty || isLoading)
            }
        }
        .padding()
    }
    
    private func submitQuery() {
        guard !question.isEmpty && !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        let userMessage = ChatMessage(content: question, isUser: true)
        chatManager.addMessage(userMessage)
        updateHistoryItem(with: userMessage)
        
        let combinedInput: String
        if chatManager.messages.count == 1 {
            combinedInput = "\(initialContext)\n\nQuestion: \(question)"
            showInitialContext = false
        } else {
            combinedInput = "Previous conversation:\n" + chatManager.messages.dropLast().map { $0.isUser ? "User: \($0.content)" : "Assistant: \($0.content)" }.joined(separator: "\n") + "\n\nNew question: \(question)"
        }
        
        guard let activeConfig = llmManager.activeConfiguration else {
            isLoading = false
            errorMessage = "No active LLM configuration"
            return
        }
        
        chatManager.isTyping = true
        
        switch activeConfig.type {
        case .openAI:
            processOpenAIQuery(input: combinedInput, config: activeConfig)
        case .ollama:
            processOllamaQuery(input: combinedInput, config: activeConfig)
        }
        
        question = ""
    }
    
    private func processOpenAIQuery(input: String, config: LLMConfiguration) {
        guard let apiKey = config.apiKey, let model = config.model else {
            isLoading = false
            errorMessage = "Invalid OpenAI configuration"
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
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                self.chatManager.isTyping = false
                if let error = error {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    return
                }
                guard let data = data else {
                    self.errorMessage = "No data received"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let message = choices.first?["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        let assistantMessage = ChatMessage(content: content.trimmingCharacters(in: .whitespacesAndNewlines), isUser: false)
                        self.chatManager.addMessage(assistantMessage)
                        self.updateHistoryItem(with: assistantMessage)
                    } else {
                        self.errorMessage = "Invalid response format"
                    }
                } catch {
                    self.errorMessage = "Error parsing response: \(error.localizedDescription)"
                }
            }
        }.resume()
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

        let body: [String: Any] = [
            "model": model,
            "prompt": input,
            "stream": true
        ]

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
    
    private func updateHistoryItem(with message: ChatMessage) {
        guard var historyItem = currentHistoryItem else {
            print("Error: No current history item")
            return
        }
        
        let historyMessage = HistoryItem.Message(id: message.id, content: message.content, isUser: message.isUser)
        historyItem.conversation.append(historyMessage)
        historyItem.timestamp = Date()  // Update timestamp
        
        currentHistoryItem = historyItem
        
        // Update the history in MQTTManager
        if let index = mqttManager.history.firstIndex(where: { $0.id == historyItem.id }) {
            mqttManager.history[index] = historyItem
        } else {
            mqttManager.history.append(historyItem)
        }
        
        mqttManager.saveHistory(mqttManager.history)
    }
    
    func resetChat(with newContext: String) {
        chatManager.clearChat()
        initialContext = newContext
        showInitialContext = true
        initializeHistoryItem()
    }
}

struct TypingAnimation: View {
    @State private var showFirstDot = false
    @State private var showSecondDot = false
    @State private var showThirdDot = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.gray)
                .frame(width: 6, height: 6)
                .scaleEffect(showFirstDot ? 1 : 0.5)
            Circle()
                .fill(Color.gray)
                .frame(width: 6, height: 6)
                .scaleEffect(showSecondDot ? 1 : 0.5)
            Circle()
                .fill(Color.gray)
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
