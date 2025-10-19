import SwiftUI

struct HistoryItem: Identifiable, Codable {
    let id: UUID
    var timestamp: Date
    let initialContext: String
    var conversation: [Message]

    struct Message: Identifiable, Codable {
        let id: UUID
        var content: String
        let isUser: Bool
    }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, initialContext, conversation
    }

    init(id: UUID = UUID(), timestamp: Date = Date(), initialContext: String, conversation: [Message]) {
        self.id = id
        self.timestamp = timestamp
        self.initialContext = initialContext
        self.conversation = conversation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        initialContext = try container.decode(String.self, forKey: .initialContext)
        conversation = try container.decode([Message].self, forKey: .conversation)

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
    }
}

struct ContentView: View {
    @ObservedObject var llmManager: LLMManager
    @ObservedObject var mqttManager: MQTTManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @State private var currentContext: String = ""
    @State private var currentQuestion: String = ""
    @State private var isHistoryVisible = false
    @State private var showSettings = false
    @State private var showCompactWindow = false
    @State private var compactWindowContext = ""
    @State private var selectedHistoryItem: HistoryItem?
    @State private var isTyping: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: {
                    isHistoryVisible.toggle()
                }) {
                    Text(isHistoryVisible ? "Close History" : "Show History")
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .cornerRadius(5)
                }
                .padding(.leading)

                Button(action: {
                    showSettings.toggle()
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.white)
                        .font(.title2)
                }
                .padding(.leading, 10)

                if let activeConfig = llmManager.activeConfiguration {
                    Text("\(activeConfig.name)")
                        .foregroundColor(.lightBlue)
                        .padding(.leading, 10)
                }

                Spacer()

                Text("ContextKey")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.lightBlue)
                    .padding()
                    .shadow(color: .black, radius: 2, x: 0, y: 2)
            }
            .frame(height: 60)
            .background(Color.darkGray)

            // Main content
            HStack(spacing: 0) {
                if isHistoryVisible {
                    HistorySection(
                        history: mqttManager.history,
                        onSelectItem: { item in
                            selectedHistoryItem = item
                            currentContext = item.initialContext
                        },
                        onDeleteItem: { item in
                            deleteHistoryItem(item)
                        }
                    )
                }

                // Main Area
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if let selectedItem = selectedHistoryItem {
                                Text("Initial Context:")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Text(selectedItem.initialContext)
                                    .padding()
                                    .background(Color.darkGray)
                                    .cornerRadius(8)

                                ForEach(selectedItem.conversation) { message in
                                    ChatBubble(message: message)
                                }
                            } else {
                                Text("Initial Context:")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                TextEditor(text: $currentContext)
                                    .frame(height: 100)
                                    .padding(5)
                                    .background(Color.darkGray)
                                    .cornerRadius(8)

                                ForEach(mqttManager.currentConversation) { message in
                                    ChatBubble(message: message)
                                }
                            }
                        }
                        .padding()
                    }
                    .background(Color.darkerGray)

                    // Input area
                    HStack {
                        TextField("Ask a question...", text: $currentQuestion)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(8)
                            .background(Color.darkGray)
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .onSubmit(submitQuestion)

                        Button(action: submitQuestion) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .padding(8)
                                .cornerRadius(8)
                        }
                        .disabled(currentQuestion.isEmpty)
                    }
                    .padding()
                    .background(Color.black)
                }
            }
        }
        .background(Color.black)
        .sheet(isPresented: $showSettings) {
            SettingsView(llmManager: llmManager, hotkeyManager: hotkeyManager, mqttManager: mqttManager)
        }
        .sheet(isPresented: $showCompactWindow) {
            CompactQueryView(llmManager: llmManager, mqttManager: mqttManager, initialContext: compactWindowContext)
        }
        .onAppear {
            setupNotificationObserver()
            mqttManager.history = mqttManager.loadHistory()
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
                       mqttManager.processQuestionWithSelectedLLM(question: currentQuestion, context: context) { response in
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
            var newItem = HistoryItem(id: UUID(), timestamp: Date(), initialContext: currentContext, conversation: [userMessage])
                        
            mqttManager.processQuestionWithSelectedLLM(question: currentQuestion, context: currentContext) { response in
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

    private func buildConversationContext(for item: HistoryItem) -> String {
        let conversationHistory = item.conversation.map { $0.isUser ? "User: \($0.content)" : "Assistant: \($0.content)" }.joined(separator: "\n")
        return "\(item.initialContext)\n\nConversation history:\n\(conversationHistory)"
    }

    private func updateHistoryItem(_ item: HistoryItem) {
        if let index = mqttManager.history.firstIndex(where: { $0.id == item.id }) {
            mqttManager.history[index] = item
        } else {
            mqttManager.history.append(item)
        }
        mqttManager.saveHistory(mqttManager.history)
    }

    func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RequestHighlightedText"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo, let text = userInfo["highlightedText"] as? String {
                self.currentContext = text
                self.mqttManager.currentContext = text
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
                let loadedHistory = self.mqttManager.loadHistory()
                self.mqttManager.history = loadedHistory
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
                self.mqttManager.currentContext = text
                self.mqttManager.currentConversation = []
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
    }

    func deleteHistoryItem(_ item: HistoryItem) {
        mqttManager.history.removeAll { $0.id == item.id }
        mqttManager.saveHistory(mqttManager.history)
        if selectedHistoryItem?.id == item.id {
            selectedHistoryItem = nil
        }
    }
}

struct HistorySection: View {
    var history: [HistoryItem]
    var onSelectItem: (HistoryItem) -> Void
    var onDeleteItem: (HistoryItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("History")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(height: 44)

            List {
                ForEach(history.sorted(by: { $0.timestamp > $1.timestamp })) { item in
                    VStack(alignment: .leading) {
                        Text(item.conversation.first?.content ?? "")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .onTapGesture {
                                onSelectItem(item)
                            }
                            
                        Text("\(item.timestamp, formatter: itemFormatter)")
                            .foregroundColor(.gray)
                        
                        Spacer()
                        Button(action: {
                            onDeleteItem(item)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())
        }
        .frame(width: 250)
        .background(Color.darkGray)
    }
}

struct ChatBubble: View {
    let message: HistoryItem.Message
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            VStack(alignment: .leading, spacing: 4) {
                if !message.isUser {
                    Text("ContextKey:")
                        .font(.caption)
                        .foregroundColor(.lightBlue)
                }
                Text(message.content)
                    .padding(10)
                    .background(Color.darkGray)
                    .foregroundColor(message.isUser ? .white : .lightBlue)
                    .cornerRadius(15)
            }
            if !message.isUser { Spacer() }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

extension Color {
    static let darkGray = Color(red: 40/255, green: 40/255, blue: 40/255)
    static let darkerGray = Color(red: 30/255, green: 30/255, blue: 30/255)
    static let lightBlue = Color(red: 59/255, green: 242/255, blue: 253/255)
}

struct TypingIndicator: View {
    var body: some View {
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
}

