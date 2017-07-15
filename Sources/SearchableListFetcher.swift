//
//  SearchableListFetcher.swift
//  SIElasticDataKit
//
//  Created by Frank Le Grand on 5/18/17.
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
import SimpleStateMachine

public class SearchableListFetcher<T: SearchableList, U: Searchable> {
    
    public typealias SearchableListItemsClosure = ((_ listItems: [SearchableListItem<U>]) -> Void)
    
    
    // MARK: - Properties
    
    fileprivate(set) lazy var machine: SimpleStateMachine<SearchableListFetcher<T, U>> = {
        let machine = SimpleStateMachine(initialState: .ready, delegate: self)
        return machine
    }()
    
    public var isDone: Bool {
        get {
            return machine.state == .done
        }
    }
    
    public var hasFailed: Bool {
        get {
            return self.fetcher?.hasFailed ?? false
        }
    }
    
    public var shouldOnlyFetchDocumentsFromSearchableList = true

    
    fileprivate(set) var searchableList: T
    fileprivate(set) var filters: SearchableFilterSet
    fileprivate(set) var sortFieldName: String?
    fileprivate(set) var sortAscending = true
    
    fileprivate(set) var fetcher: ElasticsearchFetcher<U>?
    fileprivate var listItems = [SearchableListItem<U>]()
    fileprivate var listItemsFromLastFetch = [SearchableListItem<U>]()
    
    // MARK: Callbacks on State Change
    
    public var didFetchDocumentsClosure: SearchableListItemsClosure?
    public var didCompleteClosure: SearchableListItemsClosure?
    public var didFailClosure: ((_: Error) -> Void)?
    public var didChangeBackgroundWorkerState: ((_: ElasticsearchBackgroundWorkerState) -> Void)?
    
    // MARK: Fetch Mode
    
    public var shouldFetchAllDocuments = false
    
    // MARK: Counts
    
    public var fetchedCount: Int {
        get {
            return self.fetcher?.fetchedCount ?? 0
        }
    }
    
    public var queryHitsTotal: Int? {
        get {
            return self.fetcher?.queryHitsTotal
        }
    }
    
    // MARK: - Init
    
    public init(withSearchableList searchableList: T, filters: SearchableFilterSet, sortedBy sortFieldName: String? = nil, sortAscending: Bool = true) {
        self.searchableList = searchableList
        self.filters = filters
        self.sortFieldName = sortFieldName
        self.sortAscending = sortAscending
    }
    
    public func updateMutatedSearchableList(_ searchableList: T) {
        self.searchableList = searchableList
    }
    
    // MARK: - States Transition
    
    public func run(completion: ((_ listItems: [SearchableListItem<U>]) -> Void)? = nil) {
        if let completion = completion {
            self.didCompleteClosure = completion
        }
        self.machine.state = .fetching
    }
    
    fileprivate func startFetching() {
        let fetcher = self.createFetcher()
        fetcher.shouldFetchAll = self.shouldFetchAllDocuments
        
        self.fetcher = fetcher
        self.fetcher?.run()
    }
    
    fileprivate func createFetcher() -> ElasticsearchFetcher<U> {
        let filters = self.filters
        if self.shouldOnlyFetchDocumentsFromSearchableList {
            filters.setListDocument(self.searchableList)
        }
        
        let fetcher = ElasticsearchFetcher<U>(withFilters: filters, sortedBy: self.sortFieldName, sortAscending: self.sortAscending)
        fetcher.didFetchDocumentsClosure = { [weak self] documents in
            if fetcher != self?.fetcher {
                return
            }
            self?.handleDocumentResults(documents)
        }
        
        fetcher.didFailClosure = { error in
            logger.log("SearchableListFetcher failed: \(error)")
            self.machine.state = .done
        }
        
        return fetcher
    }
    
    fileprivate func resumeFetching() {
        self.fetcher?.run()
    }
    
    fileprivate func handleDocumentResults(_ documents: [U]) {
        
        var newListItems = [SearchableListItem<U>]()
        
        for document in documents {
            let itemsForDocument = searchableList.createListItems(forDocument: document)
            newListItems.append(contentsOf: itemsForDocument)
        }
        
        self.listItemsFromLastFetch = newListItems
        self.listItems.append(contentsOf: newListItems)
        self.machine.state = .standby
        
    }
    
    fileprivate func handleDocumentsFetched(_ items: [SearchableListItem<U>]) {
        self.didFetchDocumentsClosure?(items)
        if self.fetcher?.isFinished ?? false {
            self.machine.state = .done
            return
        }
        
        if self.shouldFetchAllDocuments {
            self.machine.state = .fetching
        }
    }
}

// MARK: - SimpleStateMachineDelegate Implementation

public enum SearchableListFetcherState: SimpleStateMachineState, Equatable {
    case ready, fetching, standby, done
    
    public func canTransition(from: SearchableListFetcherState, to: SearchableListFetcherState) -> Bool {
        switch (from, to) {
        case (_, .ready):
            return true
        case (.ready, .fetching):
            return true
        case (.fetching, .standby):
            return true
        case (.standby, .fetching):
            return true
        case (.fetching, .done):
            return true
        case (.standby, .done):
            return true
        default:
            return false
        }
    }
}

extension SearchableListFetcher: SimpleStateMachineDelegate {
    
    public typealias StateType = SearchableListFetcherState
    
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
            self.startFetching()
            
        case (.fetching, .standby):
            self.handleDocumentsFetched(self.listItemsFromLastFetch)
            
        case (.standby, .fetching):
            self.resumeFetching()
            
        case (_, .done):
            self.didCompleteClosure?(self.listItems)
            
        default:
            break
        }
    }
}

