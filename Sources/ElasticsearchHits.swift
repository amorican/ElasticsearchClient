//
//  ElasticsearchHits.swift
//  ElasticsearchClient
//
//  Created by Frank Le Grand on 5/11/17.
//
//

import Foundation
import Gloss

public struct ElasticsearchHits<T : Searchable>: Glossy {
    
    private var json: JSON?
    
    let maxScore: Float?
    let total: Int?
    public let hits: [ElasticsearchHit<T>]?
    
    public init?(json: JSON) {
        self.json = json
        self.maxScore = "maxScore" <~~ json
        self.total = "total" <~~ json
        self.hits = [ElasticsearchHit<T>].from(jsonArray: ("hits" <~~ json)!)
    }
    
    public func toJSON() -> JSON? {
        return self.json
    }
}

