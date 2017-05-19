//
//  ElasticsearchDocumentSource.swift
//  ElasticsearchClient
//
//  Created by Frank Le Grand on 5/11/17.
//
//

import Foundation
import Gloss


public struct ElasticsearchDocumentSource : Searchable {
    
    public static var typeName = ""
    public static var excludedFieldsInDefaultSearch : [String]?
    
    
    public var json : JSON?
    public var id : Int?
    
    public init?(json: JSON) {
        
        self.json = json
        
        self.id = anyToInt(json["id"])
        
    }
    
    public func toJSON() -> JSON? {
        return self.json
    }
    
    public func convert<U : Searchable>() -> U? {
        guard let json = self.json else {
            return nil
        }
        return U(json: json)
    }
}

// MARK: - Query Builder

extension ElasticsearchDocumentSource {
    
    public static var sortFieldNamesMap: [String: String]? {
        get {
            return nil
        }
    }
    
    public static func buildQuery(from filtersObject: Any) -> JSON {
        return filtersObject as? JSON ?? JSON()
    }
}
