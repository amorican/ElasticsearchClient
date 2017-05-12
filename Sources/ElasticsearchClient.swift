import Gloss

//public typealias JSON = Gloss.JSON

public struct ElasticsearchClient {
    
    internal static var logger = ElasticsearchClientLogger()

    internal static var signatureType: ElasticsearchRequestSignatureType = .none
    internal static var rootURL = "http://localhost:9200"
    internal static var awsRegion: String?
    internal static var awsAccessKey: String?
    internal static var awsSecretKey: String?

    public static var shouldLogQueries = false
    public static var shouldLogMessages = true
    
    public static func initialize(withRootURL url: String,
                                  signatureType: ElasticsearchRequestSignatureType = .none,
                                  awsRegion: String? = nil,
                                  awsAccessKey: String? = nil,
                                  awsSecretKey: String? = nil) {
        self.rootURL = url
        self.signatureType = signatureType
        self.awsRegion = awsRegion
        self.awsAccessKey = awsAccessKey
        self.awsSecretKey = awsSecretKey
    }
}

public enum ElasticsearchRequestSignatureType {
    case none, awsV4
}


// MARK: - Logger

internal var logger: ElasticsearchClientLogger {
    get {
        return ElasticsearchClient.logger
    }
}

/// Logs messages about unexpected behavior.
protocol Logger {
    
    /// Logs provided message.
    ///
    /// - Parameter message: Message.
    func log(_ message: String)
    
}

/// ElasticsearchClient Logger.
struct ElasticsearchClientLogger: Logger {
    
    internal func log(_ message: String) {
        if !ElasticsearchClient.shouldLogMessages {
            return
        }
        print("[ElasticsearchClient] \(message)")
    }
    
    internal func logError(_ message: String) {
        print("[ElasticsearchClient] \(message)")
    }
    
    internal func logQuery(_ message: String) {
        if !(ElasticsearchClient.shouldLogQueries && ElasticsearchClient.shouldLogMessages) {
            return
        }
        print("[ElasticsearchClient] \(message)")
    }
}
