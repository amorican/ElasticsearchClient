//
//  ElasticsearchHit.swift
//  ElasticsearchClient
//
//  Created by Frank Le Grand on 5/11/17.
//
//

import Foundation
import Gloss

public struct ElasticsearchHit<T : Searchable> : ElasticsearchDocumentHeader {
    
    typealias documentSourceType = T
    var json : JSON?
    
    public var esId: String?
    public var esIndex: String?
    public var esType: String?
    public var esScore: Float?
    public var esSource: T?
    
    public init?(json: JSON) {
        self.json = json
        self.esId = "_id" <~~ json
        self.esIndex = "_index" <~~ json
        self.esType = "_type" <~~ json
        self.esScore = "_score" <~~ json
        self.esSource = "_source" <~~ json
    }
    
    public func toJSON() -> JSON? {
        return self.json
    }
}

