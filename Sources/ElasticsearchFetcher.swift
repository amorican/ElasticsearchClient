//
//  ElasticsearchFetcher.swift
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
import SimpleStateMachine
import Gloss

// MARK: States & Error Enums

public enum ElasticsearchBackgroundWorkerState {
    case on, off
}

public enum ElasticsearchFetcherState<T: Searchable>: SimpleStateMachineState, Equatable {
    case ready, fetching
    case partialResultsFetched(ElasticsearchResponse<T>)
    case done(ElasticsearchResponse<T>)
    case failure(Error)
    
    public func canTransition(from: ElasticsearchFetcherState, to: ElasticsearchFetcherState) -> Bool {
        switch (from, to) {
        case (_, .ready):
            return true
        case (.ready, .fetching):
            return true
        case (.fetching, .partialResultsFetched):
            return true
        case (.partialResultsFetched, .fetching):
            return true
        case (.fetching, .done):
            return true
        case (_, .failure):
            return true
        default:
            return false
        }
    }
    
    public static func == (left: ElasticsearchFetcherState, right: ElasticsearchFetcherState) -> Bool {
        switch (left, right) {
        case (.ready, .ready):
            return true
        case (.fetching, .fetching):
            return true
        case (.done(_), .done(_)):
            return true
        case (.partialResultsFetched(_), .partialResultsFetched(_)):
            return true
        case (.failure(_), .failure(_)):
            return true
        default:
            return false
        }
    }
}

public enum ElasticsearchFetcherError: Error {
    case invalidQuery(errorText: String)
    case emptyResponse
    case other
}

public class ElasticsearchFetcher<T: Searchable>: NSObject, SimpleStateMachineDelegate {
    
    // MARK: - SimpleStateMachineDelegate Implementation
    
    public typealias StateType = ElasticsearchFetcherState<T>
    
    public func didTransition(from: StateType, to: StateType) {
        
        // Notify change in background process state:
        
        switch (from, to) {
        case (_, .fetching):
            self.didChangeBackgroundWorkerState?(.on)
        case (.fetching, _):
            self.didChangeBackgroundWorkerState?(.off)
        default:
            break
        }
        
        // Proces the state change:
        
        switch (from, to) {
        case (.ready, .fetching):
            fallthrough
        case (.partialResultsFetched, .fetching):
            self.startOrContinueFetching()
            
        case (.fetching, .done(let response)):
            self.handleResponse(response)
        case (.fetching, .partialResultsFetched(let response)):
            self.handleResponse(response)
            
        case (_, .failure(let error)):
            self.handleError(error)
            
        default:
            break
        }
    }
    
    // MARK: - Properties
    
    fileprivate lazy var machine: SimpleStateMachine<ElasticsearchFetcher<T>> = {
        let machine = SimpleStateMachine(initialState: .ready, delegate: self)
        return machine
    }()
    
    public var machineState: StateType {
        get {
            return machine.state
        }
    }
    
    public var hasFailed: Bool {
        get {
            switch machineState {
            case .failure(_):
                return true
            default:
                return false
            }
        }
    }
    
    public var isDone: Bool {
        get {
            switch machineState {
            case .done(_):
                return true
            default:
                return false
            }
        }
    }
    
    public var isFinished: Bool {
        get {
            return self.hasFailed || self.isDone
        }
    }
    
    // MARK: Request attributes
    
    public var fetchSize: Int = 100
    public var shouldFetchAll = false
    public fileprivate(set) var fetchedCount: Int = 0
    public fileprivate(set) var queryHitsTotal: Int?
    
    public var types = [String]()
    public var indices = [String]()
    public var excludedSourceFieldNames: [String]?
    public private(set) var query: JSON = JSON()
    
    // MARK: Callbacks on State Change
    
    public var didFetchDocumentsClosure: ((_: [T]) -> Void)?
    public var didFailClosure: ((_: Error) -> Void)?
    public var didChangeBackgroundWorkerState: ((_: ElasticsearchBackgroundWorkerState) -> Void)?
    
    // MARK: - Init
    
    public convenience init(withFilters filters: JSON, resultsFetched: @escaping ((_: [T]) -> Void)) {
        self.init(withFilters: filters, sortedBy: nil, sortAscending: true, resultsFetched: resultsFetched)
    }
    
    public init(withFilters filters: Any, sortedBy sortFieldName: String? = nil, sortAscending: Bool = true, resultsFetched: ((_: [T]) -> Void)? = nil) {
        self.query = T.buildQuery(from: filters)
        if let sortFieldName = sortFieldName {
            let sortClause = T.sortClause(withFieldName: sortFieldName, ascending: sortAscending)
            self.query["sort"] = [sortClause]
        }
        
        if let resultsFetched = resultsFetched {
            self.didFetchDocumentsClosure = resultsFetched
        }
    }
    
    // MARK: - States Transition
    
    public func run() {
        self.run(completion: nil)
    }
    
    public func run(completion: ((_: [T]) -> Void)?) {
        if let completion = completion {
            self.didFetchDocumentsClosure = completion
        }
        self.machine.state = .fetching
    }
    
    // MARK: - Request
    
    fileprivate func startOrContinueFetching() {
        do {
            try self.fetchQueryResults() { [weak self] (response: ElasticsearchResponse<T>?) in
                guard let response = response else {
                    self?.machine.state = .failure(ElasticsearchFetcherError.emptyResponse)
                    return
                }
                
                if let totalCount = self?.queryHitsTotal, self?.fetchedCount ?? 0 >= totalCount {
                    self?.machine.state = .done(response)
                }
                else {
                    self?.machine.state = .partialResultsFetched(response)
                }
                
            }
        }
        catch let error as ElasticsearchFetcherError {
            self.machine.state = .failure(error)
        }
        catch let unknownError {
            self.machine.state = .failure(unknownError)
        }
    }
    
    fileprivate func handleResponse(_ response: ElasticsearchResponse<T>) {
        
        if self.shouldFetchAll {
            self.fetchSize = 500
            self.machine.state = .fetching
        }
        
        let documents = response.hits?.hits?.flatMap() { $0.esSource }
        if let documents = documents {
            self.didFetchDocumentsClosure?(documents)
        }
    }
    
    fileprivate func handleError(_ error: Error) {
        logger.log("Error from \(self): \(error)")
        guard let failureClosure = self.didFailClosure else {
            logger.log("WARNING: A failure occurred but no error handler has been assigned. Set a value to didFailClosure to handle the error.")
            return
        }
        failureClosure(error)
        
    }
    
}

// MARK: - Private Helpers

extension ElasticsearchFetcher {
    
    fileprivate func fetchQueryResults<T>(completion: ((_ response: ElasticsearchResponse<T>?) -> Void)?) throws {
        var query = self.query
        query["from"] = self.fetchedCount
        query["size"] = self.fetchSize
        
        if let excludedFields = self.excludedSourceFieldNames, excludedFields.count > 0 {
            query["_source"] = ["excludes": excludedFields]
        }
        log(query: query)
        
        let indexTypePair = self.getIndexAndTypeNames()
        if indexTypePair.indexName.isEmpty || indexTypePair.typeName.isEmpty {
            throw ElasticsearchFetcherError.invalidQuery(errorText: "At least one Elasticsearch index and one type name must be provided. Request cannot be performed.")
        }
        
        T.search(withQuery: query, indexName: indexTypePair.indexName, typeName: indexTypePair.typeName) {
            [weak self] (asyncResponse: AsyncResult<ElasticsearchResponse<T>>) in
            
            do {
                let response = try asyncResponse.resolve()
                self?.updateCounts(withResponse: response)
                completion?(response)
            }
            catch {
                self?.machine.state = .failure(error)
            }
            
        }
    }
    
    private func updateCounts<T>(withResponse response: ElasticsearchResponse<T>?) {
        if let resultHits = response?.hits,
            let hits = resultHits.hits {
            
            if let total = resultHits.total {
                self.queryHitsTotal = total
            }
            
            self.fetchedCount = self.fetchedCount + hits.count
        }
    }
    
    private func getIndexAndTypeNames() -> (indexName: String, typeName: String) {
        var indices = self.indices
        var types = self.types
        if indices.count == 0 {
            
            for typeName in types {
                indices.append(ElasticsearchClient.indexName(forTypeName: typeName))
            }
            indices.append(ElasticsearchClient.indexName(forTypeName: T.typeName))
            
        }
        if types.count == 0 {
            types.append(T.typeName)
        }
        let queryIndexName = indices.joined(separator: ",")
        let queryTypeName = types.joined(separator: ",")
        
        return (indexName: queryIndexName, typeName: queryTypeName)
    }
}

// MARK: - Logging

extension ElasticsearchFetcher {
    
    fileprivate func log(query: JSON) {
        do {
            let queryData = try JSONSerialization.data(withJSONObject: query, options: .prettyPrinted)
            let queryString = NSString(data: queryData, encoding: String.Encoding.utf8.rawValue) ?? "null"
            logger.logQuery("Query: \(queryString)")
        }
        catch {
            logger.logQuery("Error decoding query for logging: \(error)")
        }
    }
}



