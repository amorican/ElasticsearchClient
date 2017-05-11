//
//  ElasticsearchResponse.swift
//  ElasticsearchClient
//
//  Created by Frank Le Grand on 5/11/17.
//
//

import Foundation
import Gloss

public struct ElasticsearchResponse<T : Searchable> : Glossy {
    
    private var json: JSON?
    let shards: ElasticsearchShards?
    let hits: ElasticsearchHits<T>?
    let timedOut: Bool?
    let took: Float?
    
    public init?(json: JSON) {
        self.json = json
        self.shards = "Shards" <~~ json
        self.hits = "hits" <~~ json
        self.timedOut = "timedOut" <~~ json
        self.took = "took" <~~ json
    }
    
    public func toJSON() -> JSON? {
        return self.json
    }
}
