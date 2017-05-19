import Gloss


public enum ElasticsearchRequestSignatureType {
    case none, awsV4
}

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
    
    public static var indexNameForTypeName: ((_ indexName: String) -> String)?
}

extension ElasticsearchClient {
    internal static func indexName(forTypeName typeName: String) -> String {
        guard let closure = self.indexNameForTypeName else {
            return typeName
        }
        return closure(typeName)
    }

    static public func termsConditionSplitInSetsOf1024<T>(forFieldName fieldName: String, withValues values: [T]) -> JSON {
        var valueSets = [[T]]()
        var valueSet = [T]()
        for (index, value) in values.enumerated() {
            if index != 0 && index%1024 == 0 {
                valueSets.append(valueSet)
                valueSet = [T]()
            }
            valueSet.append(value)
        }
        if valueSet.count > 0 {
            valueSets.append(valueSet)
        }
        
        
        var includeConditions = [JSON]()
        
        for values in valueSets {
            let includeCondition = ["terms": [fieldName: values]]
            includeConditions.append(includeCondition)
            
        }
        return ["bool": ["should": includeConditions]]
    }
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
    
    let prefix = "[ElasticsearchClient]"
    
    internal func log(_ message: String) {
        if !ElasticsearchClient.shouldLogMessages {
            return
        }
        print("\(prefix) \(message)")
    }
    
    internal func logError(_ message: String) {
        print("\(prefix) \(message)")
    }
    
    internal func logQuery(_ message: String) {
        if !(ElasticsearchClient.shouldLogQueries && ElasticsearchClient.shouldLogMessages) {
            return
        }
        print("\(prefix) \(message)")
    }
}
