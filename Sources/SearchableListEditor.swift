//
//  SearchableListEditor.swift
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


public protocol SearchableListEditable {
    
    /// Id of the `SearchableList` document. Typically this is set at initialization time so that `loadSearchableListAndItems()` can be called.
    var searchableListId: Int { get }

    /// The number of Elasticsearch documents fetched so far. Call `loadMoreItems()` to fetch more.
    var fetchedCount: Int { get }

    /// The total number of items that the editor will have when all the Elasticsearch documents have been fetched. This total can be more than the count of documents when a SearchableList allows multiple occurrences of the same document
    var totalItemsCount: Int? { get }
    
    /**
     Get the list of items (fetched so far).
     - Returns: An array of `Any` objects representing the items of the `SearchableList`
     - Remark: We return of array of `Any` instead of defining an `associatedtype` to avoid adding the overhead of a "Type Erasure" pattern implementation.
     Still, it'd be nice to improve.
     */
    func getListItems() -> [Any]
    
    /// Fetches the `SearchableList` document and starts fetching the list items
    func loadSearchableListAndItems()
    
    /// Fetches the next set of list item documents
    func loadMoreItems()
    
    /// Sorts the list item documents, this is implemented only for the keys for which the sort must be done locally on the client side.
    func sortItems(byFieldName sortFieldName: String, ascending: Bool)
    
}

public enum SearchableListEditorError: Error {
    case cannotFetchSearchableList(id: Int)
}

open class SearchableListEditor<T: SearchableList, U: Searchable>: SearchableListEditable {
    
    // MARK: - Public Callbacks
    
    public var didFetchSearchableList: ((_: T) -> Void)?
    public var didFetchAllDocuments: ((_: [SearchableListItem<U>]) -> Void)?
    public var didFetchPartialDocuments: ((_: [SearchableListItem<U>]) -> Void)?
    public var didChangeBackgroundWorkerState: ((_: ElasticsearchBackgroundWorkerState) -> Void)?
    
    public var didRemoveItemsAtIndexSet: ((_ : IndexSet) -> Void)?
    public var willMoveItemsAtIndexSet: ((_ : IndexSet) -> Void)?
    public var didMoveItems: ((_ from: IndexSet, _ to: IndexSet) -> Void)?
    public var didCancelMovingItemsFromIndexSet: ((_ : IndexSet) -> Void)?
    public var didUpdateItems: ((_: [SearchableListItem<U>], _ at: IndexSet) -> Void)?
    public var didInsertItemsAtIndexSet: ((_ : IndexSet) -> Void)?
    
    // MARK: - Properties
    
    var indexSetOfMovingItems: IndexSet?
    
    public lazy var editMonitor: SearchableListEditMonitor = {
        return SearchableListEditMonitor()
    }()
    
    // MARK: Filters & SearchableList(Parent)
    
    public let searchableListId: Int
    fileprivate var itemsFilters: SearchableFilterSet
    fileprivate(set) var sortFieldName: String?
    fileprivate(set) var sortAscending = true
    
    //    var editMonitor: EditMonitor { get }
    
    // MARK: Results
    
    public var searchableList: T?
    public var shouldOnlyFetchDocumentsFromSearchableList = true
    public fileprivate(set) var listItems = [SearchableListItem<U>]()
    public func getListItems() -> [Any] {
        return listItems
    }
    
    // MARK: Machine Stuff
    
    var itemsFetcher: SearchableListFetcher<T, U>?
    
    fileprivate lazy var machine: SimpleStateMachine<SearchableListEditor<T, U>> = {
        let machine = SimpleStateMachine<SearchableListEditor<T, U>>(initialState: .ready, delegate: self)
        return machine
    }()
    
    // MARK: Fetcher Info
    
    public var fetchedCount: Int {
        get {
            return self.itemsFetcher?.fetchedCount ?? 0
        }
    }
    
    /// The number of Elasticsearch documents that match the query. This information is only available after the first set of results has been fetched.
    public var queryCount: Int? {
        get {
            return self.itemsFetcher?.queryHitsTotal
        }
    }
    
    public var totalItemsCount: Int? {
        get {
            if self.shouldOnlyFetchDocumentsFromSearchableList, let count = self.searchableList?.listItemsCount {
                return count
            }
            return self.queryCount
        }
    }
    
    // MARK: - Init
    
    public init(withId searchableListId: Int, filters: SearchableFilterSet, sortedBy sortFieldName: String? = nil, sortAscending: Bool = true) {
        self.searchableListId = searchableListId
        self.itemsFilters = filters
        self.sortFieldName = sortFieldName
        self.sortAscending = sortAscending
    }
    
    public func updateMutatedSeachableList(_ searchableList: T) {
        self.searchableList = searchableList
        self.itemsFetcher?.updateMutatedSearchableList(searchableList)
    }
    
    // MARK: - States Transitions
    
    public func loadSearchableListAndItems() {
        self.machine.state = .fetchingSearchableList
    }
    
    public func loadMoreItems() {
        self.machine.state = .fetchingDocuments
    }
    
    public func loadItemsWithFilters(_ filters: SearchableFilterSet) {
        self.itemsFilters = filters
        self.machine.state = .ready
        self.machine.state = .fetchingDocuments
    }
    
    public func sortItems(byFieldName sortFieldName: String, ascending: Bool) {
        self.sortFieldName = sortFieldName
        self.sortAscending = ascending
        
        if (!self.shouldOnlyFetchDocumentsFromSearchableList || self.itemsFetcher?.isDone == true) && self.searchableList?.localSortIsRequired(forFieldName: sortFieldName) ?? false,
            let sortedItems = searchableList?.sortedItems(self.listItems, withKey: sortFieldName, ascending: ascending) {
            self.handleAllItemsFetched(items: sortedItems)
        }
        else {
            self.machine.state = .ready
            self.machine.state = .fetchingDocuments
        }
    }
    
//    public func canSortByFieldName(_ sortFieldName: String) -> Bool {
//        if self.searchableList?.localSortIsRequired(forFieldName: sortFieldName) ?? false && !self.shouldOnlyFetchDocumentsFromSearchableList {
//            return false
//        }
//        return true
//    }
}

// MARK: - SimpleStateMachine Delegate Implementation

extension SearchableListEditor: SimpleStateMachineDelegate {
    
    public typealias StateType = SearchableListEditorState<T, U>
    
    public func didTransition(from: StateType, to: StateType) {
        
        switch (from, to) {
        case (_, .fetchingSearchableList):
            fallthrough
        case (_, .fetchingDocuments):
            self.didChangeBackgroundWorkerState?(.on)
        default:
            self.didChangeBackgroundWorkerState?(.off)
        }
        
        switch (from, to) {
        case (.ready, .fetchingSearchableList):
            self.fetchSearchableList()
            
        case (.ready, .fetchingDocuments):
            guard let searchableList = self.searchableList else {
                self.machine.state = .ready
                return
            }
            self.fetchDocuments(ofSearchableList: searchableList, filters: self.itemsFilters)
            
        case (.fetchingSearchableList, .searchableListFetched(let searchableList)):
            self.handleSearchableListFetched(searchableList)
            
        case (.searchableListFetched(let searchableList), .fetchingDocuments):
            self.fetchDocuments(ofSearchableList: searchableList, filters: self.itemsFilters)
            
        case (_, .partialDocumentsFetched(let listItems)):
            self.handlePartialItemsFetched(items: listItems)
            
        case (_, .allDocumentsFetched(let listItems)):
            self.handleAllItemsFetched(items: listItems)
            
        case (.partialDocumentsFetched(_), .fetchingDocuments):
            self.fetchMoreItems()
            
        default:
            break
        }
    }
}

// MARK: - Fetching the Parent(SearchableList) and its items

extension SearchableListEditor {
    
    fileprivate func fetchSearchableList() {
        T.fetch(withId: self.searchableListId) { [weak self] (searchableList: T?) in
            guard let strongSelf = self else {
                return
            }
            guard let searchableList = searchableList else {
                strongSelf.machine.state = .failure(SearchableListEditorError.cannotFetchSearchableList(id: strongSelf.searchableListId))
                return
            }
            strongSelf.machine.state = .searchableListFetched(searchableList)
        }
    }
    
    fileprivate func handleSearchableListFetched(_ searchableList: T) {
        self.searchableList = searchableList
        logger.log("Did fetch SearchableList \(searchableList).")
        self.didFetchSearchableList?(searchableList)
        self.machine.state = .fetchingDocuments
    }
    
    fileprivate func fetchDocuments(ofSearchableList searchableList: T, filters: SearchableFilterSet) {
        self.listItems.removeAll()
        
        let localSortIsRequired = self.sortFieldName != nil && searchableList.localSortIsRequired(forFieldName: self.sortFieldName!)
        let sortFieldName = !localSortIsRequired ? self.sortFieldName : nil
        let itemsFetcher = SearchableListFetcher<T, U>(withSearchableList: searchableList, filters: filters, sortedBy: sortFieldName, sortAscending: self.sortAscending)
        itemsFetcher.shouldOnlyFetchDocumentsFromSearchableList = self.shouldOnlyFetchDocumentsFromSearchableList
        itemsFetcher.shouldFetchAllDocuments = itemsFetcher.shouldOnlyFetchDocumentsFromSearchableList && (searchableList.editorRequiresAllDocuments || localSortIsRequired)
        
        itemsFetcher.didFetchDocumentsClosure = { [weak self] listItems in
            guard let strongSelf = self else {
                return
            }
            let totalCount: Any = strongSelf.totalItemsCount ?? "an unknown count of"
            logger.log("\(searchableList) Did fetch \(listItems.count) list items. List has \(totalCount) items, \(strongSelf.fetchedCount) fetched so far.")
            strongSelf.machine.state = .partialDocumentsFetched(listItems)
            
            if itemsFetcher.shouldOnlyFetchDocumentsFromSearchableList && itemsFetcher.shouldFetchAllDocuments && !itemsFetcher.isDone {
                strongSelf.machine.state = .fetchingDocuments
            }
        }
        
        itemsFetcher.didCompleteClosure = { [weak self] listItems in
            guard let strongSelf = self else {
                return
            }
            
            
            var sortedItems = listItems
            if let sortFieldName = strongSelf.sortFieldName, searchableList.localSortIsRequired(forFieldName: sortFieldName) {
                sortedItems = searchableList.sortedItems(sortedItems, withKey: sortFieldName, ascending: strongSelf.sortAscending)
            }
            
            
            if itemsFetcher.hasFailed {
                logger.log("\(searchableList) failed.")
            }
            else {
                logger.log("\(searchableList) Did fetch all \(listItems.count) list items.")
            }
            
            self?.machine.state = .allDocumentsFetched(sortedItems)
        }
        
        itemsFetcher.run()
        self.itemsFetcher = itemsFetcher
    }
    
    fileprivate func fetchMoreItems() {
        self.itemsFetcher?.run()
    }
    
    fileprivate func handleAllItemsFetched(items: [SearchableListItem<U>]) {
        self.listItems = items
        self.didFetchAllDocuments?(items)
    }
    
    fileprivate func handlePartialItemsFetched(items: [SearchableListItem<U>]) {
        self.listItems.append(contentsOf: items)
        self.didFetchPartialDocuments?(items)
    }
}

// MARK: - Edit Options

extension SearchableListEditor {
    
    public func createEditOptions(forItems items: [SearchableListItem<U>]) -> [SearchableListEditOption] {
        var options = [SearchableListEditOption]()
        
        if let _ = self.indexSetOfMovingItems {
            if let cancelMoveOption = self.createEditOptionsForCancelingMovingItems() {
                options.append(cancelMoveOption)
            }
            if let finishMoveWithDeleteOption = self.createEditOptionsForRemovingMovingItems() {
                options.append(finishMoveWithDeleteOption)
            }
            if let finishMoveWithPositionUpdateOption = self.createEditOptionsForUpdatingPositionOfMovingItems(to: 0) {
                options.append(finishMoveWithPositionUpdateOption)
            }
            return self.options(options, withMonitor: self.editMonitor)
        }
        
        if let removeOption = self.createEditOptions(forRemovingItems: items) {
            options.append(removeOption)
        }
        if let beginMoveOption = self.createEditOptions(forBeginMovingItems: items) {
            options.append(beginMoveOption)
        }
        
        
        if let searchableList = self.searchableList {
            let listOptions = T.createEditOptions(forItems: items, inItemList: self.listItems, ofSearchableList: searchableList) { [weak self] (updatedItems) in
                guard let strongself = self else {
                    return
                }
//                strongself.updateMutatedSeachableList(mutatedSearchableList)
                let indexSet = strongself.indexSet(ofItems: updatedItems, inList: strongself.listItems)
                self?.didUpdateItems?(updatedItems, indexSet)
            }
            
            options.append(contentsOf: listOptions)
        }
        
        return self.options(options, withMonitor: self.editMonitor)
    }
    
    public func createEditOptions(forAddingDocuments documents: [U], atPosition position: Int) -> SearchableListEditOption? {
        let title = "FIXME - Add documents"
        let executer: SearchableListEditExecution = { remoteCompletion in
            let newItems = self.searchableList?.insert(documents: documents, atPosition: position, remoteCompletion: remoteCompletion) ?? [SearchableListItem<U>]()
            var insertPosition = position
            if insertPosition < 0 {
                insertPosition = 0
            }
            if insertPosition > self.listItems.count {
                insertPosition = self.listItems.count
            }
            self.listItems.insert(contentsOf: newItems, at: insertPosition)

            
            let insertIndexSet = self.indexSet(ofItems: newItems, inList: self.listItems)
            self.didInsertItemsAtIndexSet?(insertIndexSet)
        }
        
        let option = self.editMonitor.editOption(withTitle: title, isInternal: false, isEnabled: true, executer: executer)
        return option
    }
    
    public func createEditOptions(forRemovingItems listItems: [SearchableListItem<U>]) -> SearchableListEditOption? {
        guard self.shouldOnlyFetchDocumentsFromSearchableList, let searchableList = self.searchableList, listItems.count > 0 else {
            return nil
        }
        
        var title = self.titleForListItems(listItems)
        title = "Remove " + title
        
        if !searchableList.canRemoveListItems(listItems) {
            let executer: SearchableListEditExecution = { remoteCompletion in }
            let option = self.editMonitor.editOption(withTitle: title, isInternal: false, isEnabled: true, executer: executer)
            return option
        }
        
        let removedIndexSet = self.indexSet(ofItems: listItems, inList: self.listItems)
        
        let executer: SearchableListEditExecution = { remoteCompletion in
            var mutatingSearchableList = searchableList
            self.willMoveItemsAtIndexSet?(removedIndexSet)
            
            let newItems = mutatingSearchableList.removeListItems(listItems, fromItemList: self.listItems, remoteCompletion: remoteCompletion)
            self.updateMutatedSeachableList(mutatingSearchableList)
            self.listItems = newItems
            self.didRemoveItemsAtIndexSet?(removedIndexSet)
        }
        
        let option = self.editMonitor.editOption(withTitle: title, isInternal: false, isEnabled: true, executer: executer)
        return option
    }
    
    public func createEditOptions(forBeginMovingItems listItems: [SearchableListItem<U>]) -> SearchableListEditOption? {
        if !(self.searchableList?.canMoveListItems(listItems) ?? false) || listItems.count == 0 || !self.shouldOnlyFetchDocumentsFromSearchableList {
            return nil
        }
        
        
        
        var title = self.titleForListItems(listItems)
        title = "Will move " + title
        let movingIndexSet = self.indexSet(ofItems: listItems, inList: self.listItems)
        
        let executer: SearchableListEditExecution = { remoteCompletion in
            self.indexSetOfMovingItems = movingIndexSet
            self.willMoveItemsAtIndexSet?(movingIndexSet)
        }
        
        let option = self.editMonitor.editOption(withTitle: title, isInternal: true, isEnabled: true, executer: executer)
        return option
    }
    
    public func createEditOptionsForCancelingMovingItems() -> SearchableListEditOption? {
        guard let indexSet = self.indexSetOfMovingItems, let position = indexSet.first, indexSet.count > 0 else {
            return nil
        }
        
        var listItems = [SearchableListItem<U>]()
        for index in indexSet {
            let item = self.listItems[index]
            listItems.append(item)
        }
        var title = self.titleForListItems(listItems)
        
        title = "Cancel moving " + title
        if position != 0 {
            title = title + " from position \(position)"
        }
        
        let executer: SearchableListEditExecution = { remoteCompletion in
            self.indexSetOfMovingItems = nil
            self.didCancelMovingItemsFromIndexSet?(indexSet)
        }
        
        let option = self.editMonitor.editOption(withTitle: title, isInternal: true, isEnabled: true, executer: executer)
        return option
    }
    
    public func createEditOptionsForRemovingMovingItems() -> SearchableListEditOption? {
        guard let searchableList = self.searchableList, let indexSet = self.indexSetOfMovingItems, let position = indexSet.first, indexSet.count > 0 else {
            return nil
        }
        
        var listItems = [SearchableListItem<U>]()
        for index in indexSet {
            let item = self.listItems[index]
            listItems.append(item)
        }
        var title = self.titleForListItems(listItems)
        
        title = "Remove " + title + " moving from position \(position)"
        
        let executer: SearchableListEditExecution = { remoteCompletion in
            self.indexSetOfMovingItems = nil
            
            var mutatingSearchableList = searchableList
            let newItems = mutatingSearchableList.removeListItems(listItems, fromItemList: self.listItems, remoteCompletion: remoteCompletion)
            self.updateMutatedSeachableList(mutatingSearchableList)
            self.listItems = newItems
            self.didRemoveItemsAtIndexSet?(indexSet)
        }
        
        let option = self.editMonitor.editOption(withTitle: title, isInternal: false, isEnabled: true, executer: executer)
        return option
    }
    
    public func createEditOptionsForUpdatingPositionOfMovingItems(to position: Int) -> SearchableListEditOption? {
        guard let searchableList = self.searchableList, let indexSet = self.indexSetOfMovingItems, let originalPosition = indexSet.first, indexSet.count > 0 else {
            return nil
        }
        
        var listItems = [SearchableListItem<U>]()
        for index in indexSet {
            let item = self.listItems[index]
            listItems.append(item)
        }
        var title = self.titleForListItems(listItems)
        
        title = "Move " + title + " from position \(originalPosition) to \(position)"
        
        let executer: SearchableListEditExecution = { remoteCompletion in
            self.indexSetOfMovingItems = nil
            var mutatingSearchableList = searchableList
            let newItems = mutatingSearchableList.moveListItems(listItems, toPosition: position, inItemList: self.listItems, remoteCompletion: remoteCompletion)
            self.updateMutatedSeachableList(mutatingSearchableList)
            self.listItems = newItems
            
            let insertIndexSet = self.indexSet(ofItems: listItems, inList: newItems)
            self.didMoveItems?(indexSet, insertIndexSet)
        }
        
        let option = self.editMonitor.editOption(withTitle: title, isInternal: false, isEnabled: true, executer: executer)
        return option
    }
    
    public func indexSet<U: Equatable>(ofItems items: [U], inList list: [U]) -> IndexSet {
        return self.searchableList?.indexSet(ofItems: items, inList: list) ?? IndexSet()
    }
    
    public func listItems(atIndexSet indexSet: IndexSet) -> [SearchableListItem<U>] {
        var listItems = [SearchableListItem<U>]()
        for index in indexSet {
            if index < 0 || index >= self.listItems.count {
                continue
            }
            
            listItems.append(self.listItems[index])
        }
        return listItems
    }
    
    private func titleForListItems(_ items: [SearchableListItem<U>]) -> String {
        return self.searchableList?.titleForListItems(items) ?? ""
    }
    
    public func options(_ options: [SearchableListEditOption], withMonitor monitor: SearchableListEditMonitor) -> [SearchableListEditOption] {
        for option in options {
            option.monitor = monitor
        }
        return options
    }
}

