//
//  SearchableListEditor.swift
//  SIElasticDataKit
//
//  Created by Frank Le Grand on 5/18/17.
//
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

public class SearchableListEditor<T: SearchableList, U: Searchable>: SearchableListEditable {
    
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
    
    // MARK: - Properties
    
    var indexSetOfMovingItems: IndexSet?
    
    // MARK: Filters & SearchableList(Parent)
    
    public let searchableListId: Int
    fileprivate let itemsFilters: SearchableFilterSet
    fileprivate(set) var sortFieldName: String?
    fileprivate(set) var sortAscending = true
    
    //    var editMonitor: EditMonitor { get }
    
    // MARK: Results
    
    public fileprivate(set) var searchableList: T?
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
            if let count = self.searchableList?.listItemsCount {
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
    
    fileprivate func updateMutatedSeachableList(_ searchableList: T) {
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
    
    public func sortItems(byFieldName sortFieldName: String, ascending: Bool) {
        self.sortFieldName = sortFieldName
        self.sortAscending = ascending
        
        if self.itemsFetcher?.isDone == true && self.searchableList?.localSortIsRequired(forFieldName: sortFieldName) ?? false,
            let sortedItems = searchableList?.sortedItems(self.listItems, withKey: sortFieldName, ascending: ascending) {
            self.handleAllItemsFetched(items: sortedItems)
        }
        else {
            self.machine.state = .ready
            self.machine.state = .fetchingDocuments
        }
    }
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
        itemsFetcher.shouldFetchAllDocuments = searchableList.editorRequiresAllDocuments || localSortIsRequired
        
        itemsFetcher.didFetchDocumentsClosure = { [weak self] listItems in
            guard let strongSelf = self else {
                return
            }
            let totalCount: Any = strongSelf.totalItemsCount ?? "an unknown count of"
            logger.log("\(searchableList) Did fetch \(listItems.count) list items. List has \(totalCount) items, \(strongSelf.fetchedCount) fetched so far.")
            strongSelf.machine.state = .partialDocumentsFetched(listItems)
            
            if itemsFetcher.shouldFetchAllDocuments && !itemsFetcher.isDone {
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
            return options
        }
        
        if let removeOption = self.createEditOptions(forRemovingItems: items) {
            options.append(removeOption)
        }
        if let beginMoveOption = self.createEditOptions(forBeginMovingItems: items) {
            options.append(beginMoveOption)
        }
        
        
        if let searchableList = self.searchableList {
            let listOptions = T.createEditOptions(forItems: items, inItemList: self.listItems, ofSearchableList: searchableList) { [weak self] (mutatedSearchableList: T, updatedItems) in
                guard let strongself = self else {
                    return
                }
                strongself.updateMutatedSeachableList(mutatedSearchableList)
                let indexSet = strongself.indexSet(ofItems: updatedItems, inList: strongself.listItems)
                self?.didUpdateItems?(updatedItems, indexSet)
            }
            
            options.append(contentsOf: listOptions)
        }
        
        return options
    }
    
    func createEditOptions(forRemovingItems listItems: [SearchableListItem<U>]) -> SearchableListEditOption? {
        guard let searchableList = self.searchableList, listItems.count > 0 else {
            return nil
        }
        
        var title = self.titleForListItems(listItems)
        title = "Remove " + title
        
        if !searchableList.canRemoveListItems(listItems) {
            let runner: (Void) -> Void = {}
            let option = BaseEditOption(title: title, isInternal: false, isEnabled: false, runner: runner)
            return option
        }
        
        let removedIndexSet = self.indexSet(ofItems: listItems, inList: self.listItems)
        
        let runner: (Void) -> Void = {
            var mutatingSearchableList = searchableList
            self.willMoveItemsAtIndexSet?(removedIndexSet)
            let newItems = mutatingSearchableList.removeListItems(listItems, fromItemList: self.listItems)
            self.updateMutatedSeachableList(mutatingSearchableList)
            self.listItems = newItems
            self.didRemoveItemsAtIndexSet?(removedIndexSet)
        }
        
        let option = BaseEditOption(title: title, isInternal: false, isEnabled: true, runner: runner)
        return option
    }
    
    func createEditOptions(forBeginMovingItems listItems: [SearchableListItem<U>]) -> SearchableListEditOption? {
        if listItems.count == 0 {
            return nil
        }
        
        var title = self.titleForListItems(listItems)
        title = "Will move " + title
        let movingIndexSet = self.indexSet(ofItems: listItems, inList: self.listItems)
        
        let runner: (Void) -> Void = {
            self.indexSetOfMovingItems = movingIndexSet
            self.willMoveItemsAtIndexSet?(movingIndexSet)
        }
        
        let option = BaseEditOption(title: title, isInternal: true, isEnabled: true, runner: runner)
        return option
    }
    
    func createEditOptionsForCancelingMovingItems() -> SearchableListEditOption? {
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
        
        let runner: (Void) -> Void = {
            self.indexSetOfMovingItems = nil
            self.didCancelMovingItemsFromIndexSet?(indexSet)
        }
        
        let option = BaseEditOption(title: title, isInternal: true, isEnabled: true, runner: runner)
        return option
    }
    
    func createEditOptionsForRemovingMovingItems() -> SearchableListEditOption? {
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
        
        let runner: (Void) -> Void = {
            self.indexSetOfMovingItems = nil
            
            var mutatingSearchableList = searchableList
            let newItems = mutatingSearchableList.removeListItems(listItems, fromItemList: self.listItems)
            self.updateMutatedSeachableList(mutatingSearchableList)
            self.listItems = newItems
            self.didRemoveItemsAtIndexSet?(indexSet)
        }
        
        let option = BaseEditOption(title: title, isInternal: true, isEnabled: true, runner: runner)
        return option
    }
    
    func createEditOptionsForUpdatingPositionOfMovingItems(to position: Int) -> SearchableListEditOption? {
        guard let searchableList = self.searchableList, let indexSet = self.indexSetOfMovingItems, let originalPosition = indexSet.first, indexSet.count > 0 else {
            return nil
        }
        
        var listItems = [SearchableListItem<U>]()
        for index in indexSet {
            let item = self.listItems[index]
            listItems.append(item)
        }
        var title = self.titleForListItems(listItems)
        
        title = "Finish moving " + title + " from position \(originalPosition) to \(position)"
        
        let runner: (Void) -> Void = {
            self.indexSetOfMovingItems = nil
            var mutatingSearchableList = searchableList
            let newItems = mutatingSearchableList.moveListItems(listItems, toPosition: position, inItemList: self.listItems)
            self.updateMutatedSeachableList(mutatingSearchableList)
            self.listItems = newItems
            
            let insertIndexSet = self.indexSet(ofItems: listItems, inList: newItems)
            self.didMoveItems?(indexSet, insertIndexSet)
        }
        
        let option = BaseEditOption(title: title, isInternal: true, isEnabled: true, runner: runner)
        return option
    }
    
    private func indexSet<U: Equatable>(ofItems items: [U], inList list: [U]) -> IndexSet {
        return self.searchableList?.indexSet(ofItems: items, inList: list) ?? IndexSet()
    }
    
    private func titleForListItems(_ items: [SearchableListItem<U>]) -> String {
        return self.searchableList?.titleForListItems(items) ?? ""
    }
}

