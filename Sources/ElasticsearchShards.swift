//
//  ElasticsearchShards.swift
//  ElasticsearchClient
//
//  Created by Frank Le Grand on 5/11/17.
//
//

import Foundation
import Gloss

public struct ElasticsearchShards: Glossy {
    
    private var json: JSON?
    let failed: Bool?
    let successful: Int?
    let total: Int?
    
    public init?(json: JSON) {
        self.failed = "failed" <~~ json
        self.successful = "successful" <~~ json
        self.total = "total" <~~ json
    }
    
    public func toJSON() -> JSON? {
        return self.json
    }
    
}
