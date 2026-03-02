import os

enum AppLogger {
    static let service = Logger(subsystem: "com.jadru.cc-overlay", category: "service")
    static let network = Logger(subsystem: "com.jadru.cc-overlay", category: "network")
    static let auth    = Logger(subsystem: "com.jadru.cc-overlay", category: "auth")
    static let data    = Logger(subsystem: "com.jadru.cc-overlay", category: "data")
    static let ui      = Logger(subsystem: "com.jadru.cc-overlay", category: "ui")
}
