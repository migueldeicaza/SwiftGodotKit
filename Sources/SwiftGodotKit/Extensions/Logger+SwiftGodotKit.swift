import OSLog

extension Logger {
    static let subsystem = "com.swiftgodotkit"
    
    static let Window = Logger(subsystem: subsystem, category: "Window")
    static let App = Logger(subsystem: subsystem, category: "App")
}
