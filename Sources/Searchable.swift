//
//  Searchable.swift
//  ElasticsearchClient
//
//  Created by Frank Le Grand on 5/11/17.
//
//

import Foundation
import Gloss

public protocol Searchable : Glossy {
    
    static var esType: String { get }
    static var esIndex: String { get }
    static var excludedFieldsInDefaultSearch: [String]? { get }
    static var sortFieldNamesMap: [String: String]? { get }
    static func buildQuery(from json: JSON) -> JSON
    
    var id : Int? { get }
    var json : JSON? { get }
}

// MARK: - Fetch & Search Implementations

extension Searchable {
    
    static public func fetch<T : Searchable>(withId id: Int, completion: ( @escaping (_ fetchedDocument: T?) -> Void)) {
        ElasticsearchCall.fetchDocumentSource(indexName: self.esIndex, typeName: self.esType, id: id) { asyncResult in
            do {
                let json = try asyncResult.resolve()
                let documentSource = T(json: json)
                completion(documentSource)
                
            }
            catch {
                logger.log("\(#function): A failure occured while fetching the document, nil was returned. \(error)")
                completion(nil)
            }
            
        }
    }
    
    static func fetch<T : Searchable>(withIds ids: [Int]!, completion: ( @escaping (_ fetchedDocuments: [T]?, _ error: Error?) -> Void)) {
        let query = ["query": ["bool": ["must": ["terms": ["id": ids]]]]]
        
        self.search(withQuery: query) { (asyncHits: AsyncResult<ElasticsearchHits<T>?>) in
            
            do {
                let hits = try asyncHits.resolve()?.hits
                completion(hits?.flatMap({ $0.esSource }), nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }
    
    static func search<T : Searchable>(withQuery query: JSON?, completion: ( @escaping (_ asyncHits: AsyncResult<ElasticsearchHits<T>?>) -> Void)) {
        if T.esType.isEmpty || T.esIndex.isEmpty {
            completion(AsyncResult {
                throw ElasticsearchCallError.indexOrTypeMissing
            })
            return
        }
        
        self.search(withQuery: query, indexName: T.esIndex, typeName: T.esType) { (asyncSearchResults: AsyncResult<ElasticsearchResponse<T>>) in
            
            let hits: AsyncResult<ElasticsearchHits<T>?> = asyncSearchResults.flatMap(self.toHits)
            completion(hits)
        }
    }
    
    static func search<T : Searchable>(withQuery query: JSON?, indexName: String, typeName: String, completion: ( @escaping (_ results: AsyncResult<ElasticsearchResponse<T>>) -> Void)) {
        ElasticsearchCall.search(indexName: indexName, typeName: typeName, query: query) { asyncResult in
            let searchResults: AsyncResult<ElasticsearchResponse<T>> = asyncResult.flatMap(self.toSearchResults)
            completion(searchResults)
        }
    }
    
    static func toSearchResults<T: Searchable>(json: JSON) -> AsyncResult<ElasticsearchResponse<T>> {
        return AsyncResult {
            try self.createSearchResults(fromJSON: json)
        }
    }
    
    static func toHits<T: Searchable>(searchResults: ElasticsearchResponse<T>) -> AsyncResult<ElasticsearchHits<T>?> {
        return AsyncResult {
            return searchResults.hits
        }
    }
    
    //TODO: Refactor this somewhere else
    
    static func createSearchResults<T: Searchable>(fromJSON json: JSON) throws -> ElasticsearchResponse<T> {
        guard let searchResults = ElasticsearchResponse<T>(json: json) else {
            throw ElasticsearchCallError.responseIsNotValidSearchResult(json: json)
        }
        return searchResults
    }
    
    static func createHits<T: Searchable>(fromJSON json: JSON) throws -> ElasticsearchResponse<T> {
        guard let searchResults = ElasticsearchResponse<T>(json: json) else {
            throw ElasticsearchCallError.responseIsNotValidSearchResult(json: json)
        }
        return searchResults
    }
    
}

// MARK: - Update (Work in Progress)

extension Searchable {
    
    static func update(documentId: Int, fields: JSON, completion: ( () -> Void)?) {
        ElasticsearchCall.update(indexName: self.esIndex, typeName: self.esType, documentId: documentId, fields: fields) { asyncResult in completion?() }
        
    }
    
    func update(fields: JSON) {
        self.update(fields: fields) {() -> Void in}
    }
    
    func update(fields: JSON, completion: ( @escaping () -> Void)) {
        guard let id = self.id else {
            logger.log("\(#function) The update function was called on a searchable with a nil id.")
            completion()
            return
        }
        
        let typeName = type(of: self).esType
        let indexName = type(of: self).esIndex
        ElasticsearchCall.update(indexName: indexName, typeName: typeName, documentId: id, fields: fields) { asyncResult in completion() }
    }
    
}

// MARK: - Utilities

func anyToInt(_ object: Any?) -> Int? {
    switch object {
    case let intAsString as String:
        return Int(intAsString)
    case let number as Int:
        return number
    default:
        return nil
    }
}

