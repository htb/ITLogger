import Foundation
//import os.log
import ITMulticastDelegate

public protocol LoggerEventDelegate : class
{
    func logger(_ logger: Logger, event entry: Logger.LogEntry)
}


public class Logger
{
    public enum LogLevel : Int, Comparable
    {
        case trace
        case debug
        case verbose
        case info
        case status
        case warning
        case error
        case critical
        /// Error in the source code; things that should never happen
        case code


        public var icon: String
        {
            switch self {
            case .trace    : return "🔍"
            case .debug    : return "🐜"
            case .verbose  : return "💬"
            case .info     : return "💬"
            case .status   : return "✔️"
            case .warning  : return "⚠️"
            case .error    : return "❗️"
            case .critical : return "🔥"
            case .code     : return "🎱"
            }
        }

        public var description: String
        {
            switch self {
            case .trace    : return "trace"
            case .debug    : return "debug"
            case .verbose  : return "verbose"
            case .info     : return "info"
            case .status   : return "status"
            case .warning  : return "warning"
            case .error    : return "error"
            case .critical : return "critical"
            case .code     : return "code"
            }

        }

        public var text: String
        {
            return "\(icon) \(description)"
        }

        public static func from(_ string: String) -> LogLevel?
        {
            var i = 0
            while let item = LogLevel(rawValue: i) {
                if "\(item)" == string { return item }
                i += 1
            }
            return nil
        }

        // Implement Comparable
        public static func < (a: LogLevel, b: LogLevel) -> Bool
        {
            return a.rawValue < b.rawValue
        }
    }


    public struct LogEntry
    {
        public var category : String
        public var date     : Date
        public var level    : LogLevel
        public var message  : String
        public var error    : Error?
        public var file     : String
        public var function : String
        public var line     : Int
        public var column   : Int
    }


    // MARK: - Class level

    public static let `default` = Logger("default")

    public static var logToConsole: Bool = true
    public static var consoleLogLevel: LogLevel = .info
    public static var consoleFormatter: ((_ entry: LogEntry) -> String) = defaultConsoleFormatter

    public private(set) static var delegates = MulticastDelegate<LoggerEventDelegate>()


    // MARK: - Formatter functions

    private static var _defaultDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter
    }()

    private static var _compactDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateFormat = "mm:ss"
        return dateFormatter
    }()

    public static func formatDate(_ date: Date) -> String
    {
        return _defaultDateFormatter.string(from: date)
    }

    public class func defaultConsoleFormatter(_ entry: LogEntry) -> String
    {
        let categoryString = "\(entry.category)".padding(toLength: 15, withPad: " ", startingAt: 0)
        let dateString = _defaultDateFormatter.string(from: entry.date)
        let levelString = "\(entry.level.text)".padding(toLength: 11, withPad: " ", startingAt: 0)
        var errorString = ""
        if let error = entry.error as NSError? { errorString = " [\(error.description)]" }
        return "\(dateString) | \(categoryString) | \(levelString) | \(entry.message)\(errorString)"
    }

    public class func compactConsoleFormatter(_ entry: LogEntry) -> String
    {
        let dateString = _compactDateFormatter.string(from: entry.date)
        let levelString = "\(entry.level.icon)".padding(toLength: 2, withPad: " ", startingAt: 0)
        var errorString = ""
        if let error = entry.error as NSError? { errorString = " [\(error.description)]" }
        return "\(dateString) \(levelString) \(entry.message)\(errorString)"
    }

    public class func verboseConsoleFormatter(_ entry: LogEntry) -> String
    {
        let categoryString = "\(entry.category)".padding(toLength: 15, withPad: " ", startingAt: 0)
        let dateString = _defaultDateFormatter.string(from: entry.date)
        let levelString = "\(entry.level.text)".padding(toLength: 11, withPad: " ", startingAt: 0)
        var errorString = ""
        if let error = entry.error as NSError? { errorString = " \(error.description)" }
        return "\(dateString) | \(categoryString) | \(levelString) | \(entry.message) [\(entry.function) line \(entry.line)\(errorString)]"
    }


    // MARK: - Instance level

    public private(set) var delegates = MulticastDelegate<LoggerEventDelegate>()


    // MARK: - Private

    //private var _oslog: OSLog
    public private(set) var category: String

    private func _log(_ level: LogLevel, _ message: String, error: Error?=nil, file:String=#file, function:String=#function, line:Int=#line, column:Int=#column, category:String?=nil, object:Any?=nil)
    {
        let category = category ?? (object == nil ? self.category : "\(type(of: object!))")

        let entry = LogEntry(
            category: category,
            date: Date(), level: level, message: message, error: error,
            file: file, function: function, line: line, column: column
        )

        if type(of: self).logToConsole && level.rawValue >= type(of: self).consoleLogLevel.rawValue {
            print(type(of: self).consoleFormatter(entry))
        }

        //os_log("%{public}@", log: _oslog, type: .debug, message)

        // Send to log delegates for this log instance
        self.delegates.invoke { $0.logger(self, event: entry) }

        // Global delegate messaging can be queued
        if type(of: self).queueDelegates {
            type(of: self)._queue.append((self, entry))
        } else {
            // Send to delegates listening for all loggers (class level 'delegates')
            type(of: self).delegates.invoke { $0.logger(self, event: entry) }
        }
    }

    private static var _queue: [(Logger, LogEntry)] = []

    public static var queueDelegates: Bool = false
    {
        didSet {
            if queueDelegates == false && _queue.count > 0 {
                `default`.debug("Flushing queued log entries")
                // Flush the entire queue in one operation
                let clone = _queue
                _queue = []
                for (logger, entry) in clone {
                    // Send to delegates listening for all loggers (class level 'delegates')
                    delegates.invoke { $0.logger(logger, event: entry) }
                }
            }
        }
    }


    // MARK: - Public

    public init(_ category: String)
    {
        self.category = category

        //_oslog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "-", category: "API")
    }

    public func log(_ level: LogLevel, _ message: String, error: Error?=nil, file:String=#file, function:String=#function, line:Int=#line, column:Int=#column, category:String?=nil, object:Any?=nil)
    {
        _log(level, message, error: error, file:file, function:function, line:line, column:column, category:category, object:object)
    }


    // MARK: - Specific log level wrappers

    public func trace(_ message: String, error: Error?=nil, file:String=#file, function:String=#function, line:Int=#line, column:Int=#column, category: String? = nil, object: Any? = nil)
    { _log(.trace, message, error: error, file:file, function:function, line:line, column:column, category:category, object:object) }
    public func debug(_ message: String, error: Error?=nil, file:String=#file, function:String=#function, line:Int=#line, column:Int=#column, category: String? = nil, object: Any? = nil)
    { _log(.debug, message, error: error, file:file, function:function, line:line, column:column, category:category, object:object) }
    public func verbose(_ message: String, error: Error?=nil, file:String=#file, function:String=#function, line:Int=#line, column:Int=#column, category: String? = nil, object: Any? = nil)
    { _log(.verbose, message, error: error, file:file, function:function, line:line, column:column, category:category, object:object) }
    public func info(_ message: String, error: Error?=nil, file:String=#file, function:String=#function, line:Int=#line, column:Int=#column, category: String? = nil, object: Any? = nil)
    { _log(.info, message, error: error, file:file, function:function, line:line, column:column, category:category, object:object) }
    public func status(_ message: String, error: Error?=nil, file:String=#file, function:String=#function, line:Int=#line, column:Int=#column, category: String? = nil, object: Any? = nil)
    { _log(.status, message, error: error, file:file, function:function, line:line, column:column, category:category, object:object) }
    public func warning(_ message: String, error: Error?=nil, file:String=#file, function:String=#function, line:Int=#line, column:Int=#column, category: String? = nil, object: Any? = nil)
    { _log(.warning, message, error: error, file:file, function:function, line:line, column:column, category:category, object:object) }
    public func error(_ message: String, error: Error?=nil, file:String=#file, function:String=#function, line:Int=#line, column:Int=#column, category: String? = nil, object: Any? = nil)
    { _log(.error, message, error: error, file:file, function:function, line:line, column:column, category:category, object:object) }
    public func critical(_ message: String, error: Error?=nil, file:String=#file, function:String=#function, line:Int=#line, column:Int=#column, category: String? = nil, object: Any? = nil)
    { _log(.critical, message, error: error, file:file, function:function, line:line, column:column, category:category, object:object) }
    public func code(_ message: String, error: Error?=nil, file:String=#file, function:String=#function, line:Int=#line, column:Int=#column, category: String? = nil, object: Any? = nil)
    { _log(.code, message, error: error, file:file, function:function, line:line, column:column, category:category, object:object) }
}
