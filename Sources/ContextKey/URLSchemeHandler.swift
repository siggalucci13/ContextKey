import Cocoa

class URLSchemeHandler: NSObject {
    static let shared = URLSchemeHandler()
    
    var onTextReceived: ((String) -> Void)?
    
    private override init() {
        super.init()
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        print("URLSchemeHandler initialized")
    }
    
    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        print("Received URL event")
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue else {
            print("Failed to get URL string from event")
            return
        }
        print("Received URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("Failed to create URL from string")
            return
        }
        
        guard url.scheme == "vscode-text-sender" else {
            print("Incorrect URL scheme: \(url.scheme ?? "nil")")
            return
        }
        
        guard let text = url.host?.removingPercentEncoding else {
            print("Failed to get text from URL host")
            return
        }
        
        print("Decoded text: \(text)")
        
        DispatchQueue.main.async {
            self.onTextReceived?(text)
            print("onTextReceived callback called with text: \(text)")
        }
    }
}
