//
//  ElasticsearchDocumentHeader.swift
//  ElasticsearchClient
//
//  Created by Frank Le Grand on 5/11/17.
//
//

import Foundation
import Gloss

protocol ElasticsearchDocumentHeader : Glossy {
    
    associatedtype documentSourceType
    
    var esId: String? { get }
    var esIndex: String? { get }
    var esType: String? { get }
    var esScore: Float? { get }
    var esSource: documentSourceType? { get }
}
