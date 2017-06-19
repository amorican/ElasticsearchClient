//
//  Searchable.swift
//  ElasticsearchClient
//
//  Created by Frank Le Grand on 5/11/17.
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Foundation
import Gloss

public protocol Searchable : Glossy {
    
    /// Elasticsearch Type name
    static var typeName: String { get }
    
    //TODO
    /// Currently unused (TODO)
    static var excludedFieldsInDefaultSearch: [String]? { get }
    
    /**
     Index of field names to provide the matching field name to use in a sort. For example, you may want
     to set your sort on the field `name`, but the Elasticsearch mapping of your type should use 
     `name.lowercase` you would then need to add to the map `["name": "name.lowercase"]`.
     You only need to define key-values for fields that use a different field from the mapping for sorting.
     */
    static var sortFieldNamesMap: [String: String]? { get }
    
    /**
     Build an Elasticsearch query from an object. Typically the object would be list of
     key-values that the method converts into a json elasticsearch query.
     - Remark: Ideally we would define an associatedtype for the filtersObject type, but this would make the protocol
     Searchable usable only as a constraint.
     - Parameter filtersObject: An object of type `Any` that your implementation must be handle to convert.
     - Returns: A JSON elasticsearch query
     */
    static func buildQuery(from filtersObject: Any) -> JSON
    
    /**
     Unique identifier of the document. All elasticsearch documents have an id property.
     - Remark: Currently defined as an Int?, we may want to make this a String so the module can support string id's.
     */
    var id : Int? { get }
    
    /**
     The original elasticsearch json document
     */
    var json : JSON? { get }
}

// MARK: - Sort

public extension Searchable {

    /**
     Build an Elasticsearch sort clause which is used along with the query in the `POST` JSON
     object in an `ElasticsearchCall`.
     - Parameter fieldName: The field name on which the sort must apply. You do not need to pass
     an analyzed field name from your Elasticsearch mapping if it's been set up in `sortFieldNamesMap`
     - Returns: A JSON elasticsearch sort info
     */
    static func sortClause(withFieldName fieldName: String, ascending: Bool = true) -> JSON {
        var sortFieldName = fieldName;
        if let mappedFieldName = self.sortFieldNamesMap?[fieldName] {
            sortFieldName = mappedFieldName
        }
        return [sortFieldName: ascending ? "asc" : "desc"]
    }
    
    static func getSortByScoreClause() -> JSON? {
        return ["sort": ["_score"]]
    }
}

// MARK: - Fetch & Search Implementations

public extension Searchable {
    
    /**
     Fetch a Searchable by id. Nil will be returned if the Elasticsearch document doesn't exist, or
     if an error occurred.
     If you need to catch an exception, see `ElasticsearchFetcher`.
     */
    public static func fetch<T : Searchable>(withId id: Int, completion: ( @escaping (_ fetchedDocument: T?) -> Void)) {
        ElasticsearchCall.fetchDocumentSource(typeName: self.typeName, id: id) { asyncResult in
            do {
                let json = try asyncResult.resolve()
                let documentSource = T(json: json)
                completion(documentSource)
                
            }
            catch {
                logger.logError("\(type(of:self)) \(#function) id=\(id): A failure occured while fetching the document, nil was returned. \(error)")
                completion(nil)
            }
            
        }
    }

    public static func fetch<T : Searchable>(withIds ids: [Int]!, completion: ( @escaping (_ fetchedDocuments: [T]?, _ error: Error?) -> Void)) {
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

    public static func search<T : Searchable>(withQuery query: JSON?, completion: ( @escaping (_ fetchedDocuments: [T]?) -> Void)) {
        
        self.search(withQuery: query) { (asyncHits: AsyncResult<ElasticsearchHits<T>?>) in
            do {
                let response = try asyncHits.resolve()
                let documents = response?.hits?.flatMap() { $0.esSource }
                completion(documents)
            }
            catch {
                logger.logError("\(type(of:self)) \(#function): A failure occured while searching, nil was returned. \(error)")
                completion(nil)
            }
        }
    }
    
}

extension Searchable {
    
    public static func search<T : Searchable>(withQuery query: JSON?, completion: ( @escaping (_ asyncHits: AsyncResult<ElasticsearchHits<T>?>) -> Void)) {
        let indexName = ElasticsearchClient.indexName(forTypeName: T.typeName)
        if T.typeName.isEmpty || indexName.isEmpty {
            completion(AsyncResult {
                throw ElasticsearchCallError.indexOrTypeMissing
            })
            return
        }
        
        self.search(withQuery: query, indexName: indexName, typeName: T.typeName) { (asyncSearchResults: AsyncResult<ElasticsearchResponse<T>>) in
            
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
    
    // MARK: Results Helpers
    
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
        ElasticsearchCall.update(typeName: self.typeName, documentId: documentId, fields: fields) { asyncResult in completion?() }
        
    }
    
    public func update(completion: ( @escaping () -> Void)) {
        if let fields = self.toJSON() {
            self.update(fields: fields, completion: completion)
        }
    }
    
    public func update(fields: JSON) {
        self.update(fields: fields) {() -> Void in}
    }
    
    public func update(fields: JSON, completion: ( @escaping () -> Void)) {
        guard let id = self.id else {
            logger.log("\(#function) The update function was called on a searchable with a nil id.")
            completion()
            return
        }
        
        let typeName = type(of: self).typeName
        ElasticsearchCall.update(typeName: typeName, documentId: id, fields: fields) { asyncResult in completion() }
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

