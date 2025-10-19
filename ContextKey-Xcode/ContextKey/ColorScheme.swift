import SwiftUI

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
        isDarkMode ? Color.white : Color.black
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
